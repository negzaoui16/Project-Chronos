import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/constants/api_endpoints.dart';
import 'package:dio/dio.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ApiClient _apiClient = ApiClient();
  final List<Map<String, dynamic>> _messagesList = [];

  ChatBloc() : super(ChatInitial()) {
    on<LoadChatHistoryEvent>((event, emit) async {
      emit(ChatLoading());
      _messagesList.clear();
      try {
        final response = await _apiClient.dio.get(
          '${ApiEndpoints.chatHistory}/${event.sessionId}',
        );

        final List<dynamic> data = response.data;
        for (var msg in data) {
          _messagesList.add({
            'id': msg['id'],
            'text': msg['text'],
            'isUser': msg['isUser'],
            'imageUrl': msg['imageUrl'],
            'createdAt': msg['createdAt'],
          });
        }
        emit(ChatHistoryLoaded(List.from(_messagesList)));
      } catch (e) {
        String errorMsg = 'Failed to load chat history.';
        if (e is DioException && e.response != null) {
          errorMsg = e.response?.data['message'] ?? errorMsg;
        }
        emit(ChatError(errorMsg, List.from(_messagesList)));
      }
    });

    on<SendMessageEvent>((event, emit) async {
      // Optimistically add user's message to UI list
      final userMessage = {
        'text': event.message,
        'isUser': true,
        'localImagePath': event.imagePath,
        'imageUrl': null,
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      _messagesList.add(userMessage);
      emit(MessageSendingState(List.from(_messagesList)));

      try {
        MultipartFile? imageFile;
        if (event.imagePath != null) {
          imageFile = await MultipartFile.fromFile(
            event.imagePath!,
            filename: 'chat_upload.jpg',
          );
        }

        final formData = FormData.fromMap({
          'sessionId': event.sessionId,
          'message': event.message,
          if (event.bookingId != null) 'bookingId': event.bookingId,
          if (imageFile != null) 'image': imageFile,
        });

        final response = await _apiClient.dio.post(
          ApiEndpoints.sendMessage,
          data: formData,
        );

        final data = response.data;

        // If backend returned an imageUrl, update user's message
        if (data['imageUrl'] != null) {
          userMessage['imageUrl'] = data['imageUrl'];
        }

        // Add AI response message
        _messagesList.add({
          'text': data['answer'],
          'isUser': false,
          'imageUrl': null, // Response doesn't upload response images, but could refer to diagrams
          'contextUsed': data['contextUsed'],
          'similarityScore': data['similarityScore'],
          'imageDescription': data['imageDescription'],
          'createdAt': DateTime.now().toIso8601String(),
        });

        emit(MessageSentState(List.from(_messagesList)));
      } catch (e) {
        String errorMsg = 'Failed to send message.';
        if (e is DioException && e.response != null) {
          errorMsg = e.response?.data['message'] ?? errorMsg;
        }
        emit(ChatError(errorMsg, List.from(_messagesList)));
      }
    });

    on<ResetChatEvent>((event, emit) {
      _messagesList.clear();
      emit(ChatInitial());
    });
  }
}
