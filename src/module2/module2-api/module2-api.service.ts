import { Injectable, Logger } from '@nestjs/common';
import { GlueService, Agent4Output } from './glue.service';
import axios from 'axios';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class Module2ApiService {
  private readonly logger = new Logger(Module2ApiService.name);

  private readonly localAgentUrl = 'http://127.0.0.1:8000';

  constructor(private readonly glueService: GlueService) {}

  /**
   * Helper to fetch local files for Gradio client
   */
  private async prepareFile(filePath: string): Promise<File> {
    if (filePath.startsWith('data:')) {
      const match = filePath.match(/^data:([^;]+);base64,(.+)$/);
      if (match) {
        const mimeType = match[1];
        const base64Data = match[2];
        const buffer = Buffer.from(base64Data, 'base64');
        const file = new File([buffer], 'crop.jpg', { type: mimeType });
        (file as any)._rawBuffer = buffer;
        return file;
      } else {
        throw new Error('Invalid data URI format');
      }
    }
    
    if (filePath.startsWith('http')) {
      const response = await fetch(filePath);
      const buffer = Buffer.from(await response.arrayBuffer());
      const file = new File([buffer], 'image.jpg', { type: 'image/jpeg' });
      (file as any)._rawBuffer = buffer;
      return file;
    }
    const buffer = fs.readFileSync(filePath);
    const file = new File([buffer], path.basename(filePath), { type: 'image/jpeg' });
    (file as any)._rawBuffer = buffer;
    return file;
  }


  /**
   * Flow 1: Photo-Based Inspection (Agent 1 -> Agent 2 -> Agent 4)
   */
  async processPhotoInspection(
    itemId: string,
    itemType: string,
    baselineFiles: string[],
    returnFiles: string[],
    deviceModel: string,
    complaintText: string = '',
  ): Promise<any> {
    this.logger.log(`Starting Photo Inspection for ${itemId} (${itemType})`);
    
    // 1. Call Agent 1 Locally
    try {
      const agent1Response = await axios.post(`${this.localAgentUrl}/agent1/detect`, {
        item_id: itemId,
        item_type: itemType,
        baseline_paths: baselineFiles,
        return_paths: returnFiles,
        complaint_text: complaintText,
      });

      const agent1Result = agent1Response.data;
      this.logger.log(`Agent 1 finished. Routing hint: ${agent1Result.routing_hint}`);

    if (agent1Result.routing_hint === 'none') {
      return { status: 'no_damage', message: 'No damage detected by Agent 1.' };
    }

    // 2. Glue: Select regions for Agent 2
    const regionsForAgent2 = this.glueService.selectRegionsForAgent2(agent1Result, baselineFiles, returnFiles);
    
    const finalReports = [];

    // 3. Process each damaged angle
    for (const region of regionsForAgent2) {
      
      const agent2Response = await axios.post(`${this.localAgentUrl}/agent2/classify`, {
        item_type: itemType,
        crop_image_path: region.crop_path || region.return_image,
        change_score: region.change_score,
        baseline_image_path: region.baseline_image,
        return_image_path: region.return_image,
      });

      const agent2Raw = agent2Response.data;
      
      // Glue: Reconcile Agent 2 output
      const reconciled = this.glueService.reconcileAgent2Output(agent2Raw);
      
      // Glue: Prepare Agent 4 input
      const agent4Input = this.glueService.toAgent4Input(reconciled, deviceModel);

      if (!agent4Input) {
        finalReports.push({ region_score: region.change_score, status: 'human_review', reason: 'Pre-existing damage or classification unavailable' });
        continue;
      }

      // 4. Call Agent 4
      const agent4Response = await axios.post(`${this.localAgentUrl}/agent4/estimate`, {
        device_model: agent4Input.device_model,
        damage_type: agent4Input.damage_type,
        severity: agent4Input.severity,
        description: agent4Input.description,
      });

      // Glue: Parse Agent 4 output
      const agent4Output = this.glueService.parseAgent4Output(agent4Response.data, reconciled);
      finalReports.push({ 
        region_score: region.change_score, 
        report: {
          ...agent4Output,
          severity: agent4Input.severity,
          damage_type: agent4Input.damage_type,
          description: agent4Input.description,
        }
      });
    }

    return { status: 'completed', reports: finalReports };
    } catch (error) {
      if (error.response) {
        this.logger.error(`Error in photo inspection (Axios Response): ${JSON.stringify(error.response.data)}`);
      }
      this.logger.error(`Error in photo inspection: ${error.message}`, error.stack);
      throw error;
    }
  }

  /**
   * Flow 2: Text-Based Inspection (Agent 3 -> Agent 4)
   */
  async processTextInspection(
    itemType: string,
    complaintText: string,
    deviceModel: string, // e.g. "Dell G15"
  ): Promise<any> {
    this.logger.log(`Starting Text Inspection for ${deviceModel} (${itemType})`);
    
    // 1. Call Agent 3 Locally
    try {
      const agent3Response = await axios.post(`${this.localAgentUrl}/agent3/classify`, {
        item_type: itemType,
        complaint_text: complaintText,
        brand: deviceModel.split(' ')[0], // Extract brand from deviceModel (rough approximation)
      });

      const agent3Raw = agent3Response.data;
    
    // 2. Glue: Prepare Agent 4 input
    const agent4Input = this.glueService.toAgent4Input(agent3Raw, deviceModel);

    if (!agent4Input) {
      return { status: 'human_review', reason: 'Classification unavailable' };
    }

    // 3. Call Agent 4 Locally
    const agent4Response = await axios.post(`${this.localAgentUrl}/agent4/estimate`, {
      device_model: agent4Input.device_model,
      damage_type: agent4Input.damage_type,
      severity: agent4Input.severity,
      description: agent4Input.description,
    });

    // 4. Glue: Parse Agent 4 output
    const agent4Output = this.glueService.parseAgent4Output(agent4Response.data, agent3Raw);

    return { 
      status: 'completed', 
      reports: [{
        report: {
          ...agent4Output,
          severity: agent4Input.severity,
          damage_type: agent4Input.damage_type,
          description: agent4Input.description,
        }
      }]
    };
    } catch (error) {
      this.logger.error(`Error in text inspection: ${error.message}`, error.stack);
      throw error;
    }
  }

  /**
   * Flow 3: Real-Time Video Monitoring (Agent 5)
   */
  async processVideoMonitoring(itemId: string, videoPath: string, maxSeconds?: number): Promise<any> {
    this.logger.log(`Starting Video Monitoring (Agent 5) for ${itemId} on ${videoPath}`);
    try {
      const response = await axios.post(`${this.localAgentUrl}/agent5/monitor`, {
        item_id: itemId,
        video_path: videoPath,
        max_seconds: maxSeconds,
      }, {
        timeout: 300000, // 5 min timeout for video processing
      });
      return response.data;
    } catch (error) {
      this.logger.error(`Error in processVideoMonitoring: ${error.message}`);
      throw error;
    }
  }
}
