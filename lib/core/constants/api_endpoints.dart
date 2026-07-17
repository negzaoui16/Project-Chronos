class ApiEndpoints {
  // CONFIGURATION DU SERVEUR BACKEND (NestJS) :
  // - Pour Émulateur Android (PC local) : Utiliser 'http://10.0.2.2:3000'
  // - Pour Appareil Réel (Téléphone connecté au même Wi-Fi) : Utiliser l'IP de votre PC (ex: 'http://192.168.1.50:3000')
  // - Pour iOS / Desktop / Web : Utiliser 'http://localhost:3000'
  
  static const String baseUrl = 'http://10.0.2.2:3000'; // Émulateur Android local (par défaut)
  // static const String baseUrl = 'http://localhost:3000'; // iOS / Windows Desktop / Web
  // static const String baseUrl = 'http://192.168.1.50:3000'; // Remplacer par l'IP locale de votre PC pour test Wi-Fi réel
  
  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // Gateway RAG
  static const String queryRag = '/gateway-rag/query';

  // Chat RAG Assistant
  static const String sendMessage = '/chat/message';
  static const String chatHistory = '/chat/history';

  // Assets
  static const String assets = '/assets';

  // Bookings
  static const String bookings = '/bookings';
}
