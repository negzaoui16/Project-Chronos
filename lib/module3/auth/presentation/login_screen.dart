import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_event.dart';
import 'package:frontend/module3/auth/bloc/auth_state.dart';
import 'package:frontend/module3/auth/presentation/register_screen.dart';
import 'package:frontend/module3/auth/presentation/forgot_password_screen.dart';
import 'package:frontend/module3/marketplace/presentation/marketplace_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSignInPressed() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            LoginRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text,
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
                // Top 40%: Hero Image Section (~350px height)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: size.height * 0.4 > 350 ? size.height * 0.4 : 350,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(
                            'https://lh3.googleusercontent.com/aida-public/AB6AXuAWWvwLTI6e9ZZ_TTVKKlKKEwXrezGUElghkP5WbJh0bls8LgQXi2PrT_k2Fey8j1S4RXUCwi0fSG2FUGnRgo3a851AQBcwr8aQYUgaFNbMkIVO75-9VuHFIRZYVeEB3kT4DoqgbquXWPBcerkoADjELrfZYyV2SN4tAEvi5d0NwWV8pfAjBMd3SiwOXMAd03vVQulXWXtKaiPtgM0uVRM7gVvOrCTzq2aWKfvP_W2ISLtA3QlDr4a1',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // Dark overlay gradient matching Tailwind colors
                    Container(
                      height: size.height * 0.4 > 350 ? size.height * 0.4 : 350,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF060E20).withValues(alpha: 0.4),
                            const Color(0xFF060E20).withValues(alpha: 0.6),
                            const Color(0xFF060E20).withValues(alpha: 0.9),
                          ],
                        ),
                      ),
                    ),
                    // Logo & Brand title
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'CHRONOS',
                          style: TextStyle(
                            fontFamily: 'Newsreader',
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFC0C1FF), // primary color
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ACADEMIC OPERATING SYSTEM',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFDAE2FD).withValues(alpha: 0.7),
                            letterSpacing: 2.4, // tracking-[0.2em]
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Bottom 60%: Login Sheet (Overlapping with negative margin)
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Welcome Header
                            const Text(
                              'Welcome Back',
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
                              'Access your campus resources and activity',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 14,
                                color: Color(0xFF64748B), // Slate-500
                              ),
                            ),
                            const SizedBox(height: 36),

                            // Email field
                            const Text(
                              'INSTITUTIONAL EMAIL',
                              style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0B1326), // surface-dim
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
                                color: Color(0xFF1E293B),
                              ),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.alternate_email,
                                  color: Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                hintText: 'name@university.edu',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF8083FF), width: 1.5),
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
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Password field
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'PASSWORD',
                                  style: TextStyle(
                                    fontFamily: 'Geist',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0B1326), // surface-dim
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                                    );
                                  },
                                  child: const Text(
                                    'Forgot?',
                                    style: TextStyle(
                                      fontFamily: 'Geist',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF00A2E6), // secondary-container
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _onSignInPressed(),
                              style: const TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 15,
                                color: Color(0xFF1E293B),
                              ),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Color(0xFF94A3B8),
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
                                hintText: '••••••••',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF8083FF), width: 1.5),
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
                                return null;
                              },
                            ),
                            const SizedBox(height: 36),

                            // Sign In Button
                            BlocBuilder<AuthBloc, AuthState>(
                              builder: (context, state) {
                                return ElevatedButton(
                                  onPressed: state is AuthLoading ? null : _onSignInPressed,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8083FF),
                                    foregroundColor: const Color(0xFF0D0096),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    elevation: 4,
                                    shadowColor: const Color(0xFF8083FF).withValues(alpha: 0.3),
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
                                      : const Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontFamily: 'Geist',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                );
                              },
                            ),
                            const SizedBox(height: 32),

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
                                    'SECURE AUTHENTICATION',
                                    style: TextStyle(
                                      fontFamily: 'Geist',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF94A3B8),
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

                            // Alternative Auth Buttons (SSO, Web3 ID)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      // SSO login trigger
                                    },
                                    icon: const Icon(
                                      Icons.admin_panel_settings_outlined,
                                      color: Color(0xFF334155), // Slate-700
                                      size: 20,
                                    ),
                                    label: const Text(
                                      'SSO',
                                      style: TextStyle(
                                        fontFamily: 'Geist',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      // Web3 Wallet connection trigger
                                    },
                                    icon: const Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: Color(0xFF334155),
                                      size: 20,
                                    ),
                                    label: const Text(
                                      'Web3 ID',
                                      style: TextStyle(
                                        fontFamily: 'Geist',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 36),

                            // Footer Request Access link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'New to the system? ',
                                  style: TextStyle(
                                    fontFamily: 'Geist',
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                    );
                                  },
                                  child: const Text(
                                    'Request Access',
                                    style: TextStyle(
                                      fontFamily: 'Geist',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
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
