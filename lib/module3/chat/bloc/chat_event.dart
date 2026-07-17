abstract class ChatEvent {}

class LoadChatHistoryEvent extends ChatEvent {
  final String sessionId;
  LoadChatHistoryEvent(this.sessionId);
}

class SendMessageEvent extends ChatEvent {
  final String sessionId;
  final String message;
  final String? imagePath;
  final String? bookingId;

  SendMessageEvent({
    required this.sessionId,
    required this.message,
    this.imagePath,
    this.bookingId,
  });
}

class ResetChatEvent extends ChatEvent {}
