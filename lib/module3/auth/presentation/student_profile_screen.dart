import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_state.dart';
import 'package:frontend/module3/auth/presentation/login_screen.dart';
import 'package:frontend/module1/wallet/wallet_balance_screen.dart';
import 'package:frontend/module1/wallet/reputation_score_screen.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});

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
          'SCHOLAR INDEX',
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
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          String name = 'Dr. Julian Vane';
          String email = 'vane.j@university.edu';
          String studentId = '88421092';
          String reputation = '92 pts (Lvl 4)';
          String profileImageUrl = 'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png';

          if (state is AuthAuthenticated) {
            name = state.user['name'] ?? name;
            email = state.user['email'] ?? email;
            studentId = state.user['studentId'] ?? studentId;
            final score = state.user['reputationScore'] ?? 100.0;
            reputation = '${score.toStringAsFixed(0)} pts';
            profileImageUrl = state.user['profileImageUrl'] ?? profileImageUrl;
          }

          return RefreshIndicator(
            color: const Color(0xFF8083FF),
            backgroundColor: const Color(0xFF0B1326),
            strokeWidth: 2.5,
            onRefresh: () async {
              // Reload latest profile data from the server via a short delay
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                // Profile image center
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF8083FF),
                            width: 3,
                          ),
                          image: DecorationImage(
                            image: NetworkImage(profileImageUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      CircleAvatar(
                        backgroundColor: const Color(0xFF8083FF),
                        radius: 16,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Profile info header
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Newsreader',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Resident Researcher • Bio-Medical Science',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 36),

                // Profile Details Metadata
                _buildInfoTile(Icons.badge_outlined, 'Student ID', studentId),
                const Divider(color: Color(0xFFF1F5F9)),
                _buildInfoTile(Icons.alternate_email, 'Email Address', email),
                const Divider(color: Color(0xFFF1F5F9)),
                _buildInfoTile(
                  Icons.star_outline,
                  'Reputation Trust Score',
                  reputation,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ReputationScoreScreen()),
                    );
                  },
                ),
                const Divider(color: Color(0xFFF1F5F9)),
                _buildInfoTile(
                  Icons.account_balance_wallet_outlined,
                  'Linked Node Wallet',
                  '0x71C...3a9f',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const WalletBalanceScreen()),
                    );
                  },
                ),
                const SizedBox(height: 48),

                // Logout action button
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF2F2),
                    foregroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFFEE2E2)),
                    ),
                  ),
                  child: const Text(
                    'Log Out Workstation',
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
        },
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF94A3B8), size: 20),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
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
