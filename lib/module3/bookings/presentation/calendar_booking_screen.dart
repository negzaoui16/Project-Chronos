import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/module3/auth/bloc/auth_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_state.dart';
import 'package:frontend/module3/bookings/presentation/booking_confirmation_screen.dart';

class CalendarBookingScreen extends StatefulWidget {
  final String? assetId;
  const CalendarBookingScreen({super.key, this.assetId});

  @override
  State<CalendarBookingScreen> createState() => _CalendarBookingScreenState();
}

class _CalendarBookingScreenState extends State<CalendarBookingScreen> {
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;

  int _maxDays = 3;
  String _assetName = 'Instrument';
  bool _isFetchingAsset = true;
  bool _isLoading = false;
  final ApiClient _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
    _fetchAssetDetails();
  }

  Future<void> _fetchAssetDetails() async {
    if (widget.assetId == null) {
      setState(() => _isFetchingAsset = false);
      return;
    }
    try {
      final authState = context.read<AuthBloc>().state;
      String token = '';
      if (authState is AuthAuthenticated) token = authState.token;
      
      final res = await _apiClient.dio.get(
        '/assets/${widget.assetId}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (mounted) {
        setState(() {
          _maxDays = res.data['maxReservationDays'] ?? 3;
          _assetName = res.data['name'] ?? 'Instrument';
          _isFetchingAsset = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingAsset = false);
    }
  }

  String _formatDateTime(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return 'Select Date & Time';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}, ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submitBooking() async {
    if (widget.assetId == null || _startDate == null || _startTime == null || _endDate == null || _endTime == null) return;

    final startDateTime = DateTime(_startDate!.year, _startDate!.month, _startDate!.day, _startTime!.hour, _startTime!.minute);
    final endDateTime = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, _endTime!.hour, _endTime!.minute);

    if (endDateTime.isBefore(startDateTime) || endDateTime.difference(startDateTime).inMinutes < 60) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum reservation duration is 1 hour.'), backgroundColor: Color(0xFFEF4444)));
      return;
    }

    final durationDays = endDateTime.difference(startDateTime).inDays;
    if (durationDays > _maxDays || (durationDays == _maxDays && endDateTime.difference(startDateTime).inHours % 24 > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Maximum reservation for this asset is $_maxDays days.'), backgroundColor: const Color(0xFFEF4444)));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final startTime = startDateTime;
      final endTime = endDateTime;

      final authState = context.read<AuthBloc>().state;
      String token = '';
      if (authState is AuthAuthenticated) {
        token = authState.token;
      }

      final response = await _apiClient.dio.post(
        '/bookings',
        data: {
          'assetId': widget.assetId,
          'startTime': startTime.toIso8601String(),
          'endTime': endTime.toIso8601String(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final booking = response.data;
      final txHash = booking['escrowTxHash'] ?? '';
      final depositAmount = booking['escrowDepositAmount'] ?? '20';
      final assetName = booking['asset']?['name'] ?? 'Instrument';
      
      final startDateStr = '${startTime.day}/${startTime.month}/${startTime.year} ${startTime.hour.toString().padLeft(2, '0')}:00';
      final endDateStr = '${endTime.hour.toString().padLeft(2, '0')}:00';
      final timeSlot = '$startDateStr - $endDateStr';

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BookingConfirmationScreen(
              assetName: assetName,
              timeSlot: timeSlot,
              depositAmount: depositAmount,
              txHash: txHash,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errMsg = 'Failed to create booking';
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
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
          'BOOKING CALENDAR',
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
            if (_isFetchingAsset)
              const Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator(color: Color(0xFF0D0096))))
            else ...[
              Text(
                'Reserving $_assetName',
                style: const TextStyle(
                  fontFamily: 'Newsreader',
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Maximum allowed duration: $_maxDays days',
                style: const TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 36),

              // Start Time
              const Text('START DATE & TIME', style: TextStyle(fontFamily: 'Geist', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (date == null) return;
                  if (!context.mounted) return;
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (time != null) {
                    setState(() {
                      _startDate = date;
                      _startTime = time;
                      
                      // Auto-set end date/time to +1 hour
                      final startDt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                      final endDt = startDt.add(const Duration(hours: 1));
                      _endDate = endDt;
                      _endTime = TimeOfDay.fromDateTime(endDt);
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDateTime(_startDate, _startTime), style: const TextStyle(fontFamily: 'Geist', fontSize: 14, color: Color(0xFF0F172A))),
                      const Icon(Icons.calendar_month, color: Color(0xFF8083FF)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // End Time
              const Text('END DATE & TIME', style: TextStyle(fontFamily: 'Geist', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final initial = _startDate ?? DateTime.now();
                  final date = await showDatePicker(context: context, initialDate: initial, firstDate: initial, lastDate: initial.add(Duration(days: _maxDays)));
                  if (date == null) return;
                  if (!context.mounted) return;
                  final time = await showTimePicker(context: context, initialTime: _startTime ?? TimeOfDay.now());
                  if (time != null) setState(() { _endDate = date; _endTime = time; });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDateTime(_endDate, _endTime), style: const TextStyle(fontFamily: 'Geist', fontSize: 14, color: Color(0xFF0F172A))),
                      const Icon(Icons.calendar_month, color: Color(0xFF8083FF)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),

            // Next button
            ElevatedButton(
              onPressed: (_startDate != null && _startTime != null && _endDate != null && _endTime != null && !_isLoading && !_isFetchingAsset) ? _submitBooking : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8083FF),
                foregroundColor: const Color(0xFF0D0096),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Color(0xFF0D0096), strokeWidth: 2))
                : const Text(
                    'Confirm Time Slot',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ),
            ],
          ],
        ),
      ),
    );
  }
}
