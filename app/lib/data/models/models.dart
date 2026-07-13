class City {
  const City({required this.id, required this.name});
  final String id;
  final String name;
}

class VenueHours {
  const VenueHours({required this.daysLabel, required this.open, required this.close});
  final String daysLabel;
  final String open;
  final String close;
}

class Venue {
  const Venue({
    required this.id,
    required this.cityId,
    required this.shortName,
    required this.fullAddress,
    required this.phone,
    required this.hours,
    required this.lat,
    required this.lng,
  });
  final String id;
  final String cityId;
  final String shortName;
  final String fullAddress;
  final String phone;
  final List<VenueHours> hours;
  final double lat;
  final double lng;
}

class Category {
  const Category({
    required this.id,
    required this.title,
    this.parentId,
    this.imageAsset,
  });
  final String id;
  final String title;
  final String? parentId;
  final String? imageAsset;
}

class Nutrition {
  const Nutrition({
    required this.weightG,
    required this.proteins,
    required this.fats,
    required this.carbs,
    required this.kcal,
  });
  final double weightG;
  final double proteins;
  final double fats;
  final double carbs;
  final double kcal;
}

class ModifierOption {
  const ModifierOption({
    required this.id,
    required this.title,
    this.priceDelta = 0,
    this.isDefault = false,
  });
  final String id;
  final String title;
  final double priceDelta;
  final bool isDefault;
}

class ModifierGroup {
  const ModifierGroup({
    required this.id,
    required this.title,
    required this.options,
    this.required = true,
  });
  final String id;
  final String title;
  final List<ModifierOption> options;
  final bool required;
}

class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.price,
    required this.imageAsset,
    this.weightLabel,
    this.nutrition,
    this.modifierGroups = const [],
    this.sizes = const [],
    this.featured = false,
  });
  final String id;
  final String categoryId;
  final String title;
  final String description;
  final double price;
  final String imageAsset;
  final String? weightLabel;
  final Nutrition? nutrition;
  final List<ModifierGroup> modifierGroups;
  final List<ProductSize> sizes;
  final bool featured;
}

class ProductSize {
  const ProductSize({required this.id, required this.label, required this.ml, this.priceDelta = 0});
  final String id;
  final String label;
  final int ml;
  final double priceDelta;
}

class SelectedModifier {
  const SelectedModifier({
    required this.groupId,
    required this.groupTitle,
    required this.optionId,
    required this.optionTitle,
    required this.priceDelta,
  });
  final String groupId;
  final String groupTitle;
  final String optionId;
  final String optionTitle;
  final double priceDelta;
}

class CartItem {
  CartItem({
    required this.product,
    required this.qty,
    this.size,
    this.modifiers = const [],
  });
  final Product product;
  int qty;
  final ProductSize? size;
  final List<SelectedModifier> modifiers;

  double get unitPrice =>
      product.price +
      (size?.priceDelta ?? 0) +
      modifiers.fold<double>(0, (s, m) => s + m.priceDelta);

  double get lineTotal => unitPrice * qty;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.orderId,
  });
  final String id;
  final String type; // order | promo
  final String title;
  final String body;
  final DateTime createdAt;
  final String? orderId;
}

class OrderSummary {
  const OrderSummary({
    required this.id,
    this.number,
    required this.status,
    required this.total,
    required this.createdAt,
    this.summaryLine,
    this.venueId,
    this.paymentTotal,
    this.bonusSpent = 0,
    this.bonusEarned = 0,
    this.items = const [],
  });
  final String id;
  final int? number;
  final String status;
  final double total;
  final DateTime createdAt;
  final String? summaryLine;
  final String? venueId;
  final double? paymentTotal;
  final int bonusSpent;
  final int bonusEarned;
  final List<OrderItemSummary> items;

  String get displayNumber => number?.toString() ?? (id.length <= 8 ? id : id.substring(0, 8));
}

class OrderItemModifierSummary {
  const OrderItemModifierSummary({
    required this.groupId,
    required this.groupTitle,
    required this.optionId,
    required this.optionTitle,
    required this.priceDelta,
  });

  final String? groupId;
  final String groupTitle;
  final String? optionId;
  final String optionTitle;
  final double priceDelta;
}

class OrderItemSummary {
  const OrderItemSummary({
    required this.productId,
    required this.title,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
    this.sizeId,
    this.sizeLabel,
    this.sizeMl,
    this.sizePriceDelta = 0,
    this.modifiers = const [],
  });

  final String? productId;
  final String title;
  final int qty;
  final double unitPrice;
  final double lineTotal;
  final String? sizeId;
  final String? sizeLabel;
  final int? sizeMl;
  final double sizePriceDelta;
  final List<OrderItemModifierSummary> modifiers;
}

/// Minimal response returned when the server has created an order ready for
/// YooKassa payment. It is intentionally separate from [OrderSummary]: a
/// newly created order does not yet have all history fields populated.
class CheckoutOrder {
  const CheckoutOrder({
    required this.id,
    required this.status,
    required this.total,
    required this.paymentTotal,
    required this.bonusSpent,
  });
  final String id;
  final String status;
  final double total;
  final double paymentTotal;
  final int bonusSpent;
}

class YooKassaPayment {
  const YooKassaPayment({
    required this.paymentId,
    required this.confirmationUrl,
    required this.status,
  });
  final String paymentId;
  final String confirmationUrl;
  final String status;
}

class YooKassaPaymentStatus {
  const YooKassaPaymentStatus({
    required this.orderId,
    required this.orderStatus,
    required this.paymentStatus,
  });
  final String orderId;
  final String orderStatus;
  final String paymentStatus;

  bool get isPaid => orderStatus == 'confirmed' || paymentStatus == 'succeeded';
}

class PromoSlide {
  const PromoSlide({
    required this.id,
    required this.title,
    required this.body,
    this.ctaUrl,
    this.imageAsset,
  });
  final String id;
  final String title;
  final String body;
  final String? ctaUrl;
  final String? imageAsset;
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.phone,
    this.email,
    this.birthDate,
    this.bonusBalance = 0,
  });
  final String name;
  final String phone;
  final String? email;
  final DateTime? birthDate;
  final int bonusBalance;
}
