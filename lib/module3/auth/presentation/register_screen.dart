import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_event.dart';
import 'package:frontend/module3/auth/bloc/auth_state.dart';
import 'package:frontend/module3/auth/presentation/login_screen.dart';
import 'package:frontend/module3/marketplace/presentation/marketplace_home_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _selectedImagePath;

  @override
  void dispose() {
    _nameController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImagePath = pickedFile.path;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick profile image: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _scanStudentCard() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (pickedFile == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scanning student card...'),
          backgroundColor: Color(0xFF64748B),
        ),
      );

      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      // Esprit ID format: 3 digits + 3 letters + 4 digits (e.g. 243JMT5008)
      // Fallback: 8 digits
      final idRegex = RegExp(r'\b(\d{3}[A-Z]{3}\d{4}|\d{8})\b');
      
      String? foundId;
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          final match = idRegex.firstMatch(line.text.toUpperCase().replaceAll(' ', ''));
          if (match != null) {
            foundId = match.group(0);
            break;
          }
        }
        if (foundId != null) break;
      }

      if (!mounted) return;
      if (foundId != null) {
        setState(() {
          _studentIdController.text = foundId!;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student ID detected successfully!'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read Student ID from card. Please try again with good lighting.'),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 4),
          ),
        );
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to scan card: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _onInitializePressed() {

    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            RegisterRequested(
              name: _nameController.text.trim(),
              studentId: _studentIdController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
              imagePath: _selectedImagePath,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white, // Strict Visual Rule: Pure White background
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MarketplaceHomeScreen()),
            );
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          }
        },
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top 40%: Hero Context Section (~350px height)
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: size.height * 0.4 > 350 ? size.height * 0.4 : 350,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuB9_It526qwBCCwoZc-yjdGnr5AURfZ-lSru7nZJtv71pKuRj391BoRLdevugQPh-HoejCPZJGnBHqnO5ar3dx3lqQOoErpNal5ac5jMwJI0q85AhzgZF2eUToj914h0PxC5D5WmCyWhT-aKgRvUJu52pkuOTIyEdyitL0FiIjJXIboH_Kthpm291AMcg7Vo2X7A3UwtuaW9N1z3jb2XJg54iIBq-agXHo41MembXQFOCIYjg4ekPCN',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Dark overlay gradient matching Tailwind colors
                  Container(
                    height: size.height * 0.4 > 350 ? size.height * 0.4 : 350,
                    decoration: const BoxDecoration(
                      color: Color(0xCC0B1326), // bg-hero-overlay (rgba(11, 19, 38, 0.8))
                    ),
                  ),
                  // Branding & Subtitle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ACADEMIC OPERATING SYSTEM',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFC0C1FF), // primary
                            letterSpacing: 3.6, // tracking-[0.3em]
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Begin Your Tenure',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Newsreader',
                            fontSize: 32,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Bottom 60%: Interaction Onboarding Form (Overlapping negative margin)
              Transform.translate(
                offset: const Offset(0, -30),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white, // Pure White Onboarding Form
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1A000000), // rgba(0,0,0,0.1)
                        blurRadius: 40,
                        offset: Offset(0, -10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Form Header
                          const Text(
                            'Identity Verification',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Newsreader',
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0B1326), // surface-dim
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Initialize your workstation with academic credentials.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 14,
                              color: Color(0xFF64748B), // text-muted
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Profile Image Picker
                          Center(
                            child: GestureDetector(
                              onTap: _pickProfileImage,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: const Color(0xFFF1F5F9), // Slate-100
                                    backgroundImage: _selectedImagePath != null
                                        ? FileImage(File(_selectedImagePath!))
                                        : null,
                                    child: _selectedImagePath == null
                                        ? const Icon(
                                            Icons.person_add_alt_1_outlined,
                                            size: 40,
                                            color: Color(0xFF8083FF), // primary
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF8083FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Full Legal Name
                          const Text(
                            'Full Legal Name',
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B), // text-muted
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameController,
                            keyboardType: TextInputType.name,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 15,
                              color: Color(0xFF0B1326),
                            ),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: Color(0xFF94A3B8), // outline
                                size: 20,
                              ),
                              hintText: 'Dr. Julian Vane',
                              hintStyle: const TextStyle(color: Color(0x80908FA0)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC), // input-bg
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFC0C1FF), width: 1.5), // input-focus-accent
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFEF4444)),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Student ID
                          const Text(
                            'Student ID (Auto-Scan)',
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B), // text-muted
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _studentIdController,
                            readOnly: true,
                            onTap: _scanStudentCard,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 15,
                              color: Color(0xFF0B1326),
                            ),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.badge_outlined,
                                color: Color(0xFF94A3B8), // outline
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.document_scanner_outlined, color: Color(0xFF8083FF)),
                                onPressed: _scanStudentCard,
                                tooltip: 'Scan Student Card',
                              ),
                              hintText: 'Tap to scan card (e.g. 243JMT5008)',
                              hintStyle: const TextStyle(color: Color(0x80908FA0)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFC0C1FF), width: 1.5),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFEF4444)),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please scan your Student ID card';
                              }
                              final idRegex = RegExp(r'^(\d{3}[A-Z]{3}\d{4}|\d{8})$');
                              if (!idRegex.hasMatch(value.trim().toUpperCase())) {
                                return 'Invalid Student ID format';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // University Email
                          const Text(
                            'University Email',
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B), // text-muted
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 15,
                              color: Color(0xFF0B1326),
                            ),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.alternate_email,
                                color: Color(0xFF94A3B8), // outline
                                size: 20,
                              ),
                              hintText: 'vane.j@university.edu',
                              hintStyle: const TextStyle(color: Color(0x80908FA0)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFC0C1FF), width: 1.5),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFEF4444)),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your email';
                              }
                              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                              if (!emailRegex.hasMatch(value.trim())) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Secure Access Key (Password)
                          const Text(
                            'Secure Access Key',
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B), // text-muted
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _onInitializePressed(),
                            style: const TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 15,
                              color: Color(0xFF0B1326),
                            ),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xFF94A3B8), // outline
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  color: const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              hintText: '••••••••••••',
                              hintStyle: const TextStyle(color: Color(0x80908FA0)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFC0C1FF), width: 1.5),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFEF4444)),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ensure your key contains at least one technical symbol for high-level security clearance.',
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 10,
                              color: const Color(0xFF64748B).withValues(alpha: 0.6), // text-muted/60
                            ),
                          ),
                          const SizedBox(height: 36),

                           // Initialize Account Button
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, state) {
                              return ElevatedButton(
                                onPressed: state is AuthLoading ? null : _onInitializePressed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8083FF), // primary-container
                                  foregroundColor: const Color(0xFF0D0096), // on-primary-container
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 4,
                                  shadowColor: const Color(0xFF8083FF).withValues(alpha: 0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: state is AuthLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D0096)),
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Initialize Account',
                                            style: TextStyle(
                                              fontFamily: 'Geist',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.terminal,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                              );
                            },
                          ),
                          const SizedBox(height: 28),

                          // Divider
                          Row(
                            children: [
                              const Expanded(
                                child: Divider(
                                  color: Color(0xFFF1F5F9), // Slate-100
                                  thickness: 1.5,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Access Authorization',
                                  style: TextStyle(
                                    fontFamily: 'Geist',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(
                                  color: Color(0xFFF1F5F9), // Slate-100
                                  thickness: 1.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Footer link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Existing Researcher? ',
                                style: TextStyle(
                                  fontFamily: 'Geist',
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                                  );
                                },
                                child: const Text(
                                  'Sync Logs',
                                  style: TextStyle(
                                    fontFamily: 'Geist',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF8083FF), // primary-container
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
