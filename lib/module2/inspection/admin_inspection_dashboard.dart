import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/module3/auth/bloc/auth_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_state.dart';
import 'package:frontend/module2/inspection/change_detection_view.dart';
import 'package:frontend/module2/inspection/damage_severity_report.dart';
import 'package:frontend/module2/inspection/lab_monitoring_screen.dart' as frontend_lab_monitoring;

class AdminInspectionDashboard extends StatefulWidget {
  const AdminInspectionDashboard({super.key});

  @override
  State<AdminInspectionDashboard> createState() => _AdminInspectionDashboardState();
}

class _AdminInspectionDashboardState extends State<AdminInspectionDashboard> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = true;
  List<dynamic> _activeBookings = [];
  bool _isSubmitting = false;
  Timer? _adminPollingTimer;
  int _totalRuns = 0;
  int _flaggedCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchActiveBookings();
    _adminPollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _fetchActiveBookings(silent: true);
    });
  }

  @override
  void dispose() {
    _adminPollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchActiveBookings({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final authState = context.read<AuthBloc>().state;
      String token = '';
      if (authState is AuthAuthenticated) token = authState.token;

      final response = await _apiClient.dio.get(
        '/bookings',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final List<dynamic> allBookings = response.data;
      setState(() {
        _activeBookings = allBookings.where((b) => b['status'] == 'PENDING_RETURN').toList();
        _totalRuns = allBookings.length;
        _flaggedCount = allBookings.where((b) => b['inspection'] != null && b['inspection']['status'] == 'FLAGGED').length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur de chargement des réservations.'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Strict Visual Rule: Pure White background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1326),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFC0C1FF)),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'INSPECTION HUB',
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFFDAE2FD),
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Color(0xFFDAE2FD)),
            tooltip: 'Surveillance Vidéo (Agent 5)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const frontend_lab_monitoring.LabMonitoringScreen()),
              );
            },
          ),
        ],
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchActiveBookings,
        color: const Color(0xFF8083FF),
        backgroundColor: const Color(0xFF0B1326),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quick Statistics Header
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Total Runs', '$_totalRuns', const Color(0xFF8083FF)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard('Flagged', '$_flaggedCount', const Color(0xFFEF4444)),
                ),
              ],
            ),
            const SizedBox(height: 36),

            // Inspections List Header
            const Text(
              'Inspection Log Feed',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),

            // Inspection List
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: Color(0xFF8083FF)))
            else if (_activeBookings.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 24.0),
                  child: Text('Aucune réservation en attente de retour.', style: TextStyle(color: Colors.grey, fontFamily: 'Geist', fontSize: 14)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _activeBookings.length,
                itemBuilder: (context, index) {
                  final booking = _activeBookings[index];
                  final bookingId = booking['id'] ?? 'N/A';
                  final assetName = booking['asset']?['name'] ?? 'Équipement inconnu';
                  final userName = booking['user']?['name'] ?? 'Étudiant inconnu';
                  final bookingDate = booking['startTime'] != null 
                      ? DateTime.parse(booking['startTime']).toLocal().toString().split(' ')[0] 
                      : 'Date inconnue';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bookingId.toString().length > 8 ? bookingId.toString().substring(0, 8) + '...' : bookingId,
                                    style: const TextStyle(
                                      fontFamily: 'Geist',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    assetName,
                                    style: const TextStyle(
                                      fontFamily: 'Geist',
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0E7FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'PENDING RETURN',
                                style: TextStyle(
                                  fontFamily: 'Geist',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: Color(0xFFF1F5F9), height: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Étudiant : $userName',
                                style: const TextStyle(
                                  fontFamily: 'Geist',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              bookingDate,
                              style: const TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            final inspection = booking['inspection'] ?? {};
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DamageSeverityReport(
                                  bookingId: bookingId.toString(),
                                  reportData: {
                                    'severity': inspection['damageSeverity'] ?? 'UNKNOWN',
                                    'damage_type': inspection['damageCategory'] ?? 'Unclassified',
                                    'description': inspection['aiDescription'] ?? 'No AI description provided.',
                                    'repair_cost_usd': inspection['estimatedRepairCost']?.toString() ?? '0',
                                    'recommended_action': inspection['recommendedAction'] ?? 'NONE',
                                    
                                    'text_failure_category': inspection['failureCategory'],
                                    'text_ai_confidence': inspection['aiConfidence'],
                                    'text_ai_justification': inspection['aiJustification'],
                                    'admin_report_json': inspection['adminReport'],

                                    'report': {
                                      'confidence_level': 'High',
                                      'recommended_action': inspection['recommendedAction'] ?? 'NONE',
                                      'cost_range': inspection['estimatedRepairCost'] != null && inspection['estimatedRepairCost'] > 0 ? '\$${inspection['estimatedRepairCost']}' : 'N/A',
                                      'estimated_time': inspection['estimatedRepairTime'] ?? 'Unknown',
                                    },
                                  },
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B1326),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.assignment_turned_in, size: 18),
                          label: const Text(
                            'Voir Rapport IA (Décision)',
                            style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
