import 'package:flutter/material.dart';
import 'package:frontend/module2/inspection/damage_severity_report.dart';

class ChangeDetectionView extends StatefulWidget {
  const ChangeDetectionView({super.key});

  @override
  State<ChangeDetectionView> createState() => _ChangeDetectionViewState();
}

class _ChangeDetectionViewState extends State<ChangeDetectionView> {
  bool _showOverlay = true;

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
          'DIAGNOSTIC COMPARATIVE',
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
            // Structural Details Header
            const Text(
              'Surface Change Analysis',
              style: TextStyle(
                fontFamily: 'Newsreader',
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Comparative scan tracking structural anomalies in returning equipment.',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 28),

            // Main Comparison Cards
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'ARCHIVED PRISTINE',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          image: const DecorationImage(
                            image: NetworkImage(
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuCXbm1CaktJoWupZc3uzV_7hjy6A6rLivBhlusHwMAx-3O1uzhYYoe-k0g7HYYjHGNSj8z6f76glSFmX0lq7ijioTg47EuyDYTPNsDFf33wfil94Qyia6K73wU9szaqmZzUebK1ow7fmlAlwVOAyF6_T6JPNr0j02wOs7EUhVbyGmOo1JJ8qkqe6tCxQ5ROihQR19e5D2eozzqnrKHgBpSKj7BgRpQ4ZiILxWFFDXyNWkuXOWGYaeBg',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'CURRENT SCAN',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        children: [
                          Container(
                            height: 180,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              image: const DecorationImage(
                                image: NetworkImage(
                                  'https://lh3.googleusercontent.com/aida-public/AB6AXuCXbm1CaktJoWupZc3uzV_7hjy6A6rLivBhlusHwMAx-3O1uzhYYoe-k0g7HYYjHGNSj8z6f76glSFmX0lq7ijioTg47EuyDYTPNsDFf33wfil94Qyia6K73wU9szaqmZzUebK1ow7fmlAlwVOAyF6_T6JPNr0j02wOs7EUhVbyGmOo1JJ8qkqe6tCxQ5ROihQR19e5D2eozzqnrKHgBpSKj7BgRpQ4ZiILxWFFDXyNWkuXOWGYaeBg',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          if (_showOverlay)
                            Positioned(
                              top: 50,
                              left: 60,
                              child: Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFEF4444), width: 2),
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Options / Toggles
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Highlight Fracture Zones',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Switch(
                  value: _showOverlay,
                  activeColor: const Color(0xFF8083FF),
                  onChanged: (value) {
                    setState(() {
                      _showOverlay = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Diagnostic Results summary card
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DamageSeverityReport()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'AI INSIGHT REPORT',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Similarity Index',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '94.2%',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B1326),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Discovered Anomalies',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '1 Anomaly (fracture)',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
