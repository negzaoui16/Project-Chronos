import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/module3/bookings/bloc/bookings_bloc.dart';
import 'package:frontend/module3/bookings/bloc/bookings_event.dart';
import 'package:frontend/module3/bookings/bloc/bookings_state.dart';
import 'package:frontend/module3/bookings/presentation/asset_return_screen.dart';
import 'package:frontend/module3/bookings/presentation/dynamic_qr_key_screen.dart';
import 'package:frontend/module3/auth/bloc/auth_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_state.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  int _activeTab = 0; // 0: Active, 1: Pending, 2: History
  late BookingsBloc _bookingsBloc;

  @override
  void initState() {
    super.initState();
    _bookingsBloc = BookingsBloc();
    _fetchData();
  }

  void _fetchData() {
    final authState = context.read<AuthBloc>().state;
    final token = authState is AuthAuthenticated ? authState.token : '';
    _bookingsBloc.add(FetchMyBookingsEvent(token));
  }

  @override
  void dispose() {
    _bookingsBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bookingsBloc,
      child: BlocConsumer<BookingsBloc, BookingsState>(
        listener: (context, state) {
          if (state is BookingCancelledSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.green),
            );
          } else if (state is BookingsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.white,
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
                      _fetchData();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildTabContent(state),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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

  Widget _buildTabContent(BookingsState state) {
    if (state is BookingsLoading || state is BookingsInitial) {
      return const Padding(
        padding: EdgeInsets.only(top: 50.0),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF8083FF))),
      );
    }

    if (state is BookingsLoaded) {
      switch (_activeTab) {
        case 0:
          return _buildActiveList(state.activeBookings);
        case 1:
          return _buildPendingList(state.pendingBookings);
        case 2:
          return _buildPastList(state.historyBookings);
        default:
          return const SizedBox.shrink();
      }
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildActiveList(List<dynamic> activeBookings) {
    if (activeBookings.isEmpty) return _buildEmptyState();

    return Column(
      children: activeBookings.map((bk) {
        final asset = bk['asset'] ?? {};
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
                  asset['imageUrl'] ?? 'https://via.placeholder.com/150',
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
                      asset['name'] ?? 'Unknown Item',
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${bk['id']}',
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
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => AssetReturnScreen(bookingId: bk['id'])),
                              );
                              if (!mounted) return;
                              await Future.delayed(const Duration(milliseconds: 200)); // Ensure backend has fully committed the change
                              _fetchData();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF8083FF),
                              side: const BorderSide(color: Color(0xFF8083FF)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Initiate Return', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                            child: const Text('QR Key', style: TextStyle(fontSize: 11)),
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

  Widget _buildPendingList(List<dynamic> pendingBookings) {
    if (pendingBookings.isEmpty) return _buildEmptyState();

    return Column(
      children: pendingBookings.map((bk) {
        final asset = bk['asset'] ?? {};
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
                    'ID: ${bk['id'].toString().substring(0, 8)}...',
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  Text(
                    'Pending',
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
                asset['name'] ?? 'Unknown Item',
                style: const TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hourglass_empty, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      Text(
                        bk['status'] ?? 'PENDING',
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
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPastList(List<dynamic> pastBookings) {
    if (pastBookings.isEmpty) return _buildEmptyState();

    return Column(
      children: pastBookings.map((bk) {
        final asset = bk['asset'] ?? {};
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset['name'] ?? 'Unknown Item',
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${bk['id'].toString().substring(0, 8)}...',
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                bk['status'] ?? 'COMPLETED',
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
          'No reservations recorded under this tab.',
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
