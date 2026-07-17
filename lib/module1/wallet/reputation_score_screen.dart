import 'package:flutter/material.dart';
import 'package:frontend/module1/wallet/wallet_balance_screen.dart';

class ReputationScoreScreen extends StatelessWidget {
  const ReputationScoreScreen({super.key});

  final List<Map<String, dynamic>> _scoreLogs = const [
    {
      'action': 'Punctual Equipment Return',
      'delta': '+4 pts',
      'date': 'Yesterday',
      'category': 'Reliability',
      'isPositive': true,
    },
    {
      'action': 'Accurate Damage Report',
      'delta': '+8 pts',
      'date': '4 days ago',
      'category': 'Integrity',
      'isPositive': true,
    },
    {
      'action': 'Minor Cleanliness Penalty',
      'delta': '-5 pts',
      'date': 'Last week',
      'category': 'Inspection',
      'isPositive': false,
    },
  ];

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
          'REPUTATION PROTOCOL',
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
            icon: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFC0C1FF)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WalletBalanceScreen()),
              );
            },
          ),
        ],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Circular Trust Rating indicator
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Text(
                    'ON-CHAIN TRUST LEVEL',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: 0.92,
                          strokeWidth: 10,
                          color: const Color(0xFF8083FF),
                          backgroundColor: const Color(0xFFE2E8F0),
                        ),
                      ),
                      Column(
                        children: const [
                          Text(
                            '92',
                            style: TextStyle(
                              fontFamily: 'Newsreader',
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0B1326),
                            ),
                          ),
                          Text(
                            'Level 4 Scholar',
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'High reputation grants priority reservations and reduces staking guarantee minimums.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Performance Logs Header
            const Text(
              'Audit Logs',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),

            // Logs list
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _scoreLogs.length,
              separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final log = _scoreLogs[index];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: log['isPositive'] ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log['action'],
                                style: const TextStyle(
                                  fontFamily: 'Geist',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${log['category']} • ${log['date']}',
                                style: const TextStyle(
                                  fontFamily: 'Geist',
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        log['delta'],
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: log['isPositive'] ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
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
    );
  }
}
