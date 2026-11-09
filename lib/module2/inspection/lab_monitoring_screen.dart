import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'dart:io';

class LabMonitoringScreen extends StatefulWidget {
  const LabMonitoringScreen({super.key});

  @override
  State<LabMonitoringScreen> createState() => _LabMonitoringScreenState();
}

class _LabMonitoringScreenState extends State<LabMonitoringScreen> {
  final ImagePicker _picker = ImagePicker();
  final ApiClient _apiClient = ApiClient();

  File? _selectedVideo;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  String? _errorMessage;

  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _selectedVideo = File(video.path);
          _analysisResult = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error selecting video: $e';
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _analyzeVideo() async {
    if (_selectedVideo == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final formData = FormData.fromMap({
        'itemId': 'LAB_001',
        'startTime':
            '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        'endTime':
            '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        'file': await MultipartFile.fromFile(_selectedVideo!.path,
            filename: 'lab_video.mp4'),
      });

      final response = await _apiClient.dio.post(
        '/inspection/video',
        data: formData,
        options: Options(
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
        ),
      );

      setState(() {
        _analysisResult = response.data;
      });
    } on DioException catch (e) {
      setState(() {
        _errorMessage =
            'API Error: ${e.response?.data?['message'] ?? e.message}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1326),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFC0C1FF)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agent 5: Video Surveillance',
              style: TextStyle(
                color: Color(0xFFDAE2FD),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'YOLOv8 Vision AI • Live Monitoring',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildVideoUploadCard(),
            const SizedBox(height: 16),
            _buildTimeSelectorRow(),
            const SizedBox(height: 20),
            _buildAnalyzeButton(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorBanner(),
            ],
            if (_analysisResult != null) _buildResultSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoUploadCard() {
    final fileName = _selectedVideo != null
        ? _selectedVideo!.path.split(Platform.pathSeparator).last
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _selectedVideo != null
              ? const Color(0xFF6366F1).withOpacity(0.4)
              : const Color(0xFFE2E8F0),
          width: _selectedVideo != null ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _selectedVideo != null
                    ? [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)]
                    : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _selectedVideo != null
                  ? Icons.videocam_rounded
                  : Icons.cloud_upload_outlined,
              size: 40,
              color: _selectedVideo != null
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _selectedVideo != null
                ? 'Video stream ready for analysis'
                : 'Upload Laboratory Video',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          if (_selectedVideo != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      fileName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Supported formats: MP4, MOV, AVI',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w400,
              ),
            ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _isAnalyzing ? null : _pickVideo,
            icon: Icon(
              _selectedVideo != null ? Icons.sync_rounded : Icons.add_circle_outline,
              size: 18,
              color: const Color(0xFF4F46E5),
            ),
            label: Text(
              _selectedVideo != null ? 'Change Video' : 'Browse Files',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4F46E5),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              side: const BorderSide(color: Color(0xFFC7D2FE), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: const Color(0xFFEEF2FF).withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelectorRow() {
    return Row(
      children: [
        Expanded(
          child: _buildTimeCard(
            label: 'Start Time',
            time: _startTime,
            icon: Icons.access_time_filled_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () => _selectTime(context, true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTimeCard(
            label: 'End Time',
            time: _endTime,
            icon: Icons.timelapse_rounded,
            color: const Color(0xFF8B5CF6),
            onTap: () => _selectTime(context, false),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeCard({
    required String label,
    required TimeOfDay time,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final formattedTime =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: _isAnalyzing ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedTime,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    final isReady = _selectedVideo != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isReady && !_isAnalyzing
            ? const LinearGradient(
                colors: [Color(0xFF0B1326), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        boxShadow: isReady && !_isAnalyzing
            ? [
                BoxShadow(
                  color: const Color(0xFF0B1326).withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: (isReady && !_isAnalyzing) ? _analyzeVideo : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isReady ? Colors.transparent : const Color(0xFFCBD5E1),
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isAnalyzing
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(width: 14),
                  Text(
                    'AI Analysis in progress (YOLOv8)...',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.analytics_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _selectedVideo == null
                        ? 'Please select a video'
                        : 'Run AI Video Analysis',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFEE2E2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFDC2626), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    final baseline =
        _analysisResult!['baseline_inventory'] as Map<String, dynamic>? ?? {};
    final finalInv =
        _analysisResult!['final_inventory'] as Map<String, dynamic>? ?? {};
    final missing =
        _analysisResult!['missing_items'] as Map<String, dynamic>? ?? {};
    final events =
        _analysisResult!['missing_events'] as List<dynamic>? ?? [];

    int totalStart = 0;
    int totalEnd = 0;
    int totalMissing = 0;

    for (var count in baseline.values) {
      if (count is num) totalStart += count.toInt();
    }
    for (var count in finalInv.values) {
      if (count is num) totalEnd += count.toInt();
    }
    for (var count in missing.values) {
      if (count is num) totalMissing += count.toInt();
    }

    final hasDiscrepancy = totalMissing > 0 || events.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AI Inspection Report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasDiscrepancy
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  hasDiscrepancy ? 'ANOMALY' : 'CLEAR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: hasDiscrepancy
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatusBanner(hasDiscrepancy, totalMissing),
          const SizedBox(height: 16),
          _buildQuickStats(totalStart, totalEnd, totalMissing),
          const SizedBox(height: 16),
          _buildInventoryComparisonCard(baseline, finalInv, missing),
          if (events.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildTimelineCard(events),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBanner(bool hasDiscrepancy, int missingCount) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hasDiscrepancy
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFF0FDF4),
        border: Border.all(
          color: hasDiscrepancy
              ? const Color(0xFFFECACA)
              : const Color(0xFFBBF7D0),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasDiscrepancy
                  ? const Color(0xFFEF4444).withOpacity(0.12)
                  : const Color(0xFF22C55E).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasDiscrepancy
                  ? Icons.warning_rounded
                  : Icons.verified_rounded,
              color: hasDiscrepancy
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF16A34A),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasDiscrepancy
                      ? 'Equipment Discrepancy Detected!'
                      : 'Session Validated - No Discrepancy Detected',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: hasDiscrepancy
                        ? const Color(0xFF991B1B)
                        : const Color(0xFF166534),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasDiscrepancy
                      ? '$missingCount item(s) were removed before the end of the session without being returned.'
                      : 'All equipment recorded at the beginning remained under monitoring until the end.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: hasDiscrepancy
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFF15803D),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(int start, int end, int missing) {
    return Row(
      children: [
        Expanded(
          child: _buildStatTile(
            title: 'Initial Count',
            value: '$start',
            color: const Color(0xFF3B82F6),
            bg: const Color(0xFFEFF6FF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            title: 'Final Count',
            value: '$end',
            color: const Color(0xFF10B981),
            bg: const Color(0xFFECFDF5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatTile(
            title: 'Missing Items',
            value: '$missing',
            color: missing > 0
                ? const Color(0xFFEF4444)
                : const Color(0xFF64748B),
            bg: missing > 0
                ? const Color(0xFFFEF2F2)
                : const Color(0xFFF8FAFC),
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryComparisonCard(
    Map<String, dynamic> baseline,
    Map<String, dynamic> finalInv,
    Map<String, dynamic> missing,
  ) {
    final allKeys = {...baseline.keys, ...finalInv.keys}.toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 18, color: Color(0xFF4F46E5)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Equipment Breakdown by Category',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          ...allKeys.map((key) {
            final startCount = baseline[key] ?? 0;
            final endCount = finalInv[key] ?? 0;
            final missingCount = missing[key] ?? 0;
            final isDiscrepant = startCount != endCount || missingCount > 0;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDiscrepant
                    ? const Color(0xFFFEF2F2).withOpacity(0.6)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDiscrepant
                      ? const Color(0xFFFECACA)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDiscrepant
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getIconForClass(key),
                      size: 20,
                      color: isDiscrepant
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatClassName(key),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (isDiscrepant)
                          Text(
                            'Net Loss: -$missingCount',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _buildQuantityBadge('Start', '$startCount',
                          const Color(0xFF64748B), const Color(0xFFF1F5F9)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 14, color: Color(0xFF94A3B8)),
                      ),
                      _buildQuantityBadge(
                        'End',
                        '$endCount',
                        isDiscrepant
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A),
                        isDiscrepant
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFDCFCE7),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuantityBadge(
      String label, String count, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildTimelineCard(List<dynamic> events) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 18, color: Color(0xFFEF4444)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Missing Events Timeline (Timestamp)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          ...events.map((event) {
            final timeInSeconds = event['confirmed_at'] as num;
            final minutes = (timeInSeconds / 60).floor();
            final seconds = (timeInSeconds % 60).floor();
            final timeString =
                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}s';
            final className =
                _formatClassName(event['class_name']?.toString() ?? 'Item');
            final missingCount = event['missing_count'] ?? 1;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.timer_outlined,
                        size: 16, color: Color(0xFFDC2626)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$className removed from frame',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Absence confirmed by AI (Quantity: $missingCount)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      timeString,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _getIconForClass(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('laptop')) return Icons.laptop_mac_rounded;
    if (lower.contains('tablet')) return Icons.tablet_mac_rounded;
    if (lower.contains('vr')) return Icons.view_in_ar_rounded;
    if (lower.contains('projector')) return Icons.videocam_outlined;
    if (lower.contains('keyboard')) return Icons.keyboard_rounded;
    if (lower.contains('mouse')) return Icons.mouse_rounded;
    return Icons.devices_other_rounded;
  }

  String _formatClassName(String name) {
    final lower = name.toLowerCase();
    if (lower == 'laptop') return 'Laptop Computer';
    if (lower == 'tablet') return 'Tablet';
    if (lower == 'vr_headset') return 'VR Headset';
    if (lower == 'projector') return 'Video Projector';
    return name.toUpperCase();
  }
}
