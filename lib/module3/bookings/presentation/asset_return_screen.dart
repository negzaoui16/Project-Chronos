import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/module3/auth/bloc/auth_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_state.dart';

class AssetReturnScreen extends StatefulWidget {
  final String bookingId;
  const AssetReturnScreen({super.key, required this.bookingId});

  @override
  State<AssetReturnScreen> createState() => _AssetReturnScreenState();
}

class _AssetReturnScreenState extends State<AssetReturnScreen> {
  bool _isCapturing = false;
  bool _isAiInspectionPassed = false;
  bool _isWaitingForAdmin = false;
  bool _isAdminValidated = false;
  Timer? _pollingTimer;

  final ApiClient _apiClient = ApiClient();

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _onSimulateAiInspection() async {
    setState(() {
      _isCapturing = true;
    });

    // Simulate AI loading delay (bypassing the incomplete Python module)
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isCapturing = false;
        _isAiInspectionPassed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Inspection IA réussie : Équipement en parfait état.'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    }
  }

  Future<void> _startPollingForApproval() async {
    setState(() {
      _isWaitingForAdmin = true;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      String token = '';
      if (authState is AuthAuthenticated) token = authState.token;

      await _apiClient.dio.post(
        '/bookings/${widget.bookingId}/request-return',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isWaitingForAdmin = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la demande au serveur.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      try {
        final authState = context.read<AuthBloc>().state;
        String token = '';
        if (authState is AuthAuthenticated) token = authState.token;

        final response = await _apiClient.dio.get(
          '/bookings/${widget.bookingId}',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );

        final status = response.data['status'];
        if (status == 'PASSED' || status == 'COMPLETED' || status == 'COMPLETED_PASSED') {
          timer.cancel();
          if (mounted) {
            setState(() {
              _isWaitingForAdmin = false;
              _isAdminValidated = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎉 Succès : Retour validé par l\'Administrateur ! 20 CHRONOS remboursés.'),
                backgroundColor: Color(0xFF22C55E),
              ),
            );
            Navigator.pop(context);
          }
        }
      } catch (e) {
        // Silently ignore polling errors
      }
    });
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
          'CHECK-IN SCAN',
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
            const Text(
              'Equipment Quality Scan',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Align the returning hardware within the target framework below. The automated inspection model will verify component condition.',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),

            // Camera Scanner Box Frame
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: const Color(0xFF0B1326),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Mock camera guidelines target
                  if (!_isCapturing) ...[
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFC0C1FF).withValues(alpha: 0.5), width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFFC0C1FF),
                      size: 48,
                    ),
                  ] else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        CircularProgressIndicator(
                          color: Color(0xFF8083FF),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Processing change detections...',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 12,
                            color: Color(0xFFDAE2FD),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Warning Notice details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Color(0xFF8083FF), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Failure to capture a clean focused scan may delay staking guarantee releases.',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Capture Trigger
            if (!_isAiInspectionPassed)
              ElevatedButton(
                onPressed: _isCapturing ? null : _onSimulateAiInspection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8083FF),
                  foregroundColor: const Color(0xFF0D0096),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Étape 1 : Scanner l\'équipement (IA)',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (!_isWaitingForAdmin)
              ElevatedButton(
                onPressed: _startPollingForApproval,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E), // Green to indicate success of step 1
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Étape 2 : Demander l\'approbation Admin',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Column(
                children: const [
                  CircularProgressIndicator(color: Color(0xFF8083FF)),
                  SizedBox(height: 16),
                  Text(
                    'En attente de l\'Administrateur...',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
