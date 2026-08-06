import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'bookings_event.dart';
import 'bookings_state.dart';

class BookingsBloc extends Bloc<BookingsEvent, BookingsState> {
  final ApiClient _apiClient = ApiClient();

  BookingsBloc() : super(BookingsInitial()) {
    on<FetchMyBookingsEvent>((event, emit) async {
      emit(BookingsLoading());
      try {
        final response = await _apiClient.dio.get(
          '/bookings/my',
          options: Options(headers: {'Authorization': 'Bearer ${event.token}'}),
        );
        final List<dynamic> allBookings = response.data;
        
        final activeBookings = allBookings.where((b) => b['status'] == 'ACTIVE').toList();
        final pendingBookings = allBookings.where((b) => b['status'] == 'PENDING').toList();
        final historyBookings = allBookings.where((b) => b['status'] != 'ACTIVE' && b['status'] != 'PENDING').toList();
        
        emit(BookingsLoaded(
          activeBookings: activeBookings,
          pendingBookings: pendingBookings,
          historyBookings: historyBookings,
        ));
      } on DioException catch (e) {
        final msg = e.response?.data?['message'] ?? 'Failed to load bookings.';
        emit(BookingsError(msg));
      } catch (_) {
        emit(BookingsError('Unexpected error loading bookings.'));
      }
    });

    on<CancelBookingEvent>((event, emit) async {
      emit(BookingsLoading());
      try {
        final response = await _apiClient.dio.post(
          '/bookings/${event.bookingId}/cancel',
          options: Options(headers: {'Authorization': 'Bearer ${event.token}'}),
        );
        emit(BookingCancelledSuccess(response.data['message'] ?? 'Booking cancelled.'));
        add(FetchMyBookingsEvent(event.token)); // Refresh list
      } on DioException catch (e) {
        final msg = e.response?.data?['message'] ?? 'Failed to cancel booking.';
        emit(BookingsError(msg));
        add(FetchMyBookingsEvent(event.token)); // Refresh list anyway to revert loading state
      } catch (_) {
        emit(BookingsError('Unexpected error cancelling booking.'));
        add(FetchMyBookingsEvent(event.token));
      }
    });
  }
}
