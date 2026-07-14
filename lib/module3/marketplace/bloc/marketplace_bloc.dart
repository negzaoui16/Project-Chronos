import 'package:flutter_bloc/flutter_bloc.dart';
import 'marketplace_event.dart';
import 'marketplace_state.dart';

class MarketplaceBloc extends Bloc<MarketplaceEvent, MarketplaceState> {
  MarketplaceBloc() : super(MarketplaceInitial()) {
    // Skeleton implementation
  }
}
