abstract class MarketplaceEvent {}

class FetchMarketplaceAssetsEvent extends MarketplaceEvent {}

class CreateAssetEvent extends MarketplaceEvent {
  final String name;
  final String category;
  final String? imagePath;
  final String token;
  final int maxReservationDays;

  CreateAssetEvent({
    required this.name,
    required this.category,
    this.imagePath,
    required this.token,
    required this.maxReservationDays,
  });
}

class UpdateAssetEvent extends MarketplaceEvent {
  final String id;
  final String name;
  final String category;
  final String token;
  final int maxReservationDays;

  UpdateAssetEvent({
    required this.id,
    required this.name,
    required this.category,
    required this.token,
    required this.maxReservationDays,
  });
}

class DeleteAssetEvent extends MarketplaceEvent {
  final String id;
  final String token;

  DeleteAssetEvent({
    required this.id,
    required this.token,
  });
}
