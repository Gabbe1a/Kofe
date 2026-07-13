import 'package:kofe_mama/data/api/kofe_api.dart';
import 'package:kofe_mama/data/mock/mock_data.dart';
import 'package:kofe_mama/data/models/models.dart';

/// In-memory API for widget tests (no network).
class FakeKofeApi extends KofeApi {
  FakeKofeApi() : super(baseUrl: 'http://test.local');

  @override
  Future<List<City>> fetchCities() async => MockData.cities;

  @override
  Future<List<Venue>> fetchVenues({String? cityId}) async {
    if (cityId == null) return MockData.venues;
    return MockData.venuesForCity(cityId);
  }

  @override
  Future<List<Category>> fetchCategories() async => MockData.categories;

  @override
  Future<List<Product>> fetchProducts({
    String? categoryId,
    bool? featured,
    String? q,
    String? venueId,
  }) async {
    var list = MockData.products;
    if (categoryId != null) {
      list = MockData.productsForCategory(categoryId);
    }
    if (featured == true) {
      list = list.where((p) => p.featured).toList();
    }
    if (q != null && q.trim().isNotEmpty) {
      list = MockData.search(q);
      if (categoryId != null) {
        list = list.where((p) => p.categoryId == categoryId).toList();
      }
    }
    return list;
  }

  @override
  Future<Product> fetchProduct(String id, {String? venueId}) async =>
      MockData.productById(id);

  @override
  Future<List<PromoSlide>> fetchPromoSlides() async => MockData.promoSlides;

  @override
  Future<UserProfile> fetchMe() async => MockData.demoUser;

  @override
  Future<List<OrderSummary>> fetchOrders() async => MockData.orders;

  @override
  Future<OrderSummary> fetchOrder(String id) async =>
      MockData.orders.firstWhere((o) => o.id == id, orElse: () => MockData.orders.first);

  @override
  Future<List<AppNotification>> fetchNotifications() async =>
      MockData.notifications;
}
