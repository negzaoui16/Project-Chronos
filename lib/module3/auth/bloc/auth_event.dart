abstract class AuthEvent {}

class CheckAuthRequested extends AuthEvent {}

class LogoutRequested extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  LoginRequested({required this.email, required this.password});
}

class RegisterRequested extends AuthEvent {
  final String name;
  final String studentId;
  final String email;
  final String password;
  final String? imagePath;

  RegisterRequested({
    required this.name,
    required this.studentId,
    required this.email,
    required this.password,
    this.imagePath,
  });
}
