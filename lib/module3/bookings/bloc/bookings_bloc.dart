import 'package:flutter_bloc/flutter_bloc.dart';
import 'bookings_event.dart';
import 'bookings_state.dart';

class BookingsBloc extends Bloc<BookingsEvent, BookingsState> {
  BookingsBloc() : super(BookingsInitial()) {
    // Skeleton implementation
  }
}
