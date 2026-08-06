import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/module3/auth/bloc/auth_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_state.dart';

class WalletBalanceScreen extends StatefulWidget {
  const WalletBalanceScreen({super.key});

  @override
  State<WalletBalanceScreen> createState() => _WalletBalanceScreenState();
}

class _WalletBalanceScreenState extends State<WalletBalanceScreen> {
  final _apiClient = ApiClient();

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _walletData;
  List<dynamic> _transactions = [];
  Timer? _refreshTimer;


  @override
  void initState() {
    super.initState();
    _fetchWalletDetails();
  }

  @override
  void dispose() {
    _stopRefreshTimer();
    super.dispose();
  }

  void _startRefreshTimer() {
    if (_refreshTimer != null) return;
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      _fetchWalletDetails(silent: true);
    });
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _fetchWalletDetails({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        final response = await _apiClient.dio.get(
          '/wallet/me',
          options: Options(headers: {'Authorization': 'Bearer ${authState.token}'}),
        );
        
        final txResponse = await _apiClient.dio.get(
          '/wallet/me/transactions?limit=50',
          options: Options(headers: {'Authorization': 'Bearer ${authState.token}'}),
        );

        if (mounted) {
          setState(() {
            _walletData = response.data;
            _transactions = txResponse.data['items'] ?? [];
            _isLoading = false;
            _errorMessage = null;
          });

          final status = _walletData?['tokenMintStatus'] ?? '';
          if (status == 'PENDING' || status == 'SUBMITTED') {
            _startRefreshTimer();
          } else {
            _stopRefreshTimer();
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Authentication required';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is DioException && e.response?.data?['message'] != null
              ? e.response!.data['message']
              : 'Failed to load wallet';
          _isLoading = false;
        });
      }
    }
  }



  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      // Direct call is much more robust against modern Android package visibility issues
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $e')),
        );
      }
    }
  }



  String _shortenAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'CONFIRMED':
        return 'Confirmed';
      case 'PENDING':
        return 'Preparing token allocation';
      case 'SUBMITTED':
        return 'Waiting for Polygon confirmation';
      case 'FAILED':
        return 'Token allocation failed; contact support';
      case 'NOT_REQUIRED':
        return 'No student token allocation is expected';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'CONFIRMED':
        return const Color(0xFF22C55E); // Green
      case 'PENDING':
        return const Color(0xFFEAB308); // Yellow
      case 'SUBMITTED':
        return const Color(0xFF3B82F6); // Blue
      case 'FAILED':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF64748B); // Slate
    }
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
          'CHRONOS WALLET',
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8083FF)),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => _fetchWalletDetails(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8083FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF8083FF),
                  backgroundColor: const Color(0xFF0B1326),
                  strokeWidth: 2.5,
                  onRefresh: () async {
                    await _fetchWalletDetails(silent: true);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Balance Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8083FF), Color(0xFF494BD6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8083FF).withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _walletData?['tokenName']?.toString().toUpperCase() ?? 'CHR ACCOUNT BALANCE',
                              style: const TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE1E0FF),
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${_walletData?['chronosBalance'] ?? '0.00'} ${_walletData?['tokenSymbol'] ?? 'CHR'}',
                              style: const TextStyle(
                                fontFamily: 'Newsreader',
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_shortenAddress(_walletData?['walletAddress'] ?? '0x0000000000000000000000000000000000000000')} • On-Chain Campus Node',
                              style: const TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 12,
                                color: Color(0xFFC0C1FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Status and Explorer Links Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        color: const Color(0xFFF8FAFC),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Allocation Status: ',
                                    style: TextStyle(
                                      fontFamily: 'Geist',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(_walletData?['tokenMintStatus'] ?? '').withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _getStatusLabel(_walletData?['tokenMintStatus'] ?? ''),
                                      style: TextStyle(
                                        fontFamily: 'Geist',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(_walletData?['tokenMintStatus'] ?? ''),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: () {
                                  final url = _walletData?['walletExplorerUrl'];
                                  if (url != null) {
                                    _launchURL(url);
                                  }
                                },
                                child: const Row(
                                  children: [
                                    Icon(Icons.open_in_new, size: 16, color: Color(0xFF8083FF)),
                                    SizedBox(width: 8),
                                    Text(
                                      'View wallet on Polygonscan',
                                      style: TextStyle(
                                        fontFamily: 'Geist',
                                        fontSize: 12,
                                        color: Color(0xFF8083FF),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_walletData?['transactionExplorerUrl'] != null) ...[
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () {
                                    final url = _walletData?['transactionExplorerUrl'];
                                    if (url != null) {
                                      _launchURL(url);
                                    }
                                  },
                                  child: const Row(
                                    children: [
                                      Icon(Icons.receipt_long, size: 16, color: Color(0xFF8083FF)),
                                      SizedBox(width: 8),
                                      Text(
                                        'View mint transaction details',
                                        style: TextStyle(
                                          fontFamily: 'Geist',
                                          fontSize: 12,
                                          color: Color(0xFF8083FF),
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // History Header
                      const Text(
                        'Activity Ledger',
                        style: TextStyle(
                          fontFamily: 'Newsreader',
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // History List
                      // History List
                      _transactions.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text(
                                  'No recent activity on-chain',
                                  style: TextStyle(fontFamily: 'Geist', color: Color(0xFF64748B)),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _transactions.length,
                              separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, index) {
                                final tx = _transactions[index];
                                final hasTxHash = tx['transactionHash'] != null;
                                
                                final type = tx['type']?.toString() ?? 'UNKNOWN';
                                bool isPositive = type == 'TOKEN_MINT' || type == 'ESCROW_RELEASE';
                                
                                String title = type.replaceAll('_', ' ');
                                if (type == 'TOKEN_MINT') title = 'Token Allocation';
                                if (type == 'ESCROW_LOCK') title = 'Escrow Locked';
                                if (type == 'ESCROW_RELEASE') title = 'Escrow Released';
                                if (type == 'ESCROW_SLASH') title = 'Penalty Slashed';

                                String date = 'Recently';
                                if (tx['timestamp'] != null) {
                                  final dt = DateTime.fromMillisecondsSinceEpoch(tx['timestamp'] * 1000);
                                  date = '${dt.day}/${dt.month}/${dt.year}';
                                }
                                
                                final symbol = _walletData?['tokenSymbol'] ?? 'CHR';
                                final amountStr = '${isPositive ? '+' : '-'}${tx['amount'] ?? '0.0'} $symbol';

                                return InkWell(
                                  onTap: hasTxHash
                                      ? () {
                                          final url = tx['explorerUrl'];
                                          if (url != null) _launchURL(url);
                                        }
                                      : null,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: isPositive
                                                    ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                                                    : const Color(0xFFEF4444).withValues(alpha: 0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isPositive ? Icons.call_received : Icons.call_made,
                                                color: isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      title,
                                                      style: const TextStyle(
                                                        fontFamily: 'Geist',
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                    if (hasTxHash) ...[
                                                      const SizedBox(width: 6),
                                                      const Icon(Icons.link, size: 14, color: Color(0xFF8083FF)),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${type.replaceAll('_', ' ')} • $date',
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
                                          amountStr,
                                          style: TextStyle(
                                            fontFamily: 'Geist',
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
    );
  }
}
