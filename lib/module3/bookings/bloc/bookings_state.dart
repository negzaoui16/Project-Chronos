abstract class BookingsState {}
class BookingsInitial extends BookingsState {}

class BookingsLoading extends BookingsState {}

class BookingsLoaded extends BookingsState {
  final List<dynamic> activeBookings;
  final List<dynamic> pendingBookings;
  final List<dynamic> historyBookings;

  BookingsLoaded({required this.activeBookings, required this.pendingBookings, required this.historyBookings});
}

class BookingsError extends BookingsState {
  final String message;
  BookingsError(this.message);
}

class BookingCancelledSuccess extends BookingsState {
  final String message;
  BookingCancelledSuccess(this.message);
}
