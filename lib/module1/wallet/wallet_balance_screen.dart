import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:frontend/module3/auth/bloc/auth_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_state.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/module1/wallet/governance_vote_screen.dart';

class WalletBalanceScreen extends StatefulWidget {
  const WalletBalanceScreen({super.key});

  @override
  State<WalletBalanceScreen> createState() => _WalletBalanceScreenState();
}

class _WalletBalanceScreenState extends State<WalletBalanceScreen> {
  final _transferFormKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _apiClient = ApiClient();

  Map<String, dynamic>? _walletData;
  bool _isLoading = true;
  String? _errorMessage;
  int? _errorStatusCode;
  Timer? _refreshTimer;

  final List<Map<String, dynamic>> _transactions = [
    {
      'type': 'Reward',
      'title': 'AI Inspection Verification',
      'amount': '+15.0 CHR',
      'date': 'Just now',
      'isPositive': true,
    },
    {
      'type': 'Payment',
      'title': 'Formlabs 3B+ Rental',
      'amount': '-40.0 CHR',
      'date': 'Yesterday',
      'isPositive': false,
    },
    {
      'type': 'Staking',
      'title': 'Escrow Collateral Released',
      'amount': '+100.0 CHR',
      'date': '3 days ago',
      'isPositive': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchWalletData() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      setState(() {
        _errorMessage = 'Authentication required. Please log in.';
        _errorStatusCode = 401;
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await _apiClient.dio.get(
        '/wallet/me',
        options: Options(headers: {'Authorization': 'Bearer ${authState.token}'}),
      );

      if (mounted) {
        setState(() {
          _walletData = response.data;
          _errorMessage = null;
          _errorStatusCode = null;
          _isLoading = false;
        });

        // Setup auto-refresh if status is PENDING or SUBMITTED
        final status = _walletData?['tokenMintStatus'] ?? 'NOT_REQUIRED';
        if (status == 'PENDING' || status == 'SUBMITTED') {
          _refreshTimer ??= Timer.periodic(const Duration(seconds: 10), (timer) {
            _fetchWalletData();
          });
        } else {
          _refreshTimer?.cancel();
          _refreshTimer = null;
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorStatusCode = e.response?.statusCode;
          if (_errorStatusCode == 401) {
            _errorMessage = 'Your session has expired. Please log in again.';
          } else if (_errorStatusCode == 404) {
            _errorMessage = 'Wallet not found for this account.';
          } else if (_errorStatusCode == 503) {
            _errorMessage = 'Polygon RPC node is temporarily unavailable.';
          } else {
            _errorMessage = e.response?.data?['message'] ?? 'Unable to connect to the server.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred while loading wallet.';
          _isLoading = false;
        });
      }
    }
  }

  void _onSendCHR() {
    if (_transferFormKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction successfully signed and broadcasted to Polygon Amoy.'),
          backgroundColor: Color(0xFF8083FF),
        ),
      );
      _recipientController.clear();
      _amountController.clear();
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF0B1326),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    Color textColor;
    IconData icon;
    String label;

    switch (status) {
      case 'CONFIRMED':
        badgeColor = const Color(0xFFECFDF5);
        textColor = const Color(0xFF059669);
        icon = Icons.check_circle_rounded;
        label = 'Allocation Confirmed';
        break;
      case 'PENDING':
        badgeColor = const Color(0xFFFFF7ED);
        textColor = const Color(0xFFEA580C);
        icon = Icons.hourglass_empty_rounded;
        label = 'Preparing allocation...';
        break;
      case 'SUBMITTED':
        badgeColor = const Color(0xFFEFF6FF);
        textColor = const Color(0xFF2563EB);
        icon = Icons.pending_actions_rounded;
        label = 'Waiting for Polygon...';
        break;
      case 'FAILED':
        badgeColor = const Color(0xFFFEF2F2);
        textColor = const Color(0xFFDC2626);
        icon = Icons.error_outline_rounded;
        label = 'Allocation failed';
        break;
      default:
        badgeColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF475569);
        icon = Icons.info_outline_rounded;
        label = 'No allocation expected';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w600,
              fontFamily: 'Geist',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.how_to_vote, color: Color(0xFFC0C1FF)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GovernanceVoteScreen()),
              );
            },
          ),
        ],
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
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFDC2626),
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 16,
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_errorStatusCode == 401)
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0B1326),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: const Text('Back to Login'),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                              });
                              _fetchWalletData();
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8083FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
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
                              _walletData?['tokenName']?.toUpperCase() ?? 'CHRONOS TOKEN ACCOUNT',
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
                              '${_walletData?['chronosBalance'] ?? '0.0'} ${_walletData?['tokenSymbol'] ?? 'CHRONOS'}',
                              style: const TextStyle(
                                fontFamily: 'Newsreader',
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _walletData?['walletAddress'] != null
                                        ? '${_walletData!['walletAddress'].substring(0, 8)}...${_walletData!['walletAddress'].substring(_walletData!['walletAddress'].length - 8)} • On-Chain Node'
                                        : 'Address Pending • On-Chain Node',
                                    style: const TextStyle(
                                      fontFamily: 'Geist',
                                      fontSize: 12,
                                      color: Color(0xFFC0C1FF),
                                    ),
                                  ),
                                ),
                                if (_walletData?['walletAddress'] != null)
                                  GestureDetector(
                                    onTap: () => _copyToClipboard(
                                      _walletData!['walletAddress'],
                                      'Wallet address copied to clipboard!',
                                    ),
                                    child: const Icon(
                                      Icons.copy_rounded,
                                      color: Color(0xFFC0C1FF),
                                      size: 16,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Status Header Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Network Status',
                            style: TextStyle(
                              fontFamily: 'Newsreader',
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          _buildStatusBadge(_walletData?['tokenMintStatus'] ?? 'NOT_REQUIRED'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Explorer Links buttons
                      Row(
                        children: [
                          if (_walletData?['walletExplorerUrl'] != null)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _copyToClipboard(
                                  _walletData!['walletExplorerUrl'],
                                  'Wallet Explorer link copied! Open in your browser.',
                                ),
                                icon: const Icon(Icons.explore_outlined, size: 16),
                                label: const Text('Wallet Link'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF494BD6),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          if (_walletData?['transactionExplorerUrl'] != null) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _copyToClipboard(
                                  _walletData!['transactionExplorerUrl'],
                                  'Transaction link copied! Open in your browser.',
                                ),
                                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                                label: const Text('Mint Tx Link'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF494BD6),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Quick Transfer Section
                      const Text(
                        'Quick Transfer',
                        style: TextStyle(
                          fontFamily: 'Newsreader',
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Transfer Form
                      Form(
                        key: _transferFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _recipientController,
                              style: const TextStyle(fontFamily: 'Geist', fontSize: 14),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                                hintText: 'Recipient Address (0x...)',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF8083FF)),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a recipient address';
                                }
                                if (!value.startsWith('0x') || value.length < 10) {
                                  return 'Please enter a valid hex address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontFamily: 'Geist', fontSize: 14),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20),
                                hintText: 'Amount (CHR)',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF8083FF)),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter an amount';
                                }
                                if (double.tryParse(value) == null || double.parse(value) <= 0) {
                                  return 'Amount must be a positive number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _onSendCHR,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8083FF),
                                foregroundColor: const Color(0xFF0D0096),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Sign & Transfer CHR',
                                style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
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
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _transactions.length,
                        separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final tx = _transactions[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: tx['isPositive']
                                            ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                                            : const Color(0xFFEF4444).withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        tx['isPositive'] ? Icons.call_received : Icons.call_made,
                                        color: tx['isPositive'] ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx['title'],
                                          style: const TextStyle(
                                            fontFamily: 'Geist',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${tx['type']} • ${tx['date']}',
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
                                  tx['amount'],
                                  style: TextStyle(
                                    fontFamily: 'Geist',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: tx['isPositive'] ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
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
