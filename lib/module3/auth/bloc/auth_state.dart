abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final Map<String, dynamic> user;
  final String token;

  AuthAuthenticated({required this.user, required this.token});
}

class AuthError extends AuthState {
  final String message;

  AuthError({required this.message});
}
