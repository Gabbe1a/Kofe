import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import 'session_cart_state.dart';
import 'storage/local_store.dart';

export 'session_cart_state.dart';

/// Filled in [main] before runApp.
LocalStore? _bootStore;

void bindLocalStore(LocalStore store) => _bootStore = store;

LocalStore? get optionalLocalStore => _bootStore;

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(SessionState initial) : super(initial);

  Future<void> _persist() async {
    final store = optionalLocalStore;
    if (store == null) return;
    await store.saveSession(state);
  }

  void setCity(City city) {
    state = state.copyWith(
      cityId: city.id,
      city: city,
      clearVenue: true,
    );
    _persist();
  }

  void setVenue(Venue venue) {
    state = state.copyWith(
      venueId: venue.id,
      venue: venue,
    );
    _persist();
  }

  void markPromoSeen() {
    state = state.copyWith(promoSeen: true);
    _persist();
  }

  void markWelcomeSeen() {
    state = state.copyWith(hasSeenWelcome: true);
    _persist();
  }

  void setThemePreference(ThemePreference preference) {
    state = state.copyWith(themePreference: preference);
    _persist();
  }

  void setNotificationsEnabled(bool enabled) {
    state = state.copyWith(notificationsEnabled: enabled);
    _persist();
  }

  void login(UserProfile user) {
    state = state.copyWith(isAuthed: true, user: user);
    _persist();
  }

  void updateUser(UserProfile user) {
    state = state.copyWith(isAuthed: true, user: user);
    _persist();
  }

  void logout() {
    state = state.copyWith(isAuthed: false, clearUser: true);
    _persist();
  }

  void setComment(String? text, {required bool save}) {
    state = state.copyWith(savedComment: text, saveComment: save);
    _persist();
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  final initial = _bootStore?.session ?? const SessionState();
  return SessionNotifier(initial);
});

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier(CartState initial) : super(initial);

  Future<void> _persist() async {
    final store = optionalLocalStore;
    if (store == null) return;
    await store.saveCart(state);
  }

  void add({
    required Product product,
    int qty = 1,
    ProductSize? size,
    List<SelectedModifier> modifiers = const [],
  }) {
    final next = [...state.items];
    final idx = next.indexWhere(
      (i) =>
          i.product.id == product.id &&
          i.size?.id == size?.id &&
          _sameMods(i.modifiers, modifiers),
    );
    if (idx >= 0) {
      next[idx].qty += qty;
    } else {
      next.add(CartItem(
        product: product,
        qty: qty,
        size: size,
        modifiers: modifiers,
      ));
    }
    state = state.copyWith(
      items: next,
      addressConfirmed: state.items.isEmpty ? false : state.addressConfirmed,
    );
    _persist();
  }

  bool _sameMods(List<SelectedModifier> a, List<SelectedModifier> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].optionId != b[i].optionId) return false;
    }
    return true;
  }

  void setQty(int index, int qty) {
    final next = [...state.items];
    if (qty <= 0) {
      next.removeAt(index);
    } else {
      next[index].qty = qty;
    }
    state = state.copyWith(items: next);
    _persist();
  }

  /// Replaces the configuration of one existing line without adding a second
  /// product to the cart. The line index is the same index rendered by cart.
  void updateItem(
    int index, {
    required Product product,
    required int qty,
    ProductSize? size,
    required List<SelectedModifier> modifiers,
  }) {
    if (index < 0 || index >= state.items.length) return;

    final next = [...state.items];
    next[index] = CartItem(
      product: product,
      qty: qty.clamp(1, 99) as int,
      size: size,
      modifiers: modifiers,
    );
    state = state.copyWith(items: next);
    _persist();
  }

  /// Refresh prices and option deltas in a persisted cart from the currently
  /// selected venue menu. Cart rows keep only choices that are still offered.
  void syncWithCatalog(List<Product> catalog) {
    final byId = {for (final product in catalog) product.id: product};
    var changed = false;
    final next = <CartItem>[];

    for (final item in state.items) {
      final product = byId[item.product.id];
      if (product == null) {
        // The product has been removed from this venue's live menu.
        changed = true;
        continue;
      }

      ProductSize? size;
      if (item.size != null) {
        for (final candidate in product.sizes) {
          if (candidate.id == item.size!.id) {
            size = candidate;
            break;
          }
        }
      }

      final modifiers = <SelectedModifier>[];
      for (final oldModifier in item.modifiers) {
        ModifierGroup? group;
        for (final candidate in product.modifierGroups) {
          if (candidate.id == oldModifier.groupId) {
            group = candidate;
            break;
          }
        }
        if (group == null) continue;
        ModifierOption? option;
        for (final candidate in group.options) {
          if (candidate.id == oldModifier.optionId) {
            option = candidate;
            break;
          }
        }
        if (option == null) continue;
        modifiers.add(SelectedModifier(
          groupId: group.id,
          groupTitle: group.title,
          optionId: option.id,
          optionTitle: option.title,
          priceDelta: option.priceDelta,
        ));
      }

      final selectionChanged =
          size?.id != item.size?.id ||
          size?.priceDelta != item.size?.priceDelta ||
          modifiers.length != item.modifiers.length ||
          modifiers.asMap().entries.any((entry) {
            final old = item.modifiers[entry.key];
            final fresh = entry.value;
            return old.groupId != fresh.groupId ||
                old.optionId != fresh.optionId ||
                old.priceDelta != fresh.priceDelta;
          });
      if (item.product.price != product.price ||
          item.product.title != product.title ||
          item.product.imageAsset != product.imageAsset ||
          selectionChanged) {
        changed = true;
      }
      next.add(CartItem(
        product: product,
        qty: item.qty,
        size: size,
        modifiers: modifiers,
      ));
    }

    if (changed) {
      state = state.copyWith(items: next);
      _persist();
    }
  }

  void clear() {
    state = state.copyWith(
      items: [],
      bonusPoints: 0,
      addressConfirmed: false,
    );
    _persist();
  }

  void replaceForVenue(List<CartItem> items) {
    state = state.copyWith(
      items: items,
      addressConfirmed: false,
    );
    _persist();
  }

  void setAddressConfirmed(bool v) {
    state = state.copyWith(addressConfirmed: v);
    _persist();
  }

  void setPromo(String? code) {
    state = state.copyWith(
      promoCode: code,
      clearPromo: code == null,
      bonusPoints: 0,
    );
    _persist();
  }

  void setBonusPoints(int points) {
    state = state.copyWith(bonusPoints: points < 0 ? 0 : points);
    _persist();
  }

  void setComment(String? text) {
    state = state.copyWith(
      comment: text,
      clearComment: text == null,
    );
    _persist();
  }

  void setPickup(DateTime? dt) {
    state = state.copyWith(
      pickupAt: dt,
      clearPickup: dt == null,
    );
    _persist();
  }

  void setPayment(String label) {
    state = state.copyWith(paymentLabel: label);
    _persist();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  final initial = _bootStore?.cart ?? const CartState();
  return CartNotifier(initial);
});
