import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../data/api/api_mappers.dart';
import '../../data/models/models.dart';
import '../session_cart_state.dart';

/// Device-local JSON persistence for session + cart (survives flutter run restart).
class LocalStore {
  LocalStore._(this._file, this.session, this.cart);

  final File _file;
  SessionState session;
  CartState cart;

  static Future<LocalStore> open() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/kofe_mama_local.json');
    if (!await file.exists()) {
      return LocalStore._(file, const SessionState(), const CartState());
    }
    try {
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return LocalStore._(
        file,
        _decodeSession(raw['session'] as Map<String, dynamic>?),
        _decodeCart(raw['cart'] as Map<String, dynamic>?),
      );
    } catch (_) {
      return LocalStore._(file, const SessionState(), const CartState());
    }
  }

  Future<void> save() async {
    final payload = <String, dynamic>{
      'session': _encodeSession(session),
      'cart': _encodeCart(cart),
    };
    await _file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
  }

  Future<void> saveSession(SessionState next) async {
    session = next;
    await save();
  }

  Future<void> saveCart(CartState next) async {
    cart = next;
    await save();
  }
}

Map<String, dynamic> _encodeSession(SessionState s) => {
      'isAuthed': s.isAuthed,
      'promoSeen': s.promoSeen,
      'saveComment': s.saveComment,
      'savedComment': s.savedComment,
      'hasSeenWelcome': s.hasSeenWelcome,
      'themePreference': s.themePreference.name,
      'city': s.city == null
          ? null
          : {'id': s.city!.id, 'name': s.city!.name},
      'venue': s.venue == null ? null : _encodeVenue(s.venue!),
      'user': s.user == null ? null : _encodeUser(s.user!),
    };

SessionState _decodeSession(Map<String, dynamic>? j) {
  if (j == null) return const SessionState();
  final cityJson = j['city'] as Map<String, dynamic>?;
  final venueJson = j['venue'] as Map<String, dynamic>?;
  final userJson = j['user'] as Map<String, dynamic>?;
  final city = cityJson == null ? null : mapCity(cityJson);
  final venue = venueJson == null ? null : _decodeVenue(venueJson);
  final user = userJson == null ? null : mapUser(userJson);
  final isAuthed = j['isAuthed'] as bool? ?? user != null;
  // Existing installations already completed the old auto-splash flow and
  // should not be interrupted by a new first-run welcome after an update.
  final hasStoredPlace = cityJson != null || venueJson != null;
  return SessionState(
    cityId: city?.id,
    venueId: venue?.id,
    city: city,
    venue: venue,
    isAuthed: isAuthed,
    user: user,
    promoSeen: j['promoSeen'] as bool? ?? false,
    savedComment: j['savedComment'] as String?,
    saveComment: j['saveComment'] as bool? ?? false,
    hasSeenWelcome: j['hasSeenWelcome'] as bool? ?? hasStoredPlace,
    themePreference: ThemePreference.fromStorage(j['themePreference'] as String?),
  );
}

Map<String, dynamic> _encodeUser(UserProfile u) => {
      'name': u.name,
      'phone': u.phone,
      'email': u.email,
      'birthDate': u.birthDate?.toIso8601String(),
      'bonusBalance': u.bonusBalance,
    };

Map<String, dynamic> _encodeVenue(Venue v) => {
      'id': v.id,
      'cityId': v.cityId,
      'shortName': v.shortName,
      'fullAddress': v.fullAddress,
      'phone': v.phone,
      'lat': v.lat,
      'lng': v.lng,
      'hours': [
        for (final h in v.hours)
          {
            'daysLabel': h.daysLabel,
            'open': h.open,
            'close': h.close,
          },
      ],
    };

Venue _decodeVenue(Map<String, dynamic> j) => mapVenue(j);

Map<String, dynamic> _encodeCart(CartState c) => {
      'addressConfirmed': c.addressConfirmed,
      'promoCode': c.promoCode,
      'comment': c.comment,
      'pickupAt': c.pickupAt?.toIso8601String(),
      'bonusPoints': c.bonusPoints,
      'paymentLabel': c.paymentLabel,
      'items': [for (final i in c.items) _encodeCartItem(i)],
    };

CartState _decodeCart(Map<String, dynamic>? j) {
  if (j == null) return const CartState();
  final items = (j['items'] as List<dynamic>? ?? [])
      .map((e) => _decodeCartItem(e as Map<String, dynamic>))
      .toList();
  final savedPaymentLabel = j['paymentLabel'] as String?;
  return CartState(
    items: items,
    addressConfirmed: j['addressConfirmed'] as bool? ?? false,
    promoCode: j['promoCode'] as String?,
    comment: j['comment'] as String?,
    pickupAt: j['pickupAt'] == null
        ? null
        : DateTime.tryParse(j['pickupAt'] as String),
    bonusPoints: j['bonusPoints'] as int? ?? 0,
    // The old build persisted a fictitious saved card. It is not a real
    // payment instrument and must never appear after moving to YooKassa.
    paymentLabel: savedPaymentLabel == null || savedPaymentLabel == 'Карта 2056'
        ? 'Онлайн через ЮKassa'
        : savedPaymentLabel,
  );
}

Map<String, dynamic> _encodeCartItem(CartItem i) => {
      'qty': i.qty,
      'product': _encodeProduct(i.product),
      'size': i.size == null
          ? null
          : {
              'id': i.size!.id,
              'label': i.size!.label,
              'ml': i.size!.ml,
              'priceDelta': i.size!.priceDelta,
            },
      'modifiers': [
        for (final m in i.modifiers)
          {
            'groupId': m.groupId,
            'groupTitle': m.groupTitle,
            'optionId': m.optionId,
            'optionTitle': m.optionTitle,
            'priceDelta': m.priceDelta,
          },
      ],
    };

CartItem _decodeCartItem(Map<String, dynamic> j) {
  final sizeJson = j['size'] as Map<String, dynamic>?;
  final mods = (j['modifiers'] as List<dynamic>? ?? [])
      .map((e) => e as Map<String, dynamic>)
      .map(
        (m) => SelectedModifier(
          groupId: m['groupId'] as String,
          groupTitle: m['groupTitle'] as String,
          optionId: m['optionId'] as String,
          optionTitle: m['optionTitle'] as String,
          priceDelta: (m['priceDelta'] as num?)?.toDouble() ?? 0,
        ),
      )
      .toList();
  return CartItem(
    product: _decodeProduct(j['product'] as Map<String, dynamic>),
    qty: j['qty'] as int? ?? 1,
    size: sizeJson == null
        ? null
        : ProductSize(
            id: sizeJson['id'] as String,
            label: sizeJson['label'] as String,
            ml: sizeJson['ml'] as int,
            priceDelta: (sizeJson['priceDelta'] as num?)?.toDouble() ?? 0,
          ),
    modifiers: mods,
  );
}

Map<String, dynamic> _encodeProduct(Product p) => {
      'id': p.id,
      'categoryId': p.categoryId,
      'title': p.title,
      'description': p.description,
      'price': p.price,
      'imageAsset': p.imageAsset,
      'weightLabel': p.weightLabel,
      'featured': p.featured,
      'nutrition': p.nutrition == null
          ? null
          : {
              'weightG': p.nutrition!.weightG,
              'proteins': p.nutrition!.proteins,
              'fats': p.nutrition!.fats,
              'carbs': p.nutrition!.carbs,
              'kcal': p.nutrition!.kcal,
            },
      'sizes': [
        for (final s in p.sizes)
          {
            'id': s.id,
            'label': s.label,
            'ml': s.ml,
            'priceDelta': s.priceDelta,
          },
      ],
      'modifierGroups': [
        for (final g in p.modifierGroups)
          {
            'id': g.id,
            'title': g.title,
            'required': g.required,
            'options': [
              for (final o in g.options)
                {
                  'id': o.id,
                  'title': o.title,
                  'priceDelta': o.priceDelta,
                  'isDefault': o.isDefault,
                },
            ],
          },
      ],
    };

Product _decodeProduct(Map<String, dynamic> j) => mapProduct(j);
