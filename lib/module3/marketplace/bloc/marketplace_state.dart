abstract class MarketplaceState {}

class MarketplaceInitial extends MarketplaceState {}

class MarketplaceLoading extends MarketplaceState {}

class MarketplaceLoaded extends MarketplaceState {
  final List<MarketplaceAsset> assets;
  MarketplaceLoaded({required this.assets});
}

class MarketplaceError extends MarketplaceState {
  final String message;
  MarketplaceError({required this.message});
}

class MarketplaceAsset {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String status; // e.g. "LIVE" or "RESERVED"
  final String availabilityText; // e.g. "Available Now" or "Returns in 2d"
  final String category; // e.g. "Hardware", "Labs", "Space"

  MarketplaceAsset({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.status,
    required this.availabilityText,
    required this.category,
  });
}
