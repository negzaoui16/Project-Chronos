import { Injectable, Logger } from '@nestjs/common';

export interface Agent1Angle {
  change_score: number;
  aligned_ok: boolean;
  regions: { crop_path: string; crop_base64?: string }[];
  resolution_warning?: boolean;
  alignment_warning?: boolean;
}

export interface Agent1Result {
  overall_change_detected: boolean;
  routing_hint: 'agent_2' | 'none';
  angles: Agent1Angle[];
}

export interface Agent2VlmAssessment {
  damage_type: string;
  damage_level: string;
  confidence_agreement_ratio: number;
  requires_human_review: boolean;
  is_new_damage: boolean;
  description: string;
}

export interface Agent2Result {
  yolo_findings: any[];
  vlm_assessment: Agent2VlmAssessment;
}

export interface ReconciledClassification extends Agent2VlmAssessment {
  reconciled: boolean;
}

export interface Agent3Result {
  damage_type: string;
  damage_level: string;
  confidence: number;
  reasoning: string;
  context_source: string;
  requires_human_review: boolean;
  professional_consultation_recommended: boolean;
}

export interface Agent4Input {
  device_model: string;
  damage_type: string;
  severity: string;
  description: string;
}

export interface Agent4Output {
  cost_range: string;
  estimated_time: string;
  recommended_action: string;
  confidence_level: string;
  expert_consultation_recommended: boolean;
  report: string;
}

@Injectable()
export class GlueService {
  private readonly logger = new Logger(GlueService.name);

  /**
   * 4.1 select_regions_for_agent2()
   * Extracts ALL regions from ALL angles that have flagged damage,
   * associating them with the corresponding baseline and return photos.
   */
  selectRegionsForAgent2(
    agent1Result: Agent1Result,
    baselinePhotos: string[],
    returnPhotos: string[],
  ): {
    crop_path: string;
    crop_base64?: string;
    change_score: number;
    baseline_image: string;
    return_image: string;
  }[] {
    const selectedRegions = [];

    if (agent1Result.routing_hint !== 'agent_2') {
      return selectedRegions;
    }

    agent1Result.angles.forEach((angle, index) => {
      if (angle.regions && angle.regions.length > 0) {
        // Safe mapping to baseline and return photos by index
        const baseline = baselinePhotos[index] || baselinePhotos[0];
        const ret = returnPhotos[index] || returnPhotos[0];

        angle.regions.forEach((region) => {
          selectedRegions.push({
            crop_path: region.crop_path,
            crop_base64: region.crop_base64,
            change_score: angle.change_score,
            baseline_image: baseline,
            return_image: ret,
          });
        });
      }
    });
    // Sort by change_score descending to process the most severe regions first
    selectedRegions.sort((a, b) => b.change_score - a.change_score);

    // Limit to top 3 regions to prevent long processing times which lead to mobile HTTP timeouts
    return selectedRegions.slice(0, 3);
  }

  /**
   * 4.2 reconcile_agent2_output()
   * Merges Agent 2's two separate signals (yolo_findings + vlm_assessment).
   * If they disagree, explicitly flag for human review.
   */
  reconcileAgent2Output(agent2Raw: Agent2Result): ReconciledClassification {
    const { yolo_findings, vlm_assessment } = agent2Raw;
    
    const reconciled: ReconciledClassification = {
      ...vlm_assessment,
      reconciled: true,
    };

    if (yolo_findings && yolo_findings.length > 0) {
      // Basic heuristic: if YOLO found something but VLM says something completely different (e.g., structural vs screen), flag it.
      const yoloString = JSON.stringify(yolo_findings).toLowerCase();
      const vlmType = vlm_assessment.damage_type.toLowerCase();
      
      const isMismatch = (yoloString.includes('screen') && !vlmType.includes('screen')) ||
                         (yoloString.includes('crack') && vlmType.includes('cosmetic'));

      if (isMismatch) {
        this.logger.warn(`Disagreement detected between YOLO and VLM. Flagging for human review.`);
        reconciled.requires_human_review = true;
      }
    }

    return reconciled;
  }

  /**
   * 4.3 to_agent4_input()
   * Converts Reconciled Agent 2 OR Agent 3 result into Agent 4 input.
   * Returns null if damage is pre-existing or classification is unavailable.
   */
  toAgent4Input(
    classification: ReconciledClassification | Agent3Result,
    deviceModel: string,
  ): Agent4Input | null {
    // Check if it's from Agent 2 and damage is pre-existing
    if ('is_new_damage' in classification) {
      if (classification.is_new_damage === false) {
        this.logger.log('Damage is pre-existing. Skipping Agent 4 estimation.');
        return null;
      }
    }

    if (classification.damage_type === 'classification_unavailable') {
      this.logger.warn('Classification unavailable. Skipping Agent 4 estimation.');
      return null;
    }

    return {
      device_model: deviceModel,
      damage_type: classification.damage_type || 'Unknown',
      severity: classification.damage_level || 'Unknown',
      description: ('description' in classification && classification.description) 
        ? classification.description 
        : (('reasoning' in classification && classification.reasoning) ? classification.reasoning : 'No description provided by upstream agent'),
    };
  }

  /**
   * 4.4 parseAgent4Output()
   * Parses JSON string from Agent 4 and overrides confidence if upstream was low.
   */
  parseAgent4Output(
    rawOutput: any,
    upstreamClassification: ReconciledClassification | Agent3Result,
  ): Agent4Output {
    let parsed: Agent4Output;
    
    if (typeof rawOutput === 'string') {
      try {
        parsed = JSON.parse(rawOutput);
      } catch (e) {
        this.logger.error('Failed to parse Agent 4 output as JSON', e);
        parsed = {
          cost_range: 'N/A',
          estimated_time: 'Unknown',
          recommended_action: 'human_review_required',
          confidence_level: 'Low',
          expert_consultation_recommended: true,
          report: 'Failed to parse AI estimate.',
        };
      }
    } else {
      parsed = rawOutput as Agent4Output;
    }

    // Override Agent 4's confidence if upstream was uncertain
    if (upstreamClassification.requires_human_review) {
      this.logger.warn('Upstream classification requires human review. Overriding Agent 4 confidence to Low.');
      parsed.confidence_level = 'Low';
      parsed.expert_consultation_recommended = true;
      if (parsed.recommended_action !== 'human_review_required') {
        parsed.report += '\n[Note: Automatic action suspended due to uncertain upstream classification. Human review required.]';
        parsed.recommended_action = 'human_review_required';
      }
    }

    return parsed;
  }
}
