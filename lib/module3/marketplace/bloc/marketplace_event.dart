abstract class MarketplaceEvent {}

class FetchMarketplaceAssetsEvent extends MarketplaceEvent {}

class CreateAssetEvent extends MarketplaceEvent {
  final String name;
  final String category;
  final String? imagePath;
  final String token;

  CreateAssetEvent({
    required this.name,
    required this.category,
    this.imagePath,
    required this.token,
  });
}
