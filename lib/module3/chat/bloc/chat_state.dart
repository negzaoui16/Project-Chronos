abstract class ChatState {}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatHistoryLoaded extends ChatState {
  final List<Map<String, dynamic>> messages;
  ChatHistoryLoaded(this.messages);
}

class MessageSendingState extends ChatState {
  final List<Map<String, dynamic>> messages;
  MessageSendingState(this.messages);
}

class MessageSentState extends ChatState {
  final List<Map<String, dynamic>> messages;
  MessageSentState(this.messages);
}

class ChatError extends ChatState {
  final String error;
  final List<Map<String, dynamic>> messages;
  ChatError(this.error, this.messages);
}
