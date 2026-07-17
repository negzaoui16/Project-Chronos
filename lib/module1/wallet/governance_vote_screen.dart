import 'package:flutter/material.dart';

class GovernanceVoteScreen extends StatefulWidget {
  const GovernanceVoteScreen({super.key});

  @override
  State<GovernanceVoteScreen> createState() => _GovernanceVoteScreenState();
}

class _GovernanceVoteScreenState extends State<GovernanceVoteScreen> {
  final List<Map<String, dynamic>> _proposals = [
    {
      'id': 'PROP-402',
      'title': 'Deploy High-Performance Computing cluster node in Department Building B',
      'yesVotes': 1420,
      'noVotes': 380,
      'status': 'Voting Active',
      'ends': 'Ends in 3 days',
      'myVote': 'None',
    },
    {
      'id': 'PROP-399',
      'title': 'Acquire 3 additional Formlabs resin printers for open reservation',
      'yesVotes': 2100,
      'noVotes': 120,
      'status': 'Passed',
      'ends': 'Ended 2 days ago',
      'myVote': 'Yes',
    },
  ];

  void _castVote(int index, String voteType) {
    setState(() {
      _proposals[index]['myVote'] = voteType;
      if (voteType == 'Yes') {
        _proposals[index]['yesVotes'] += 10; // Simple weight simulator
      } else {
        _proposals[index]['noVotes'] += 10;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Casted "$voteType" vote on ${_proposals[index]['id']}. Transaction signed.'),
        backgroundColor: const Color(0xFF8083FF),
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
          'DECISION PROTOCOLS',
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
      body: ListView.builder(
        padding: const EdgeInsets.all(24.0),
        itemCount: _proposals.length,
        itemBuilder: (context, index) {
          final proposal = _proposals[index];
          final totalVotes = proposal['yesVotes'] + proposal['noVotes'];
          final yesPct = totalVotes > 0 ? (proposal['yesVotes'] / totalVotes) : 0.0;
          final isVoted = proposal['myVote'] != 'None';
          final isActive = proposal['status'] == 'Voting Active';

          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Proposal Meta Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      proposal['id'],
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF8083FF) : const Color(0xFF64748B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          proposal['status'],
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isActive ? const Color(0xFF8083FF) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Proposal Title
                Text(
                  proposal['title'],
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Voting Bar Chart
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Yes (${(yesPct * 100).toStringAsFixed(0)}%)',
                          style: const TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D0096),
                          ),
                        ),
                        Text(
                          'No (${((1 - yesPct) * 100).toStringAsFixed(0)}%)',
                          style: const TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: yesPct,
                            child: Container(
                              color: const Color(0xFF8083FF),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Footer interactions or status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      proposal['ends'],
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    if (isActive && !isVoted) ...[
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => _castVote(index, 'No'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              side: const BorderSide(color: Color(0xFFEF4444)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('No', style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _castVote(index, 'Yes'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8083FF),
                              foregroundColor: const Color(0xFF0D0096),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Yes', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        isVoted ? 'You voted: ${proposal['myVote']}' : 'Voting Period Closed',
                        style: const TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
