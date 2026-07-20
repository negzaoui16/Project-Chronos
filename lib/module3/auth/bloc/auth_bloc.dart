import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/constants/api_endpoints.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiClient _apiClient = ApiClient();

  AuthBloc() : super(AuthInitial()) {
    on<CheckAuthRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        final userStr = prefs.getString('auth_user');

        if (token != null && userStr != null) {
          final user = jsonDecode(userStr);
          emit(AuthAuthenticated(user: user, token: token));
        } else {
          emit(AuthInitial());
        }
      } catch (e) {
        emit(AuthInitial());
      }
    });

    on<LogoutRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        await prefs.remove('auth_user');
        emit(AuthInitial());
      } catch (e) {
        emit(AuthInitial());
      }
    });

    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final response = await _apiClient.dio.post(
          ApiEndpoints.login,
          data: {
            'email': event.email,
            'password': event.password,
          },
        );
        
        final data = response.data;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['token']);
        await prefs.setString('auth_user', jsonEncode(data['user']));

        emit(AuthAuthenticated(
          user: data['user'],
          token: data['token'],
        ));
      } catch (e) {
        String errorMsg = 'Failed to login. Please check connection.';
        if (e is DioException && e.response != null) {
          errorMsg = e.response?.data['message'] ?? errorMsg;
        }
        emit(AuthError(message: errorMsg));
      }
    });

    on<RegisterRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        MultipartFile? profileImageFile;
        if (event.imagePath != null) {
          profileImageFile = await MultipartFile.fromFile(
            event.imagePath!,
            filename: 'profile_image.jpg',
          );
        }

        final formData = FormData.fromMap({
          'name': event.name,
          'studentId': event.studentId,
          'email': event.email,
          'password': event.password,
          if (profileImageFile != null) 'profileImage': profileImageFile,
        });

        final response = await _apiClient.dio.post(
          ApiEndpoints.register,
          data: formData,
        );
        
        final data = response.data;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['token']);
        await prefs.setString('auth_user', jsonEncode(data['user']));

        emit(AuthAuthenticated(
          user: data['user'],
          token: data['token'],
        ));
      } catch (e) {
        String errorMsg = 'Failed to register. Please check connection.';
        if (e is DioException && e.response != null) {
          errorMsg = e.response?.data['message'] ?? errorMsg;
        }
        emit(AuthError(message: errorMsg));
      }
    });
  }
}
