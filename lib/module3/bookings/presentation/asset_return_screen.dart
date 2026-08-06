import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  final ApiClient _apiClient = ApiClient();

  Future<void> _onCaptureScan() async {
    setState(() {
      _isCapturing = true;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      String token = '';
      if (authState is AuthAuthenticated) token = authState.token;

      await _apiClient.dio.post(
        '/bookings/${widget.bookingId}/return',
        data: {
          "damageCategory": "OTHER_UNCLASSIFIED",
          "damageSeverity": "COSMETIC",
          "aiDescription": "Mock AI Inspection passed.",
          "estimatedRepairCost": 0.0,
          "recommendedAction": "NONE",
          "status": "PASSED"
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        setState(() { _isCapturing = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return verified. 20 CHRONOS refunded to your wallet.'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
        Navigator.pop(context); // Go back to bookings list
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isCapturing = false; });
        String errMsg = 'Error during return inspection.';
        if (e is DioException && e.response?.data?['message'] != null) {
          final msgData = e.response!.data['message'];
          if (msgData is List) {
            errMsg = msgData.join(', ');
          } else {
            errMsg = msgData.toString();
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: Colors.redAccent,
          ),
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
            ElevatedButton(
              onPressed: _isCapturing ? null : _onCaptureScan,
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
                'Capture & Initiate Quality Check',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
