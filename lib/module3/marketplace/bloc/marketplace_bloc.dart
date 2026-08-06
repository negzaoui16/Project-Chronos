import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/constants/api_endpoints.dart';
import 'marketplace_event.dart';
import 'marketplace_state.dart';

class MarketplaceBloc extends Bloc<MarketplaceEvent, MarketplaceState> {
  final ApiClient _apiClient = ApiClient();

  MarketplaceBloc() : super(MarketplaceInitial()) {
    // ─── Fetch all assets from Neon DB via NestJS ────────────────────────────
    on<FetchMarketplaceAssetsEvent>((event, emit) async {
      emit(MarketplaceLoading());
      try {
        final response = await _apiClient.dio.get(ApiEndpoints.assets);
        final List<dynamic> data = response.data;

        final assets = data.map((json) {
          // Map AssetStatus from backend to display labels
          final status = json['status'] as String? ?? 'AVAILABLE';
          final displayStatus = status == 'AVAILABLE' ? 'LIVE' : 'RESERVED';
          final availText = status == 'AVAILABLE' ? 'Available Now' : 'Currently Reserved';

          return MarketplaceAsset(
            id: json['id'] ?? '',
            title: json['name'] ?? '',
            description: json['description'] ?? 'No description available.',
            imageUrl: json['imageUrl'] ?? '',
            status: displayStatus,
            availabilityText: availText,
            category: json['category'] ?? 'Hardware',
            maxReservationDays: json['maxReservationDays'] ?? 3,
          );
        }).toList();

        emit(MarketplaceLoaded(assets: assets));
      } on DioException catch (e) {
        final msg = e.response?.data?['message'] ?? 'Failed to load assets.';
        emit(MarketplaceError(message: msg));
      } catch (_) {
        emit(MarketplaceError(message: 'Unexpected error loading assets.'));
      }
    });

    // ─── Create asset (Admin only) → Cloudinary image + Neon DB ─────────────
    on<CreateAssetEvent>((event, emit) async {
      emit(MarketplaceLoading());
      try {
        FormData formData;

        if (event.imagePath != null) {
          final imageFile = await MultipartFile.fromFile(
            event.imagePath!,
            filename: 'asset_image.jpg',
          );
          formData = FormData.fromMap({
            'name': event.name,
            'category': event.category,
            'maxReservationDays': event.maxReservationDays,
            'image': imageFile,
          });
        } else {
          formData = FormData.fromMap({
            'name': event.name,
            'category': event.category,
            'maxReservationDays': event.maxReservationDays,
          });
        }

        await _apiClient.dio.post(
          ApiEndpoints.assets,
          data: formData,
          options: Options(
            headers: {
              'Authorization': 'Bearer ${event.token}',
              'Content-Type': 'multipart/form-data',
            },
          ),
        );

        // After successful create, refresh the asset list from DB
        add(FetchMarketplaceAssetsEvent());
      } on DioException catch (e) {
        final msg = e.response?.data?['message'] ?? 'Failed to create asset.';
        emit(MarketplaceError(message: msg));
      } catch (_) {
        emit(MarketplaceError(message: 'Unexpected error creating asset.'));
      }
    });

    on<UpdateAssetEvent>((event, emit) async {
      emit(MarketplaceLoading());
      try {
        await _apiClient.dio.put(
          '${ApiEndpoints.assets}/${event.id}',
          data: {
            'name': event.name,
            'category': event.category,
            'maxReservationDays': event.maxReservationDays,
          },
          options: Options(
            headers: {
              'Authorization': 'Bearer ${event.token}',
            },
          ),
        );
        add(FetchMarketplaceAssetsEvent());
      } on DioException catch (e) {
        final msg = e.response?.data?['message'] ?? 'Failed to update asset.';
        emit(MarketplaceError(message: msg));
      } catch (_) {
        emit(MarketplaceError(message: 'Unexpected error updating asset.'));
      }
    });

    on<DeleteAssetEvent>((event, emit) async {
      emit(MarketplaceLoading());
      try {
        await _apiClient.dio.delete(
          '${ApiEndpoints.assets}/${event.id}',
          options: Options(
            headers: {
              'Authorization': 'Bearer ${event.token}',
            },
          ),
        );
        add(FetchMarketplaceAssetsEvent());
      } on DioException catch (e) {
        final msg = e.response?.data?['message'] ?? 'Failed to delete asset.';
        emit(MarketplaceError(message: msg));
      } catch (_) {
        emit(MarketplaceError(message: 'Unexpected error deleting asset.'));
      }
    });
  }
}
