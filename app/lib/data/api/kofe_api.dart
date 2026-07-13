import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'api_mappers.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class KofeApi {
  KofeApi({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Uri _u(String path, [Map<String, String>? query]) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await _client
            .get(_u(path, query))
            .timeout(const Duration(seconds: 20));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw ApiException(_message(res), statusCode: res.statusCode);
        }
        return jsonDecode(utf8.decode(res.bodyBytes));
      } on http.ClientException {
        if (attempt == 1) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 450));
      } on TimeoutException {
        if (attempt == 1) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }
    }
    throw StateError('GET retry loop completed unexpectedly');
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final res = await _client
        .post(
          _u(path),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(_message(res), statusCode: res.statusCode);
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  String _message(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {
      // The body is not JSON. Its text is still more useful than a status code.
    }
    return body.isEmpty ? 'Ошибка запроса (${response.statusCode})' : body;
  }

  String? _optionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<List<City>> fetchCities() async {
    final data = await _get('/cities') as List<dynamic>;
    return data.map((e) => mapCity(e as Map<String, dynamic>)).toList();
  }

  Future<List<Venue>> fetchVenues({String? cityId}) async {
    final data = await _get(
      '/venues',
      cityId == null ? null : {'city_id': cityId},
    ) as List<dynamic>;
    return data.map((e) => mapVenue(e as Map<String, dynamic>)).toList();
  }

  Future<List<Category>> fetchCategories() async {
    final data = await _get('/categories') as List<dynamic>;
    return data.map((e) => mapCategory(e as Map<String, dynamic>)).toList();
  }

  Future<List<Product>> fetchProducts({
    String? categoryId,
    bool? featured,
    String? q,
    String? venueId,
  }) async {
    // A selected venue is the source of truth for price/availability. The
    // server applies its stop-list before the client filters presentation.
    if (venueId != null) {
      final data = await _get('/menu', {'venue_id': venueId}) as List<dynamic>;
      var products = data
          .map((e) => mapProduct(e as Map<String, dynamic>))
          .toList();
      if (categoryId != null) {
        products = products.where((p) => p.categoryId == categoryId).toList();
      }
      if (featured == true) {
        products = products.where((p) => p.featured).toList();
      }
      if (q != null && q.trim().isNotEmpty) {
        final query = q.trim().toLowerCase();
        products = products
            .where(
              (p) => p.title.toLowerCase().contains(query) ||
                  p.description.toLowerCase().contains(query),
            )
            .toList();
      }
      return products;
    }
    final query = <String, String>{};
    if (categoryId != null) query['category_id'] = categoryId;
    if (featured != null) query['featured'] = featured.toString();
    if (q != null && q.trim().isNotEmpty) query['q'] = q.trim();
    final data = await _get('/products', query.isEmpty ? null : query) as List<dynamic>;
    return data.map((e) => mapProduct(e as Map<String, dynamic>)).toList();
  }

  Future<Product> fetchProduct(String id, {String? venueId}) async {
    final data = await _get(
      '/products/$id',
      venueId == null ? null : {'venue_id': venueId},
    ) as Map<String, dynamic>;
    return mapProduct(data);
  }

  Future<List<PromoSlide>> fetchPromoSlides() async {
    final data = await _get('/promo-slides') as List<dynamic>;
    return data.map((e) => mapPromo(e as Map<String, dynamic>)).toList();
  }

  Future<UserProfile> fetchMe() async {
    final data = await _get('/me') as Map<String, dynamic>;
    return mapUser(data);
  }

  Future<List<OrderSummary>> fetchOrders() async {
    final data = await _get('/orders') as List<dynamic>;
    return data.map((e) => mapOrder(e as Map<String, dynamic>)).toList();
  }

  Future<OrderSummary> fetchOrder(String id) async {
    final data = await _get('/orders/$id') as Map<String, dynamic>;
    return mapOrder(data);
  }

  Future<CheckoutOrder> createOrder({
    required String venueId,
    required List<CartItem> items,
    required String idempotencyKey,
    String? promoCode,
    String? comment,
    DateTime? pickupAt,
    int bonusPoints = 0,
  }) async {
    final data = await _post('/orders', {
      'venue_id': venueId,
      'items': [
        for (final item in items)
          {
            'product_id': item.product.id,
            'qty': item.qty,
            'size_id': item.size?.id,
            'modifiers': [
              for (final modifier in item.modifiers)
                {
                  'group_id': modifier.groupId,
                  'option_id': modifier.optionId,
                },
            ],
          },
      ],
      'promo_code': _optionalText(promoCode),
      'bonus_points': bonusPoints,
      'address_confirmed': true,
      'comment': _optionalText(comment),
      'pickup_at': pickupAt?.toUtc().toIso8601String(),
      'idempotency_key': idempotencyKey,
    }) as Map<String, dynamic>;
    return CheckoutOrder(
      id: data['id'] as String,
      status: data['status'] as String,
      total: (data['total'] as num).toDouble(),
      paymentTotal: (data['paymentTotal'] as num).toDouble(),
      bonusSpent: data['bonusSpent'] as int? ?? 0,
    );
  }

  Future<YooKassaPayment> startYooKassaPayment(String orderId) async {
    final data = await _post('/orders/$orderId/payment', const {}) as Map<String, dynamic>;
    return YooKassaPayment(
      paymentId: data['paymentId'] as String,
      confirmationUrl: data['confirmationUrl'] as String,
      status: data['status'] as String,
    );
  }

  Future<YooKassaPaymentStatus> refreshYooKassaPayment(String orderId) async {
    final data = await _get('/orders/$orderId/payment-status') as Map<String, dynamic>;
    return YooKassaPaymentStatus(
      orderId: data['orderId'] as String,
      orderStatus: data['orderStatus'] as String,
      paymentStatus: data['paymentStatus'] as String,
    );
  }

  Future<List<AppNotification>> fetchNotifications() async {
    final data = await _get('/notifications') as List<dynamic>;
    return data.map((e) => mapNotification(e as Map<String, dynamic>)).toList();
  }
}
