import 'package:flutter/material.dart';
import 'package:frontend/module3/bookings/presentation/calendar_booking_screen.dart';
import 'package:frontend/module3/marketplace/bloc/marketplace_state.dart';

class AssetDetailsScreen extends StatelessWidget {
  final MarketplaceAsset asset;

  const AssetDetailsScreen({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    final isAvailable = asset.status == 'LIVE';
    final statusLabel  = isAvailable ? 'Available' : 'Reserved';
    final statusColor  = isAvailable ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1326),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFC0C1FF)),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'EQUIPMENT SPECIFICATIONS',
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
      body: RefreshIndicator(
        color: const Color(0xFF8083FF),
        backgroundColor: const Color(0xFF0B1326),
        strokeWidth: 2.5,
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Banner image from Cloudinary ──────────────────────────────
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1326),
                  image: asset.imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(asset.imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: asset.imageUrl.isEmpty
                    ? const Center(
                        child: Icon(Icons.devices, size: 80, color: Color(0xFF8083FF)),
                      )
                    : null,
              ),

              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Title + status badge ───────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            asset.title,
                            style: const TextStyle(
                              fontFamily: 'Newsreader',
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0B1326),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Description ───────────────────────────────────────
                    Text(
                      asset.description.isNotEmpty
                          ? asset.description
                          : 'No description available for this equipment.',
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Technical Details ──────────────────────────────────
                    const Text(
                      'Technical Details',
                      style: TextStyle(
                        fontFamily: 'Newsreader',
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0B1326),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildDetailRow('Category', asset.category),
                    const Divider(color: Color(0xFFF1F5F9)),
                    _buildDetailRow('Availability', asset.availabilityText),
                    const Divider(color: Color(0xFFF1F5F9)),
                    _buildDetailRow('Asset ID', asset.id.substring(0, 8).toUpperCase()),
                    const SizedBox(height: 32),

                    // ── Reserve Button ─────────────────────────────────────
                    ElevatedButton(
                      onPressed: isAvailable
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CalendarBookingScreen(assetId: asset.id),
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8083FF),
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        foregroundColor: const Color(0xFF0D0096),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isAvailable ? 'Reserve Instrument' : 'Currently Unavailable',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isAvailable ? const Color(0xFF0D0096) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0B1326),
            ),
          ),
        ],
      ),
    );
  }
}
