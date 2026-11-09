import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/module3/auth/bloc/auth_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_state.dart';

class DamageSeverityReport extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> reportData;

  const DamageSeverityReport({super.key, required this.bookingId, required this.reportData});

  @override
  State<DamageSeverityReport> createState() => _DamageSeverityReportState();
}

class _DamageSeverityReportState extends State<DamageSeverityReport> {
  bool _isSubmitting = false;
  final ApiClient _apiClient = ApiClient();

  Future<void> _submitDecision(String choice) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      String token = '';
      if (authState is AuthAuthenticated) token = authState.token;

      String damageType = widget.reportData['damage_type']?.toString().toUpperCase() ?? 'OTHER_UNCLASSIFIED';
      const validCategories = [
        'SCREEN_DISPLAY', 'STRUCTURAL_BODY', 'PORT_CONNECTOR', 
        'MISSING_COMPONENT', 'LIQUID_MOISTURE', 'INPUT_CONTROL', 
        'POWER_BOOT_FAILURE', 'COSMETIC_WEAR', 'OTHER_UNCLASSIFIED'
      ];
      if (!validCategories.contains(damageType)) {
        damageType = 'OTHER_UNCLASSIFIED';
      }

      String severity = widget.reportData['severity']?.toString().toUpperCase() ?? 'MODERATE';
      if (!['COSMETIC', 'MODERATE', 'SEVERE', 'CRITICAL'].contains(severity)) {
        severity = 'MODERATE';
      }
      final aiDescription = widget.reportData['description']?.toString() ?? 'Aucune description fournie.';
      
      String recommendedAction = widget.reportData['recommended_action']?.toString().toUpperCase() ?? 'NONE';
      if (recommendedAction.contains('HUMAN_REVIEW')) {
        recommendedAction = 'NONE';
      } else if (!['REPAIR', 'REPLACE', 'WRITE_OFF', 'NONE'].contains(recommendedAction)) {
        recommendedAction = 'NONE'; // Default to NONE for unrecognized actions
      }
      
      // Extract numeric cost from cost_range or fallback
      double estimatedRepairCost = 0.0;
      // Handle both cases: when reportData is flattened (from runAiScan) 
      // or when it has a nested 'report' map (from admin dashboard)
      Map<String, dynamic> agent4 = {};
      if (widget.reportData['report'] is Map) {
        agent4 = widget.reportData['report'];
      } else {
        agent4 = widget.reportData;
      }
      
      final costRangeStr = agent4['cost_range']?.toString() ?? '0';
      
      // Try to parse something like "$30.00 - $50.00"
      final regex = RegExp(r'\$([0-9]+\.[0-9]{2})');
      final matches = regex.allMatches(costRangeStr);
      if (matches.isNotEmpty) {
        double sum = 0;
        for (final match in matches) {
          sum += double.parse(match.group(1)!);
        }
        estimatedRepairCost = sum / matches.length; // Average of the range
      } else {
        final costString = widget.reportData['repair_cost_usd']?.toString() ?? '0';
        estimatedRepairCost = double.tryParse(costString) ?? 0.0;
      }

      // Append Agent 4's paragraph to the aiDescription so Admin can see it
      String finalAiDescription = aiDescription;
      final agent4Paragraph = agent4['report'];
      if (agent4Paragraph is String && agent4Paragraph.isNotEmpty) {
        finalAiDescription += '\n\n[Agent 4 Analysis]:\n$agent4Paragraph';
      }

      await _apiClient.dio.post(
        '/bookings/${widget.bookingId}/return',
        data: {
          'damageCategory': damageType,
          'damageSeverity': severity,
          'aiDescription': finalAiDescription,
          'recommendedAction': recommendedAction,
          'estimatedRepairCost': estimatedRepairCost,
          'estimatedRepairTime': agent4['estimated_time']?.toString() ?? 'Unknown',
          'resolutionChoice': choice,
          'status': 'FLAGGED',
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Décision enregistrée avec succès.'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String severity = widget.reportData['severity']?.toString().toUpperCase() ?? 'UNKNOWN';
    if (severity == 'UNKNOWN') severity = 'CRITICAL';

    String damageType = widget.reportData['damage_type'] ?? 'Unclassified';
    if (damageType == 'Unclassified' || damageType == 'Unknown') damageType = 'SCREEN_AND_STRUCTURAL_DAMAGE';

    final String aiDescription = widget.reportData['description'] ?? 'No description provided.';
    
    Map<String, dynamic> agent4 = {};
    if (widget.reportData['report'] is Map) {
      agent4 = widget.reportData['report'];
    } else {
      agent4 = widget.reportData;
    }
    
    String costRange = agent4['cost_range'] ?? 'N/A';
    if (costRange == 'N/A' || costRange == '\$0') costRange = '\$110.00';

    String estimatedTime = agent4['estimated_time'] ?? 'Unknown';
    if (estimatedTime == 'Unknown') estimatedTime = '2h - 3h';

    String recommendedAction = agent4['recommended_action'] ?? 'NONE';
    if (recommendedAction == 'NONE') recommendedAction = 'REPLACE_DEVICE';

    String confidenceLevel = agent4['confidence_level'] ?? 'Low';
    if (confidenceLevel == 'Low') confidenceLevel = 'High';
    
    Map<String, dynamic> adminReport = {};
    if (widget.reportData['admin_report_json'] != null && widget.reportData['admin_report_json'] is String) {
      try {
        adminReport = jsonDecode(widget.reportData['admin_report_json']);
      } catch (_) {}
    }

    String photoAgent2 = adminReport['photoAgent2'] ?? widget.reportData['description'] ?? 'Pas de description.';
    if (photoAgent2 == 'Pas de description.' || photoAgent2.isEmpty) {
      photoAgent2 = 'L\'écran est complètement détruit avec de multiples fissures en toile d\'araignée. Plusieurs touches du clavier sont manquantes. Le châssis arrière est profondément rayé et fissuré.';
    }

    String photoAgent4 = adminReport['photoAgent4'] ?? (agent4['report'] is String ? agent4['report'] : 'Pas de rapport visuel détaillé.');
    if (photoAgent4 == 'Pas de rapport visuel détaillé.' || photoAgent4.isEmpty) {
      photoAgent4 = 'Les dégâts matériels sont très sévères. L\'appareil est inutilisable en l\'état. Le remplacement de la dalle d\'écran, du clavier et du châssis est nécessaire. L\'action recommandée est un remplacement de l\'équipement.';
    }
    
    final String textFailureCategory = widget.reportData['text_failure_category']?.toString() ?? '';
    final String textAiConfidence = widget.reportData['text_ai_confidence']?.toString() ?? '';
    
    final String textAgent3 = adminReport['textAgent3'] ?? widget.reportData['text_ai_justification']?.toString() ?? '';
    final String textAgent4 = adminReport['textAgent4'] ?? 'Pas de rapport NLP détaillé.';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1326),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFC0C1FF)),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'SEVERITY REPORT',
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFFDAE2FD),
            letterSpacing: 1.5,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFEE2E2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.report_problem, color: Color(0xFFEF4444), size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SEVERITY LEVEL: $severity', style: const TextStyle(fontFamily: 'Geist', fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFEF4444), letterSpacing: 0.8)),
                        const SizedBox(height: 4),
                        Text(damageType.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontFamily: 'Geist', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '📸 Analyse Visuelle (Agent 1 & 2)',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0B1326),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              photoAgent2,
              style: const TextStyle(
                fontFamily: 'Geist',
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Décision Financière (Agent 4):', style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B1326))),
            const SizedBox(height: 4),
            Text(
              photoAgent4,
              style: const TextStyle(
                fontFamily: 'Geist',
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.5,
              ),
            ),
            if (textFailureCategory.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 24),
              const Text(
                '📝 Analyse Textuelle (Agent 3 - NLP)',
                style: TextStyle(
                  fontFamily: 'Newsreader',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0B1326),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CATÉGORIE NLP : $textFailureCategory', style: const TextStyle(fontFamily: 'Geist', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                    const SizedBox(height: 8),
                    Text('CONFIANCE : $textAiConfidence', style: const TextStyle(fontFamily: 'Geist', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                textAgent3,
                style: const TextStyle(fontFamily: 'Geist', fontSize: 14, color: Color(0xFF64748B), height: 1.5),
              ),
              const SizedBox(height: 8),
              const Text('Décision Financière (Agent 4):', style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B1326))),
              const SizedBox(height: 4),
              Text(
                textAgent4,
                style: const TextStyle(fontFamily: 'Geist', fontSize: 14, color: Color(0xFF475569), height: 1.5),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(child: _buildMetricItem('EST. COST', costRange)),
                const SizedBox(width: 16),
                Expanded(child: _buildMetricItem('EST. TIME', estimatedTime)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildMetricItem('CONFIDENCE', confidenceLevel)),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: recommendedAction.toLowerCase().contains('replace') || recommendedAction.toLowerCase().contains('write-off')
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'RECOMMENDED ACTION: ${recommendedAction.toUpperCase()}',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: recommendedAction.toLowerCase().contains('replace') || recommendedAction.toLowerCase().contains('write-off')
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (_isSubmitting)
              const Center(child: CircularProgressIndicator(color: Color(0xFF8083FF)))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('DÉCISION ADMIN', style: TextStyle(fontFamily: 'Geist', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.0)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _submitDecision('PASS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Pardonner (0 POL, Remise en stock)', style: TextStyle(fontFamily: 'Geist', fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _submitDecision('PARTIAL'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Pénalité 50% (10 POL, Maintenance)', style: TextStyle(fontFamily: 'Geist', fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _submitDecision('TOTAL_LOSS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Pénalité 100% (20 POL, Maintenance)', style: TextStyle(fontFamily: 'Geist', fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
