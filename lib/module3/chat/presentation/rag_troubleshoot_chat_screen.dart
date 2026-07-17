import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:frontend/module3/chat/bloc/chat_bloc.dart';
import 'package:frontend/module3/chat/bloc/chat_event.dart';
import 'package:frontend/module3/chat/bloc/chat_state.dart';
import 'package:frontend/module3/auth/bloc/auth_bloc.dart';
import 'package:frontend/module3/auth/bloc/auth_state.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/module3/chat/presentation/chat_history_screen.dart';

class RagTroubleshootChatScreen extends StatefulWidget {
  const RagTroubleshootChatScreen({super.key});

  @override
  State<RagTroubleshootChatScreen> createState() => _RagTroubleshootChatScreenState();
}

class _RagTroubleshootChatScreenState extends State<RagTroubleshootChatScreen>
    with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _apiClient = ApiClient();
  final _picker = ImagePicker();

  String? _selectedImagePath;
  String _currentSessionId = '';
  String? _selectedBookingId;
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoadingBookings = false;
  String _userId = '';
  String _token = '';

  // Colors
  static const _violet = Color(0xFF8083FF);
  static const _darkBg = Color(0xFF0B1326);
  static const _aiBubbleBg = Color(0xFFF3F4FF);
  static const _aiBubbleBorder = Color(0xFFDDD9FF);
  static const _textDark = Color(0xFF1E1B4B);
  static const _textMuted = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _resolveAuthAndInitialize();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _resolveAuthAndInitialize() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _userId = authState.user['id'] ?? '';
      _token = authState.token;
      _currentSessionId = '${_userId}_general';
      _fetchUserBookings();
      context.read<ChatBloc>().add(LoadChatHistoryEvent(_currentSessionId));
    } else {
      _currentSessionId = 'general_fallback';
      context.read<ChatBloc>().add(LoadChatHistoryEvent(_currentSessionId));
    }
  }

  Future<void> _fetchUserBookings() async {
    setState(() => _isLoadingBookings = true);
    try {
      final response = await _apiClient.dio.get(
        '/bookings/my',
        options: Options(headers: {'Authorization': 'Bearer $_token'}),
      );
      final List<dynamic> list = response.data;
      setState(() {
        _bookings = list.map((b) => b as Map<String, dynamic>).toList();
      });
    } catch (e) {
      // Fail silently
    } finally {
      setState(() => _isLoadingBookings = false);
    }
  }

  void _onSendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImagePath == null) return;

    context.read<ChatBloc>().add(
          SendMessageEvent(
            sessionId: _currentSessionId,
            message: text.isEmpty ? 'Image uploaded for analysis' : text,
            imagePath: _selectedImagePath,
            bookingId: _selectedBookingId,
          ),
        );

    setState(() {
      _messageController.clear();
      _selectedImagePath = null;
    });

    _scrollToBottom();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (image != null) {
        setState(() => _selectedImagePath = image.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select image: $e')),
      );
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Attach Image',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _violet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: _violet, size: 22),
                ),
                title: const Text('Take a Photo',
                    style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _violet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: _violet, size: 22),
                ),
                title: const Text('Choose from Gallery',
                    style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// Renders AI text with numbered steps highlighted beautifully
  Widget _buildFormattedText(String text, bool isUser) {
    final lines = text.split('\n');
    List<Widget> children = [];

    for (var line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) {
        children.add(const SizedBox(height: 4));
        continue;
      }

      // Detect numbered step: "1. " "2. " etc.
      final stepMatch = RegExp(r'^(\d+)\.\s+(.+)$').firstMatch(trimmedLine);
      if (!isUser && stepMatch != null) {
        final num = stepMatch.group(1)!;
        final content = stepMatch.group(2)!;
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1, right: 10),
                  decoration: const BoxDecoration(
                    color: _violet,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      num,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Geist',
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    content,
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 14,
                      color: _textDark,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Bullet point
      bool isBullet = trimmedLine.startsWith('-') || trimmedLine.startsWith('•');
      String cleanLine = isBullet ? trimmedLine.substring(1).trim() : trimmedLine;

      // Bold parsing **text**
      List<TextSpan> spans = [];
      final parts = cleanLine.split('**');
      for (int i = 0; i < parts.length; i++) {
        final isBold = i % 2 == 1;
        spans.add(TextSpan(
          text: parts[i],
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            color: isUser ? Colors.white : _textDark,
            fontFamily: 'Geist',
            fontSize: 14,
            height: 1.5,
          ),
        ));
      }

      Widget textWidget = RichText(text: TextSpan(children: spans));

      if (isBullet) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.white70 : _violet,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(child: textWidget),
              ],
            ),
          ),
        );
      } else {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: textWidget,
        ));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _buildSourceBadge(String contextUsed) {
    final isLocal = contextUsed == 'local';
    final isGreeting = contextUsed == 'greeting' || contextUsed == 'conversation';

    Color badgeColor;
    Color textColor;
    IconData icon;
    String label;

    if (isGreeting) {
      badgeColor = const Color(0xFFECFDF5);
      textColor = const Color(0xFF059669);
      icon = Icons.auto_awesome_rounded;
      label = 'AI Assistant';
    } else if (isLocal) {
      badgeColor = const Color(0xFFEDE9FE);
      textColor = const Color(0xFF7C3AED);
      icon = Icons.library_books_rounded;
      label = 'Knowledge Base';
    } else {
      badgeColor = const Color(0xFFEFF6FF);
      textColor = const Color(0xFF2563EB);
      icon = Icons.travel_explore_rounded;
      label = 'Web Search';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: textColor,
              fontWeight: FontWeight.w600,
              fontFamily: 'Geist',
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isUser = msg['isUser'] == true;
    final text = msg['text'] ?? '';
    final imageUrl = msg['imageUrl'];
    final localImagePath = msg['localImagePath'];
    final contextUsed = msg['contextUsed'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI Avatar
          if (!isUser) ...[
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8083FF), Color(0xFF5B5FFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _violet.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
          ],
          // Bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFF8083FF), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : _aiBubbleBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: isUser
                    ? null
                    : Border.all(color: _aiBubbleBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? _violet.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image preview
                  if (localImagePath != null || imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          SizedBox(
                            height: 200,
                            width: double.infinity,
                            child: localImagePath != null
                                ? Image.file(File(localImagePath), fit: BoxFit.cover)
                                : Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        height: 200,
                                        color: const Color(0xFFE0E7FF),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: _violet,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          // Image label overlay
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, Colors.black54],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              child: const Text(
                                'Image uploaded for analysis',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontFamily: 'Geist',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Text content
                  _buildFormattedText(text, isUser),
                  // Source badge (AI only)
                  if (!isUser && contextUsed != null) ...[
                    const SizedBox(height: 10),
                    _buildSourceBadge(contextUsed),
                  ],
                ],
              ),
            ),
          ),
          // User Avatar
          if (isUser) ...[
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(left: 8, bottom: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B4B),
                shape: BoxShape.circle,
                border: Border.all(color: _violet, width: 1.5),
              ),
              child: const Icon(Icons.person, color: Colors.white70, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(right: 8, bottom: 2),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8083FF), Color(0xFF5B5FFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _aiBubbleBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: _aiBubbleBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(150),
                const SizedBox(width: 4),
                _buildDot(300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, val, child) => Opacity(
        opacity: val,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: _violet,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8083FF), Color(0xFF5B5FFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _violet.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 24),
            const Text(
              'AI Troubleshooting Assistant',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ask me anything about your academic equipment.\nI can help with setup, errors, and diagnostics.',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 13,
                color: _textMuted,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Suggestion chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestion('🔌 Quest 3 setup'),
                _buildSuggestion('🖨️ Printer error'),
                _buildSuggestion('💻 BSOD fix'),
                _buildSuggestion('📡 Network issue'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestion(String label) {
    return GestureDetector(
      onTap: () {
        _messageController.text = label.replaceAll(RegExp(r'[^\w\s]'), '').trim();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _violet.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _violet.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 12,
            color: _violet,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFC0C1FF), size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8083FF), Color(0xFF5B5FFF)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI ASSESSOR',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDAE2FD),
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'Chronos Troubleshooting Assistant',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 10,
                    color: Color(0xFF6B7FBD),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // New conversation button
          IconButton(
            tooltip: 'New Conversation',
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _violet.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_rounded, color: Color(0xFFDAE2FD), size: 20),
            ),
            onPressed: () {
              final newSessionId = '${_userId}_${DateTime.now().millisecondsSinceEpoch}';
              setState(() {
                _currentSessionId = newSessionId;
                _selectedBookingId = null;
              });
              context.read<ChatBloc>().add(LoadChatHistoryEvent(newSessionId));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Text('New conversation started',
                          style: TextStyle(fontFamily: 'Geist', fontWeight: FontWeight.w500)),
                    ],
                  ),
                  backgroundColor: _violet,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
          ),
          // History button
          IconButton(
            tooltip: 'Chat History',
            icon: const Icon(Icons.history_rounded, color: Color(0xFFC0C1FF), size: 22),
            onPressed: () async {
              final chatBloc = context.read<ChatBloc>();
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ChatHistoryScreen(userId: _userId)),
              );
              if (!mounted) return;
              if (result != null && result is String) {
                setState(() {
                  _currentSessionId = result;
                  _selectedBookingId = _bookings.any((b) => b['id'] == result) ? result : null;
                });
                chatBloc.add(LoadChatHistoryEvent(_currentSessionId));
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF1A2540)),
        ),
      ),
      body: Column(
        children: [
          // Session selector bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade100),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _violet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.devices_rounded, size: 16, color: _violet),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _isLoadingBookings
                      ? const Text('Loading assets...',
                          style: TextStyle(
                              fontFamily: 'Geist', fontSize: 13, color: _textMuted))
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedBookingId ?? 'general',
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                color: _violet, size: 20),
                            style: const TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 13,
                              color: _textDark,
                              fontWeight: FontWeight.w500,
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: 'general',
                                child: Text(
                                    'General Troubleshooting (${_userId.length > 5 ? _userId.substring(0, 5) : _userId}...)'),
                              ),
                              ..._bookings.map((booking) {
                                final assetName = booking['asset']?['name'] ?? 'Equipment';
                                final status = booking['status'] ?? 'Active';
                                return DropdownMenuItem<String>(
                                  value: booking['id'],
                                  child: Text('$assetName · $status'),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() {
                                if (val == 'general') {
                                  _selectedBookingId = null;
                                  _currentSessionId = '${_userId}_general';
                                } else {
                                  _selectedBookingId = val;
                                  _currentSessionId = val;
                                }
                              });
                              context
                                  .read<ChatBloc>()
                                  .add(LoadChatHistoryEvent(_currentSessionId));
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),

          // Messages area
          Expanded(
            child: BlocConsumer<ChatBloc, ChatState>(
              listener: (context, state) {
                if (state is MessageSentState ||
                    state is MessageSendingState ||
                    state is ChatHistoryLoaded) {
                  _scrollToBottom();
                }
                if (state is ChatError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.error),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is ChatLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: _violet, strokeWidth: 2),
                  );
                }

                List<Map<String, dynamic>> msgs = [];
                bool isSending = false;
                if (state is ChatHistoryLoaded) msgs = state.messages;
                if (state is MessageSendingState) {
                  msgs = state.messages;
                  isSending = true;
                }
                if (state is MessageSentState) msgs = state.messages;
                if (state is ChatError) msgs = state.messages;

                if (msgs.isEmpty && !isSending) return _buildEmptyState();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                  itemCount: msgs.length + (isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (isSending && index == msgs.length) {
                      return _buildTypingIndicator();
                    }
                    return _buildMessageBubble(msgs[index]);
                  },
                );
              },
            ),
          ),

          // Attached image preview
          if (_selectedImagePath != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              decoration: BoxDecoration(
                color: _violet.withValues(alpha: 0.04),
                border: Border(
                  top: BorderSide(color: _violet.withValues(alpha: 0.15)),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_selectedImagePath!),
                      height: 52,
                      width: 52,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Image attached',
                            style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _textDark)),
                        Text('Will be sent with your message',
                            style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 11,
                                color: _textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 22),
                    onPressed: () => setState(() => _selectedImagePath = null),
                  ),
                ],
              ),
            ),

          // Input bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attach button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _showImagePickerOptions,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _violet.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate_rounded,
                          color: _violet,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Text field
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE0E7FF), width: 1.5),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(
                            fontFamily: 'Geist', fontSize: 14, color: _textDark),
                        maxLines: null,
                        onSubmitted: (_) => _onSendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Ask about any equipment issue...',
                          hintStyle: TextStyle(
                              color: Color(0xFFADB5D0),
                              fontFamily: 'Geist',
                              fontSize: 14),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Send button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _onSendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8083FF), Color(0xFF6366F1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _violet.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
