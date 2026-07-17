import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/module3/auth/bloc/auth_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_state.dart';

class ChatHistoryScreen extends StatefulWidget {
  final String? userId;
  const ChatHistoryScreen({super.key, this.userId});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final _apiClient = ApiClient();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _resolvedUserId = '';

  @override
  void initState() {
    super.initState();
    _resolveUserIdAndFetch();
  }

  void _resolveUserIdAndFetch() {
    _resolvedUserId = widget.userId ?? '';
    if (_resolvedUserId.isEmpty) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        _resolvedUserId = authState.user['id'] ?? '';
      }
    }
    _fetchChatSessions();
  }

  Future<void> _fetchChatSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiClient.dio.get('/chat/sessions/$_resolvedUserId');
      final List<dynamic> list = response.data;
      setState(() {
        _history = list.map((item) => item as Map<String, dynamic>).toList();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load chat history ledger.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteChatSession(String sessionId) async {
    try {
      final response = await _apiClient.dio.delete('/chat/session/$sessionId');
      if (response.statusCode == 200 || response.statusCode == 204) {
        _fetchChatSessions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conversation supprimée avec succès', style: TextStyle(fontFamily: 'Geist')),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de supprimer la conversation.', style: TextStyle(fontFamily: 'Geist')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<bool?> _showConfirmDeleteDialog(String title) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Supprimer la conversation',
            style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          content: Text(
            'Êtes-vous sûr de vouloir supprimer la conversation "$title" ? Cette action est irréversible.',
            style: const TextStyle(fontFamily: 'Geist', color: Color(0xFF64748B)),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler', style: TextStyle(fontFamily: 'Geist', color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Supprimer', style: TextStyle(fontFamily: 'Geist', color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'RESOLVED':
        return const Color(0xFF22C55E);
      case 'ACTIVE':
        return const Color(0xFF8083FF);
      case 'GENERAL':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF94A3B8);
    }
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
          'CHAT LEDGER',
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
                color: Color(0xFF8083FF),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, style: const TextStyle(fontFamily: 'Geist', color: Color(0xFF64748B))),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _fetchChatSessions,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8083FF)),
                          child: const Text('Try Again', style: TextStyle(color: Colors.white, fontFamily: 'Geist')),
                        )
                      ],
                    ),
                  ),
                )
              : _history.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 48, color: const Color(0xFF94A3B8).withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            const Text(
                              'No chat history yet',
                              style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Start troubleshooting sessions in the assessor and they will be listed here.',
                              style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(24.0),
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final session = _history[index];
                        final statusText = session['status'] ?? 'Active';
                        final sessionId = session['id'] as String;

                        return Dismissible(
                          key: Key(sessionId),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            final confirm = await _showConfirmDeleteDialog(session['title']);
                            return confirm ?? false;
                          },
                          onDismissed: (direction) {
                            _deleteChatSession(sessionId);
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24.0),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context, sessionId);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(18),
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        sessionId.substring(0, 8).toUpperCase(),
                                        style: const TextStyle(
                                          fontFamily: 'Geist',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(statusText).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: TextStyle(
                                            fontFamily: 'Geist',
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: _getStatusColor(statusText),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    session['title'],
                                    style: const TextStyle(
                                      fontFamily: 'Geist',
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    session['lastMessage'],
                                    style: const TextStyle(
                                      fontFamily: 'Geist',
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        session['date'],
                                        style: const TextStyle(
                                          fontFamily: 'Geist',
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward,
                                        color: Color(0xFF8083FF),
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
