abstract class BookingsEvent {}

class FetchMyBookingsEvent extends BookingsEvent {
  final String token;
  FetchMyBookingsEvent(this.token);
}

class CancelBookingEvent extends BookingsEvent {
  final String bookingId;
  final String token;
  CancelBookingEvent(this.bookingId, this.token);
}
