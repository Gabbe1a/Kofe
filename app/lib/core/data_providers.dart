import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/kofe_api.dart';
import '../data/models/models.dart';
import 'config/app_config.dart';
import 'providers.dart';

final apiProvider = Provider<KofeApi>((ref) {
  return KofeApi(baseUrl: AppConfig.apiBaseUrl);
});

final citiesProvider = FutureProvider<List<City>>((ref) {
  return ref.watch(apiProvider).fetchCities();
});

final venuesProvider = FutureProvider.family<List<Venue>, String?>((ref, cityId) {
  return ref.watch(apiProvider).fetchVenues(cityId: cityId);
});

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(apiProvider).fetchCategories();
});

final productsProvider = FutureProvider.family<List<Product>, String?>((
  ref,
  categoryId,
) {
  final venueId = ref.watch(sessionProvider.select((s) => s.venueId));
  return ref
      .watch(apiProvider)
      .fetchProducts(categoryId: categoryId, venueId: venueId);
});

final featuredProductsProvider = FutureProvider<List<Product>>((ref) {
  final venueId = ref.watch(sessionProvider.select((s) => s.venueId));
  return ref.watch(apiProvider).fetchProducts(featured: true, venueId: venueId);
});

final productProvider = FutureProvider.autoDispose.family<Product, String>((ref, id) {
  final venueId = ref.watch(sessionProvider.select((s) => s.venueId));
  return ref.watch(apiProvider).fetchProduct(id, venueId: venueId);
});

final productSearchProvider = FutureProvider.family<List<Product>, String>((
  ref,
  query,
) {
  final venueId = ref.watch(sessionProvider.select((s) => s.venueId));
  return ref.watch(apiProvider).fetchProducts(q: query, venueId: venueId);
});

final promoSlidesProvider = FutureProvider<List<PromoSlide>>((ref) {
  return ref.watch(apiProvider).fetchPromoSlides();
});

final meProvider = FutureProvider<UserProfile>((ref) {
  return ref.watch(apiProvider).fetchMe();
});

final ordersProvider = FutureProvider<List<OrderSummary>>((ref) {
  return ref.watch(apiProvider).fetchOrders();
});

final orderProvider = FutureProvider.family<OrderSummary, String>((ref, id) {
  return ref.watch(apiProvider).fetchOrder(id);
});

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  return ref.watch(apiProvider).fetchNotifications();
});
