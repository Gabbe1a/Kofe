import '../../data/models/models.dart';

enum ThemePreference {
  system,
  light,
  dark;

  static ThemePreference fromStorage(String? value) => switch (value) {
    'light' => ThemePreference.light,
    'dark' => ThemePreference.dark,
    _ => ThemePreference.system,
  };
}

class SessionState {
  const SessionState({
    this.cityId,
    this.venueId,
    this.city,
    this.venue,
    this.isAuthed = false,
    this.user,
    this.promoSeen = false,
    this.savedComment,
    this.saveComment = false,
    this.hasSeenWelcome = false,
    this.themePreference = ThemePreference.system,
  });

  final String? cityId;
  final String? venueId;
  final City? city;
  final Venue? venue;
  final bool isAuthed;
  final UserProfile? user;
  final bool promoSeen;
  final String? savedComment;
  final bool saveComment;
  final bool hasSeenWelcome;
  final ThemePreference themePreference;

  SessionState copyWith({
    String? cityId,
    String? venueId,
    City? city,
    Venue? venue,
    bool clearVenue = false,
    bool clearCity = false,
    bool? isAuthed,
    UserProfile? user,
    bool clearUser = false,
    bool? promoSeen,
    String? savedComment,
    bool? saveComment,
    bool? hasSeenWelcome,
    ThemePreference? themePreference,
  }) {
    return SessionState(
      cityId: clearCity ? null : (cityId ?? this.cityId),
      venueId: clearVenue ? null : (venueId ?? this.venueId),
      city: clearCity ? null : (city ?? this.city),
      venue: clearVenue ? null : (venue ?? this.venue),
      isAuthed: isAuthed ?? this.isAuthed,
      user: clearUser ? null : (user ?? this.user),
      promoSeen: promoSeen ?? this.promoSeen,
      savedComment: savedComment ?? this.savedComment,
      saveComment: saveComment ?? this.saveComment,
      hasSeenWelcome: hasSeenWelcome ?? this.hasSeenWelcome,
      themePreference: themePreference ?? this.themePreference,
    );
  }
}

class CartState {
  const CartState({
    this.items = const [],
    this.addressConfirmed = false,
    this.promoCode,
    this.comment,
    this.pickupAt,
    this.bonusPoints = 0,
    this.paymentLabel = 'Онлайн через ЮKassa',
  });

  final List<CartItem> items;
  final bool addressConfirmed;
  final String? promoCode;
  final String? comment;
  final DateTime? pickupAt;
  final int bonusPoints;
  final String paymentLabel;

  int get totalQty => items.fold(0, (s, i) => s + i.qty);

  double get subtotal => items.fold(0, (s, i) => s + i.lineTotal);

  double get total => subtotal;

  int get effectiveBonusPoints {
    if (total <= 1) return 0;
    final orderLimit = (total - 1).floor();
    return bonusPoints.clamp(0, orderLimit) as int;
  }

  double get paymentTotal => isEmpty ? 0 : total - effectiveBonusPoints;

  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    bool? addressConfirmed,
    String? promoCode,
    bool clearPromo = false,
    String? comment,
    bool clearComment = false,
    DateTime? pickupAt,
    bool clearPickup = false,
    int? bonusPoints,
    String? paymentLabel,
  }) {
    return CartState(
      items: items ?? this.items,
      addressConfirmed: addressConfirmed ?? this.addressConfirmed,
      promoCode: clearPromo ? null : (promoCode ?? this.promoCode),
      comment: clearComment ? null : (comment ?? this.comment),
      pickupAt: clearPickup ? null : (pickupAt ?? this.pickupAt),
      bonusPoints: bonusPoints ?? this.bonusPoints,
      paymentLabel: paymentLabel ?? this.paymentLabel,
    );
  }
}
