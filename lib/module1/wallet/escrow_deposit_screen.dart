import 'package:flutter/material.dart';
import 'package:frontend/module1/wallet/wallet_balance_screen.dart';

class EscrowDepositScreen extends StatefulWidget {
  const EscrowDepositScreen({super.key});

  @override
  State<EscrowDepositScreen> createState() => _EscrowDepositScreenState();
}

class _EscrowDepositScreenState extends State<EscrowDepositScreen> {
  final List<Map<String, dynamic>> _escrowItems = [
    {
      'id': 'ESC-892',
      'title': 'Formlabs 3B+ Rental Deposit',
      'amount': '50.0 CHR',
      'status': 'Locked',
      'statusColor': Color(0xFFF59E0B), // orange-500
      'releaseCondition': 'Successful AI Damage Scan',
    },
    {
      'id': 'ESC-304',
      'title': 'VR Headset Reservation Deposit',
      'amount': '25.0 CHR',
      'status': 'Released',
      'statusColor': Color(0xFF22C55E), // green-500
      'releaseCondition': 'Returned on Time',
    },
    {
      'id': 'ESC-110',
      'title': 'Staked Node Guarantee',
      'amount': '150.0 CHR',
      'status': 'Staked',
      'statusColor': Color(0xFF8083FF), // primary-container
      'releaseCondition': 'Validator Node Uptime 99.9%',
    },
  ];

  void _onStakeTokens() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Guarantor staking proposal successfully submitted to network.'),
        backgroundColor: Color(0xFF8083FF),
      ),
    );
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
          'ESCROW & STAKING',
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
            // Top overview metric
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'TOTAL STAKED ASSETS',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                          letterSpacing: 1.0,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '225.00 CHR',
                        style: TextStyle(
                          fontFamily: 'Newsreader',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B1326),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _onStakeTokens,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8083FF),
                      foregroundColor: const Color(0xFF0D0096),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text(
                      'Stake Guarantee',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Staking logs list title
            const Text(
              'Locked Agreements',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),

            // Active list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _escrowItems.length,
              itemBuilder: (context, index) {
                final item = _escrowItems[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
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
                          Row(
                            children: [
                              Text(
                                item['id'],
                                style: const TextStyle(
                                  fontFamily: 'Geist',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item['statusColor'].withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item['status'],
                                  style: TextStyle(
                                    fontFamily: 'Geist',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: item['statusColor'],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            item['amount'],
                            style: const TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0B1326),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item['title'],
                        style: const TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFF94A3B8),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Release conditions: ${item['releaseCondition']}',
                              style: const TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
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
