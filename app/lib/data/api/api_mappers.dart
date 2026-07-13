import '../models/models.dart';

City mapCity(Map<String, dynamic> j) => City(
      id: j['id'] as String,
      name: j['name'] as String,
    );

Venue mapVenue(Map<String, dynamic> j) {
  final hours = (j['hours'] as List<dynamic>? ?? [])
      .map((e) => e as Map<String, dynamic>)
      .map(
        (h) => VenueHours(
          daysLabel: h['daysLabel'] as String,
          open: h['open'] as String,
          close: h['close'] as String,
        ),
      )
      .toList();
  return Venue(
    id: j['id'] as String,
    cityId: j['cityId'] as String,
    shortName: j['shortName'] as String,
    fullAddress: j['fullAddress'] as String,
    phone: j['phone'] as String,
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    hours: hours,
  );
}

Category mapCategory(Map<String, dynamic> j) => Category(
      id: j['id'] as String,
      title: j['title'] as String,
      parentId: j['parentId'] as String?,
    );

Product mapProduct(Map<String, dynamic> j) {
  final nutritionJson = j['nutrition'] as Map<String, dynamic>?;
  final sizes = (j['sizes'] as List<dynamic>? ?? [])
      .map((e) => e as Map<String, dynamic>)
      .map(
        (s) => ProductSize(
          id: s['id'] as String,
          label: s['label'] as String,
          ml: s['ml'] as int,
          priceDelta: (s['priceDelta'] as num?)?.toDouble() ?? 0,
        ),
      )
      .toList();
  final mods = (j['modifierGroups'] as List<dynamic>? ?? [])
      .map((e) => e as Map<String, dynamic>)
      .map(
        (g) => ModifierGroup(
          id: g['id'] as String,
          title: g['title'] as String,
          required: g['required'] as bool? ?? false,
          options: (g['options'] as List<dynamic>? ?? [])
              .map((e) => e as Map<String, dynamic>)
              .map(
                (o) => ModifierOption(
                  id: o['id'] as String,
                  title: o['title'] as String,
                  priceDelta: (o['priceDelta'] as num?)?.toDouble() ?? 0,
                  isDefault: o['isDefault'] as bool? ?? false,
                ),
              )
              .toList(),
        ),
      )
      .toList();

  return Product(
    id: j['id'] as String,
    categoryId: j['categoryId'] as String,
    title: j['title'] as String,
    description: j['description'] as String? ?? '',
    price: (j['price'] as num).toDouble(),
    imageAsset: (j['imageUrl'] ?? j['imageAsset'] ?? '') as String,
    weightLabel: j['weightLabel'] as String?,
    featured: j['featured'] as bool? ?? false,
    nutrition: nutritionJson == null
        ? null
        : Nutrition(
            weightG: (nutritionJson['weightG'] as num).toDouble(),
            proteins: (nutritionJson['proteins'] as num).toDouble(),
            fats: (nutritionJson['fats'] as num).toDouble(),
            carbs: (nutritionJson['carbs'] as num).toDouble(),
            kcal: (nutritionJson['kcal'] as num).toDouble(),
          ),
    sizes: sizes,
    modifierGroups: mods,
  );
}

PromoSlide mapPromo(Map<String, dynamic> j) => PromoSlide(
      id: j['id'] as String,
      title: j['title'] as String,
      body: j['body'] as String,
      ctaUrl: j['ctaUrl'] as String?,
      imageAsset: (j['imageUrl'] ?? j['imageAsset']) as String?,
    );

UserProfile mapUser(Map<String, dynamic> j) => UserProfile(
      name: j['name'] as String,
      phone: j['phone'] as String,
      email: j['email'] as String?,
      birthDate: j['birthDate'] == null
          ? null
          : DateTime.tryParse(j['birthDate'] as String),
      bonusBalance: j['bonusBalance'] as int? ?? 0,
    );

OrderSummary mapOrder(Map<String, dynamic> j) => OrderSummary(
      id: j['id'] as String,
      status: j['status'] as String,
      total: (j['total'] as num).toDouble(),
      createdAt: DateTime.parse(j['createdAt'] as String),
      summaryLine: j['summaryLine'] as String?,
      venueId: j['venueId'] as String?,
    );

AppNotification mapNotification(Map<String, dynamic> j) => AppNotification(
      id: j['id'] as String,
      type: j['type'] as String,
      title: j['title'] as String,
      body: j['body'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      orderId: j['orderId'] as String?,
    );
