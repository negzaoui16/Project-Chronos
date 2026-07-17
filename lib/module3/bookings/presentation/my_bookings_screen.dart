import 'package:flutter/material.dart';
import 'package:frontend/module3/bookings/presentation/asset_return_screen.dart';
import 'package:frontend/module3/bookings/presentation/dynamic_qr_key_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  int _activeTab = 0; // 0: Active, 1: Pending, 2: History

  final List<Map<String, dynamic>> _activeBookings = [
    {
      'id': 'BK-102',
      'title': 'Formlabs 3B+ Printer',
      'timeRemaining': '3 hours remaining',
      'location': 'Bio-Medical Lab A',
      'imageUrl': 'https://lh3.googleusercontent.com/aida-public/AB6AXuCXbm1CaktJoWupZc3uzV_7hjy6A6rLivBhlusHwMAx-3O1uzhYYoe-k0g7HYYjHGNSj8z6f76glSFmX0lq7ijioTg47EuyDYTPNsDFf33wfil94Qyia6K73wU9szaqmZzUebK1ow7fmlAlwVOAyF6_T6JPNr0j02wOs7EUhVbyGmOo1JJ8qkqe6tCxQ5ROihQR19e5D2eozzqnrKHgBpSKj7BgRpQ4ZiILxWFFDXyNWkuXOWGYaeBg',
    },
  ];

  final List<Map<String, dynamic>> _pendingBookings = [
    {
      'id': 'BK-205',
      'title': 'Meta Quest Pro Kit',
      'status': 'Staking Approval Pending',
      'escrowAmount': '25.0 CHR',
    },
  ];

  final List<Map<String, dynamic>> _pastBookings = [
    {
      'id': 'BK-098',
      'title': 'High-Perf Workstation',
      'date': 'July 10, 2026',
      'status': 'Returned & Verified',
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
          'MY RESERVATIONS',
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab selection buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Expanded(child: _buildTabButton('Active', 0)),
                const SizedBox(width: 8),
                Expanded(child: _buildTabButton('Pending', 1)),
                const SizedBox(width: 8),
                Expanded(child: _buildTabButton('History', 2)),
              ],
            ),
          ),

          // Tab content area
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF8083FF),
              backgroundColor: const Color(0xFF0B1326),
              strokeWidth: 2.5,
              onRefresh: () async {
                setState(() {}); // Trigger rebuild to reload booking data
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildTabContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFC0C1FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFFC0C1FF) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? const Color(0xFF0D0096) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case 0:
        return _buildActiveList();
      case 1:
        return _buildPendingList();
      case 2:
        return _buildPastList();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActiveList() {
    if (_activeBookings.isEmpty) return _buildEmptyState();

    return Column(
      children: _activeBookings.map((bk) {
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  bk['imageUrl'],
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bk['title'],
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${bk['location']} • ${bk['timeRemaining']}',
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 13,
                        color: Color(0xFF8083FF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AssetReturnScreen()),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF8083FF),
                              side: const BorderSide(color: Color(0xFF8083FF)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Initiate Return', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const DynamicQrKeyScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8083FF),
                              foregroundColor: const Color(0xFF0D0096),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Access QR Key', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPendingList() {
    if (_pendingBookings.isEmpty) return _buildEmptyState();

    return Column(
      children: _pendingBookings.map((bk) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    bk['id'],
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  Text(
                    bk['escrowAmount'],
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B1326),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                bk['title'],
                style: const TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.hourglass_empty, size: 14, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Text(
                    bk['status'],
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 12,
                      color: Color(0xFFF59E0B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPastList() {
    if (_pastBookings.isEmpty) return _buildEmptyState();

    return Column(
      children: _pastBookings.map((bk) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bk['title'],
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Returned on ${bk['date']}',
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Text(
                bk['status'],
                style: const TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF22C55E),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return const SizedBox(
      height: 250,
      child: Center(
        child: Text(
          'No reservations recorded under this index.',
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 14,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
