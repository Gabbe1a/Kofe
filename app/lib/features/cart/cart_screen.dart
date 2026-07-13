import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kofe_surface.dart';
import '../../core/widgets/product_image.dart';
import '../../data/api/kofe_api.dart';
import '../../data/models/models.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _openingPayment = false;
  String? _pendingOrderId;
  String? _pendingIdempotencyKey;
  String? _pendingCartFingerprint;

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(productsProvider(null));
    ref.listen<AsyncValue<List<Product>>>(
      productsProvider(null),
      (_, next) => next.whenData((catalog) => ref.read(cartProvider.notifier).syncWithCatalog(catalog)),
    );
    final cart = ref.watch(cartProvider);
    final session = ref.watch(sessionProvider);
    if (cart.isEmpty) {
      return _EmptyCart(isGuest: !session.isAuthed);
    }

    final canPay = session.isAuthed && cart.addressConfirmed;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 192),
              children: [
                _Header(onBack: () => context.go('/menu')),
                const SizedBox(height: 24),
                Text('Корзина', style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: 18),
                ...List.generate(cart.items.length, (index) => _CartLine(
                  item: cart.items[index],
                  onOpen: () => context.push('/cart/item/$index'),
                  onMinus: () => ref.read(cartProvider.notifier).setQty(index, cart.items[index].qty - 1),
                  onPlus: () => ref.read(cartProvider.notifier).setQty(index, cart.items[index].qty + 1),
                )),
                const SizedBox(height: 24),
                const Text('Добавить к заказу', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 12),
                catalogAsync.when(
                  loading: () => const SizedBox(height: 132, child: Center(child: CircularProgressIndicator())),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (products) => _SuggestionRail(products: _suggestions(products, cart.items)),
                ),
                const SizedBox(height: 24),
                const Text('Получение и оплата', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 12),
                KofeSurface(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(
                    children: [
                      _CheckoutRow(
                        icon: Icons.location_on_outlined,
                        title: session.venue?.shortName ?? 'Точка не выбрана',
                        subtitle: cart.addressConfirmed ? 'Точка подтверждена' : 'Подтвердите точку получения',
                        trailing: Switch.adaptive(
                          value: cart.addressConfirmed,
                          onChanged: ref.read(cartProvider.notifier).setAddressConfirmed,
                        ),
                        onTap: () => ref.read(cartProvider.notifier).setAddressConfirmed(!cart.addressConfirmed),
                      ),
                      _CheckoutRow(
                        icon: Icons.schedule_outlined,
                        title: 'Когда заберёте',
                        subtitle: cart.pickupAt == null ? 'Как можно скорее' : _timeLabel(cart.pickupAt!),
                        onTap: () => _pickupSheet(context, ref),
                      ),
                      _CheckoutRow(
                        icon: Icons.local_offer_outlined,
                        title: 'Промокод',
                        subtitle: cart.promoCode ?? 'Добавить промокод',
                        onTap: () => _promoSheet(context, ref),
                      ),
                      _CheckoutRow(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Комментарий',
                        subtitle: cart.comment?.isNotEmpty == true ? cart.comment! : 'Например, без трубочки',
                        onTap: () => _commentSheet(context, ref),
                      ),
                      _CheckoutRow(
                        icon: Icons.credit_card_outlined,
                        title: 'Оплата',
                        subtitle: 'Онлайн через ЮKassa',
                        onTap: () => context.push('/payment'),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _CheckoutBar(
                total: cart.total,
                enabled: canPay && !_openingPayment,
                label: _openingPayment
                    ? 'Открываем ЮKassa…'
                    : canPay
                    ? 'Оплатить через ЮKassa'
                    : (!session.isAuthed ? 'Войдите для оплаты' : 'Подтвердите точку'),
                onTap: canPay && !_openingPayment
                    ? () => _startYooKassaCheckout(context, cart, session)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _newIdempotencyKey() {
    final entropy = Random.secure().nextInt(1 << 32).toRadixString(16);
    return 'mobile-${DateTime.now().microsecondsSinceEpoch}-$entropy';
  }

  String _cartFingerprint(CartState cart, String venueId) {
    final lines = cart.items.map((item) {
      final modifiers = item.modifiers
          .map((modifier) => '${modifier.groupId}:${modifier.optionId}')
          .join(',');
      return '${item.product.id}:${item.size?.id ?? ''}:${item.qty}:$modifiers';
    }).join('|');
    return '$venueId/$lines/${cart.promoCode ?? ''}/${cart.comment ?? ''}/${cart.pickupAt?.toIso8601String() ?? ''}';
  }

  Future<void> _startYooKassaCheckout(
    BuildContext context,
    CartState cart,
    SessionState session,
  ) async {
    final venueId = session.venueId;
    if (venueId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала выберите точку получения.')));
      return;
    }
    final fingerprint = _cartFingerprint(cart, venueId);
    if (_pendingCartFingerprint != fingerprint) {
      _pendingOrderId = null;
      _pendingIdempotencyKey = null;
      _pendingCartFingerprint = null;
    }

    setState(() => _openingPayment = true);
    try {
      final api = ref.read(apiProvider);
      var orderId = _pendingOrderId;
      if (orderId == null) {
        final order = await api.createOrder(
          venueId: venueId,
          items: cart.items,
          idempotencyKey: _pendingIdempotencyKey ??= _newIdempotencyKey(),
          promoCode: cart.promoCode,
          comment: cart.comment,
          pickupAt: cart.pickupAt,
        );
        orderId = order.id;
        _pendingOrderId = order.id;
        _pendingCartFingerprint = fingerprint;
      }
      final payment = await api.startYooKassaPayment(orderId);
      // The sheet must already observe the app lifecycle before the external
      // browser takes over. This lets it reconcile the payment automatically
      // as soon as the customer returns from YooKassa.
      final paymentSheet = _paymentReturnSheet(context, orderId);
      await WidgetsBinding.instance.endOfFrame;
      final didOpen = await launchUrl(
        Uri.parse(payment.confirmationUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!didOpen) {
        if (mounted) Navigator.of(context).pop(false);
        await paymentSheet;
        throw StateError('Не удалось открыть защищённую страницу ЮKassa.');
      }
      if (!mounted) return;
      final paid = await paymentSheet;
      if (paid == true) {
        _pendingOrderId = null;
        _pendingIdempotencyKey = null;
        _pendingCartFingerprint = null;
        ref.read(cartProvider.notifier).clear();
        ref.invalidate(ordersProvider);
        if (mounted) context.go('/active-order/$orderId');
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось начать оплату: ${error.message}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _openingPayment = false);
    }
  }

  Future<bool?> _paymentReturnSheet(BuildContext context, String orderId) {
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _PaymentReturnSheet(orderId: orderId),
    );
  }

  static List<Product> _suggestions(List<Product> all, List<CartItem> cart) {
    final inCart = cart.map((item) => item.product.id).toSet();
    return all.where((product) => !inCart.contains(product.id)).take(4).toList();
  }

  static String _timeLabel(DateTime value) => 'Заберу в ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  static Future<void> _pickupSheet(BuildContext context, WidgetRef ref) async {
    var later = ref.read(cartProvider).pickupAt != null;
    TimeOfDay selected = TimeOfDay.now().replacing(minute: 0);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Время получения', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 14),
                _SheetChoice(title: 'Как можно скорее', selected: !later, onTap: () => setModalState(() => later = false)),
                const SizedBox(height: 8),
                _SheetChoice(
                  title: later ? 'Заберу в ${selected.format(context)}' : 'Выбрать время',
                  selected: later,
                  onTap: () async {
                    final time = await showTimePicker(context: context, initialTime: selected);
                    if (time != null) setModalState(() { selected = time; later = true; });
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final now = DateTime.now();
                      ref.read(cartProvider.notifier).setPickup(later
                          ? DateTime(now.year, now.month, now.day, selected.hour, selected.minute)
                          : null);
                      Navigator.pop(context);
                    },
                    child: const Text('Готово'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _promoSheet(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: ref.read(cartProvider).promoCode ?? '');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Промокод', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 14),
              TextField(controller: controller, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'Введите промокод')),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final code = controller.text.trim();
                    ref.read(cartProvider.notifier).setPromo(code.isEmpty ? null : code);
                    Navigator.pop(context);
                  },
                  child: const Text('Применить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  static Future<void> _commentSheet(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: ref.read(cartProvider).comment ?? '');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Комментарий', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 14),
              TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(hintText: 'Что важно учесть?')),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    ref.read(cartProvider.notifier).setComment(text.isEmpty ? null : text);
                    Navigator.pop(context);
                  },
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }
}

class _PaymentReturnSheet extends ConsumerStatefulWidget {
  const _PaymentReturnSheet({required this.orderId});

  final String orderId;

  @override
  ConsumerState<_PaymentReturnSheet> createState() => _PaymentReturnSheetState();
}

class _PaymentReturnSheetState extends ConsumerState<_PaymentReturnSheet>
    with WidgetsBindingObserver {
  static const _retryDelay = Duration(seconds: 2);
  static const _automaticChecksAfterReturn = 4;

  bool _checking = false;
  bool _leftForPayment = false;
  int _remainingAutomaticChecks = _automaticChecksAfterReturn;
  Timer? _retryTimer;
  String _message =
      'После оплаты вернитесь в приложение — статус обновится автоматически. '
      'Обычно это занимает несколько секунд.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _leftForPayment = true;
        break;
      case AppLifecycleState.resumed:
        if (_leftForPayment) {
          _leftForPayment = false;
          _remainingAutomaticChecks = _automaticChecksAfterReturn;
          _retryTimer?.cancel();
          unawaited(_runAutomaticChecks());
        }
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _runAutomaticChecks() async {
    final terminal = await _refreshPayment(automatic: true);
    if (!mounted || terminal) return;

    if (_remainingAutomaticChecks == 0) {
      setState(() {
        _message =
            'Платёж пока не подтверждён. Нажмите «Проверить сейчас» чуть позже — '
            'заказ не будет создан повторно.';
      });
      return;
    }

    _remainingAutomaticChecks -= 1;
    _retryTimer = Timer(_retryDelay, () => unawaited(_runAutomaticChecks()));
  }

  Future<bool> _refreshPayment({required bool automatic}) async {
    if (_checking) return false;

    setState(() {
      _checking = true;
      if (automatic) _message = 'Проверяем оплату в ЮKassa…';
    });
    try {
      final status = await ref.read(apiProvider).refreshYooKassaPayment(widget.orderId);
      if (!mounted) return true;

      if (status.isPaid) {
        _retryTimer?.cancel();
        Navigator.of(context).pop(true);
        return true;
      }

      final canceled = status.paymentStatus == 'canceled';
      setState(() {
        _message = canceled
            ? 'Платёж отменён в ЮKassa. Вы можете вернуться в корзину и попробовать снова.'
            : automatic
            ? 'Платёж ещё обрабатывается. Проверим статус автоматически ещё раз.'
            : 'ЮKassa пока не подтвердила платёж. Подождите несколько секунд и попробуйте снова.';
      });
      return canceled;
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _message = automatic
              ? 'Не удалось получить статус, попробуем ещё раз автоматически.'
              : 'Не удалось проверить статус: ${error.message}';
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.line,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                KofeRoundIcon(icon: Icons.open_in_new_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Оплата открыта в ЮKassa',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_message, style: TextStyle(color: palette.inkMuted, height: 1.4)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _checking
                    ? null
                    : () => unawaited(_refreshPayment(automatic: false)),
                icon: _checking
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(_checking ? 'Проверяем…' : 'Проверить сейчас'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Center(child: Text('Вернусь позже')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Row(
      children: [
        Material(
          color: palette.surface,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onBack,
            customBorder: const CircleBorder(),
            child: SizedBox(width: 42, height: 42, child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: palette.ink)),
          ),
        ),
        const Spacer(),
        Text('КОФЕ МАМА', style: TextStyle(color: palette.ink, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        const Spacer(),
        const SizedBox(width: 42),
      ],
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({required this.item, required this.onOpen, required this.onMinus, required this.onPlus});
  final CartItem item;
  final VoidCallback onOpen;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    final choices = [
      if (item.size != null) '${item.size!.label} · ${item.size!.ml} мл',
      ...item.modifiers.map((modifier) => modifier.optionTitle),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: palette.imageBackdrop, borderRadius: BorderRadius.circular(9)),
                  child: ProductImage(asset: item.product.imageAsset),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.product.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, height: 1.14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text(choices.isEmpty ? 'Без добавок' : choices.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.inkMuted, fontSize: 12)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text('${item.lineTotal.toStringAsFixed(0)} ₽', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          KofeQuantityControl(value: item.qty, onMinus: onMinus, onPlus: onPlus, compact: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionRail extends StatelessWidget {
  const _SuggestionRail({required this.products});
  final List<Product> products;
  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    final palette = context.kofePalette;
    return SizedBox(
      height: 158,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final product = products[index];
          return SizedBox(
            width: 132,
            child: Material(
              color: palette.surface,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => context.push('/product/${product.id}'),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(color: palette.imageBackdrop, borderRadius: BorderRadius.circular(9)),
                          child: ProductImage(asset: product.imageAsset),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('+ ${product.price.toStringAsFixed(0)} ₽', style: TextStyle(color: palette.inkMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CheckoutRow extends StatelessWidget {
  const _CheckoutRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.showDivider = true,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                KofeRoundIcon(icon: icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.inkMuted, fontSize: 12)),
                    ],
                  ),
                ),
                trailing ?? Icon(Icons.arrow_forward_ios_rounded, size: 14, color: palette.inkMuted),
              ],
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, indent: 52, color: palette.line),
      ],
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.total, required this.enabled, required this.label, required this.onTap});
  final double total;
  final bool enabled;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Material(
      color: palette.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('Итого', style: TextStyle(color: palette.inkMuted, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${total.toStringAsFixed(0)} ₽', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onTap, child: Text(label))),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCart extends ConsumerWidget {
  const _EmptyCart({required this.isGuest});
  final bool isGuest;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.kofePalette;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(onBack: () => context.go('/menu')),
              const Spacer(),
              Center(
                child: Container(
                  width: 126,
                  height: 126,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: palette.imageBackdrop),
                  child: Icon(Icons.shopping_bag_outlined, color: palette.ink, size: 54),
                ),
              ),
              const SizedBox(height: 24),
              Center(child: Text('Пока пусто', style: Theme.of(context).textTheme.headlineLarge)),
              const SizedBox(height: 8),
              Center(child: Text('Добавьте напиток или десерт из меню.', textAlign: TextAlign.center, style: TextStyle(color: palette.inkMuted))),
              if (isGuest) ...[
                const SizedBox(height: 20),
                KofeSurface(
                  color: palette.surfaceMuted,
                  borderColor: palette.surfaceMuted,
                  child: const Text('Для оформления заказа понадобится вход в профиль.'),
                ),
              ],
              const Spacer(),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => context.go('/menu'), child: const Text('В меню'))),
              if (isGuest) TextButton(onPressed: () => context.push('/auth'), child: const Center(child: Text('Войти в профиль'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetChoice extends StatelessWidget {
  const _SheetChoice({required this.title, required this.selected, required this.onTap});
  final String title;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Material(
      color: selected ? palette.surfaceMuted : palette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))), Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: palette.ink)]),
        ),
      ),
    );
  }
}
