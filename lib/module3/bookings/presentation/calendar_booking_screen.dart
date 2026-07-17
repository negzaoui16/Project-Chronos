import 'package:flutter/material.dart';
import 'package:frontend/module3/bookings/presentation/booking_confirmation_screen.dart';

class CalendarBookingScreen extends StatefulWidget {
  final String? assetId;
  const CalendarBookingScreen({super.key, this.assetId});

  @override
  State<CalendarBookingScreen> createState() => _CalendarBookingScreenState();
}

class _CalendarBookingScreenState extends State<CalendarBookingScreen> {
  int _selectedDayIndex = 0;
  int _selectedSlotIndex = -1;

  final List<String> _days = ['Mon 14', 'Tue 15', 'Wed 16', 'Thu 17', 'Fri 18'];
  final List<Map<String, dynamic>> _slots = [
    {'time': '09:00 - 10:00', 'isAvailable': true},
    {'time': '10:00 - 11:00', 'isAvailable': false},
    {'time': '11:00 - 12:00', 'isAvailable': true},
    {'time': '13:00 - 14:00', 'isAvailable': true},
    {'time': '14:00 - 15:00', 'isAvailable': false},
    {'time': '15:00 - 16:00', 'isAvailable': true},
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
          'BOOKING CALENDAR',
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
            // Month title
            const Text(
              'July 2026',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),

            // Horizontal date list
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _days.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedDayIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDayIndex = index;
                          _selectedSlotIndex = -1; // Reset slot on day change
                        });
                      },
                      child: Container(
                        width: 70,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFC0C1FF) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFC0C1FF) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _days[index].split(' ')[0],
                              style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? const Color(0xFF0D0096) : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _days[index].split(' ')[1],
                              style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFF0D0096) : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 36),

            // Time Slots Header
            const Text(
              'Select Time Slot',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),

            // Time Slots Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
              ),
              itemCount: _slots.length,
              itemBuilder: (context, index) {
                final slot = _slots[index];
                final isAvailable = slot['isAvailable'];
                final isSelected = _selectedSlotIndex == index;

                Color cardColor = const Color(0xFFF8FAFC);
                Color textColor = const Color(0xFF0F172A);
                Color borderColor = const Color(0xFFE2E8F0);

                if (!isAvailable) {
                  cardColor = const Color(0xFFF1F5F9);
                  textColor = const Color(0xFF94A3B8);
                } else if (isSelected) {
                  cardColor = const Color(0xFFC0C1FF);
                  textColor = const Color(0xFF0D0096);
                  borderColor = const Color(0xFFC0C1FF);
                }

                return GestureDetector(
                  onTap: isAvailable
                      ? () {
                          setState(() {
                            _selectedSlotIndex = index;
                          });
                        }
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Center(
                      child: Text(
                        slot['time'],
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 48),

            // Next button
            ElevatedButton(
              onPressed: _selectedSlotIndex != -1
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reservation scheduled. Waiting for collateral release confirmation.'),
                          backgroundColor: Color(0xFF8083FF),
                        ),
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const BookingConfirmationScreen()),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8083FF),
                foregroundColor: const Color(0xFF0D0096),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm Time Slot',
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
  }
}
