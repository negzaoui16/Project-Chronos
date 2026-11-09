import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
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
  Map<String, dynamic>? _aiReport;
  Map<String, dynamic>? _aiTextReport;
  Timer? _pollingTimer;

  File? _frontPhoto;
  File? _backPhoto;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _complaintController = TextEditingController();

  Future<void> _pickPhoto(bool isFront) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galerie'),
                onTap: () {
                  Navigator.of(context).pop();
                  _getImage(ImageSource.gallery, isFront);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Caméra'),
                onTap: () {
                  Navigator.of(context).pop();
                  _getImage(ImageSource.camera, isFront);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source, bool isFront) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          if (isFront) {
            _frontPhoto = File(image.path);
          } else {
            _backPhoto = File(image.path);
          }
        });
      }
    } catch (e) {
      // Ignored if camera fails
    }
  }

  final ApiClient _apiClient = ApiClient();

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _complaintController.dispose();
    super.dispose();
  }

  Future<void> _runRealAiInspection() async {
    if (_frontPhoto == null || _backPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez prendre les deux photos.')));
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      String token = '';
      if (authState is AuthAuthenticated) token = authState.token;

      final Map<String, dynamic> mapData = {};
      mapData['frontPhoto'] = await MultipartFile.fromFile(_frontPhoto!.path);
      mapData['backPhoto'] = await MultipartFile.fromFile(_backPhoto!.path);
      mapData['complaintText'] = _complaintController.text;

      final formData = FormData.fromMap(mapData);

      final response = await _apiClient.dio.post(
        '/bookings/${widget.bookingId}/run-ai-scan',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          receiveTimeout: const Duration(minutes: 15), // L'IA peut prendre jusqu'à 15 min
        ),
      );

      final status = response.data['status'];

      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isAiInspectionPassed = true;
        });

        if (status == 'no_damage') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Inspection IA réussie : Équipement en parfait état.'),
              backgroundColor: Color(0xFF22C55E),
            ),
          );
        } else {
          if (response.data['reports'] != null && response.data['reports'].isNotEmpty) {
            _aiReport = response.data['reports'][0]['report'];
            if (response.data['reports'].length > 1) {
              _aiTextReport = response.data['reports'][1]['report'];
            }
          } else {
            _aiReport = response.data['report'];
          }
          // Ne pas utiliser de snackbar ici, l'UI va se mettre à jour avec _aiReport
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'analyse IA. Réessayez.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
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
            // Dual Camera Scanner Frame
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _isCapturing ? null : () => _pickPhoto(true),
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1326),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        image: _frontPhoto != null
                            ? DecorationImage(image: FileImage(_frontPhoto!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _frontPhoto == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.camera_alt, color: Color(0xFFC0C1FF), size: 32),
                                SizedBox(height: 8),
                                Text('Face (De devant)', style: TextStyle(color: Color(0xFFDAE2FD), fontFamily: 'Geist', fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: _isCapturing ? null : () => _pickPhoto(false),
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1326),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        image: _backPhoto != null
                            ? DecorationImage(image: FileImage(_backPhoto!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _backPhoto == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.camera_alt, color: Color(0xFFC0C1FF), size: 32),
                                SizedBox(height: 8),
                                Text('Dos (De derrière)', style: TextStyle(color: Color(0xFFDAE2FD), fontFamily: 'Geist', fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Optional Complaint Text Field
            TextField(
              controller: _complaintController,
              enabled: !_isCapturing && !_isAiInspectionPassed,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Optionnel: Décrivez le problème (min 10 lettres pour activer l\'Agent 3)...',
                hintStyle: const TextStyle(fontFamily: 'Geist', fontSize: 13, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8083FF)),
                ),
              ),
            ),
            if (_isCapturing) ...[
              const SizedBox(height: 16),
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF8083FF)),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Patientez... Les 4 Agents IA analysent vos données (cela peut prendre jusqu\'à 15 minutes)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: Color(0xFF64748B))
                ),
              ),
            ],
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

            // Agent 4 AI Report UI
            if (_aiReport != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        Text(
                          'SÉVÉRITÉ : ${_aiReport!['severity']?.toString().toUpperCase()}',
                          style: const TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _aiReport!['damage_type']?.toString().toUpperCase() ?? 'DÉGÂT INCONNU',
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Décision Financière (Analyse Image):', style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B1326))),
                    const SizedBox(height: 4),
                    Text(
                      _aiReport!['report'] is String ? _aiReport!['report'] : 'Pas de rapport visuel détaillé.',
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 14,
                        color: Color(0xFF475569),
                        height: 1.5,
                      ),
                    ),
                    if (_aiTextReport != null) ...[
                      const SizedBox(height: 16),
                      const Text('Décision Financière (Analyse Plainte):', style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0B1326))),
                      const SizedBox(height: 4),
                      Text(
                        _aiTextReport!['report'] is String ? _aiTextReport!['report'] : 'Pas de rapport NLP détaillé.',
                        style: const TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 14,
                          color: Color(0xFF475569),
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, color: Color(0xFF16A34A), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ACTION RECOMMANDÉE: ${_aiReport!['recommended_action']?.toString().toUpperCase()}',
                              style: const TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
            ],

            // Capture Trigger
            if (!_isAiInspectionPassed && _aiReport == null)
              ElevatedButton(
                onPressed: (_isCapturing || _frontPhoto == null || _backPhoto == null) 
                  ? null 
                  : _runRealAiInspection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B1326),
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Soumettre pour Inspection IA', style: TextStyle(fontFamily: 'Geist', fontSize: 14, fontWeight: FontWeight.bold)),
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
