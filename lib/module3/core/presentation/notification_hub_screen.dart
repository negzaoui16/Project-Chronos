import 'package:flutter/material.dart';

class NotificationHubScreen extends StatelessWidget {
  const NotificationHubScreen({super.key});

  final List<Map<String, dynamic>> _notifications = const [
    {
      'title': 'Collateral Released',
      'body': 'Your escrow staking lock of 40.0 CHR on Formlabs 3B+ has been returned.',
      'type': 'Staking',
      'icon': Icons.account_balance_wallet,
      'time': '2 hours ago',
      'isRead': false,
    },
    {
      'title': 'Lease Returning In 1 Hour',
      'body': 'Your booking window for VR Headset Kit in Robotics Hub expires shortly.',
      'type': 'Alert',
      'icon': Icons.hourglass_top,
      'time': '4 hours ago',
      'isRead': false,
    },
    {
      'title': 'Booking Secured',
      'body': 'Staking collateral verified. Your access QR token code is now active.',
      'type': 'System',
      'icon': Icons.check_circle,
      'time': 'Yesterday',
      'isRead': true,
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
          'NOTIFICATIONS',
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
      body: ListView.separated(
        padding: const EdgeInsets.all(24.0),
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9)),
        itemBuilder: (context, index) {
          final notif = _notifications[index];
          final isUnread = !notif['isRead'];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Unread dot indicator
                if (isUnread)
                  Container(
                    margin: const EdgeInsets.only(top: 14, right: 8),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8083FF),
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(width: 14),

                // Icon Type
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Icon(
                    notif['icon'],
                    color: const Color(0xFF8083FF),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),

                // Message Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif['title'],
                        style: const TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif['body'],
                        style: const TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notif['time'],
                        style: const TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
