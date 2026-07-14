class ApiEndpoints {
  static const String baseUrl = 'http://localhost:3000';
  
  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';

  // Gateway RAG
  static const String queryRag = '/gateway-rag/query';

  // Assets
  static const String assets = '/assets';

  // Bookings
  static const String bookings = '/bookings';
}
