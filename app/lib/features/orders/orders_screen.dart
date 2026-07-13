import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/data_providers.dart';
import '../../core/order_status.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kofe_surface.dart';
import '../../core/widgets/product_image.dart';
import '../../data/models/models.dart';
import '../venues/venue_map.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.kofePalette;
    final dateFmt = DateFormat('dd.MM.yyyy HH:mm');
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('История заказов'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.canPop() ? context.pop() : context.go('/menu'),
        ),
      ),
      body: SafeArea(
        minimum: KofeLayout.pageSafeArea,
        child: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Ошибка загрузки заказов\n$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.inkMuted),
            ),
          ),
          data: (orders) {
            final historyOrders = orders
                .where((order) => order.status.isHistoryOrder)
                .toList();
            if (historyOrders.isEmpty) {
              return Center(
                child: Text(
                  'История пока пуста',
                  style: TextStyle(color: palette.inkMuted),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: historyOrders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final order = historyOrders[i];
                final cancelled = order.status.isCancelled;
                final summary = order.summaryLine ?? 'Заказ';

                return KofeSurface(
                  padding: const EdgeInsets.all(16),
                  onTap: () => context.push('/orders/${order.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Заказ № ${order.displayNumber}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cancelled
                                  ? AppColors.danger.withValues(alpha: 0.12)
                                  : palette.surfaceMuted,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cancelled
                                      ? Icons.close_rounded
                                      : Icons.check_rounded,
                                  size: 14,
                                  color: cancelled
                                      ? AppColors.danger
                                      : palette.ink,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  order.status.localized,
                                  style: TextStyle(
                                    color: cancelled
                                        ? AppColors.danger
                                        : palette.ink,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        dateFmt.format(order.createdAt),
                        style: TextStyle(
                          color: palette.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        color: palette.line,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              summary,
                              style: TextStyle(
                                color: palette.inkMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            '${order.total.toStringAsFixed(0)} ₽',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      if (!cancelled) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: palette.surfaceMuted,
                              foregroundColor: palette.ink,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              try {
                                final detailed = await ref
                                    .read(apiProvider)
                                    .fetchOrder(order.id);
                                if (context.mounted) {
                                  await _repeatOrder(context, ref, detailed);
                                }
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Не удалось загрузить состав заказа: $error',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(
                              'Повторить заказ',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

Future<void> _repeatOrder(
  BuildContext context,
  WidgetRef ref,
  OrderSummary order,
) async {
  if (order.items.isEmpty || order.venueId == null) {
    await _showRepeatProblem(
      context,
      'У этого старого заказа не сохранился полный состав. '
      'Его нельзя повторить без риска выбрать другой размер или добавки.',
    );
    return;
  }

  final catalog = await ref
      .read(apiProvider)
      .fetchProducts(venueId: order.venueId);
  final productsById = {for (final product in catalog) product.id: product};
  final restored = <CartItem>[];
  final problems = <String>[];

  for (final historical in order.items) {
    final product = historical.productId == null
        ? null
        : productsById[historical.productId];
    if (product == null) {
      problems.add('«${historical.title}» сейчас нет в меню этой точки');
      continue;
    }

    ProductSize? size;
    if (historical.sizeId != null) {
      for (final candidate in product.sizes) {
        if (candidate.id == historical.sizeId) {
          size = candidate;
          break;
        }
      }
      if (size == null) {
        problems.add(
          'Для «${historical.title}» больше нет размера '
          '«${historical.sizeLabel ?? historical.sizeId}»',
        );
        continue;
      }
    } else if (product.sizes.isNotEmpty) {
      problems.add(
        'В старом заказе не сохранился размер «${historical.title}»',
      );
      continue;
    }

    final selectedModifiers = <SelectedModifier>[];
    var modifiersValid = true;
    for (final historicalModifier in historical.modifiers) {
      ModifierGroup? group;
      for (final candidate in product.modifierGroups) {
        if (candidate.id == historicalModifier.groupId) {
          group = candidate;
          break;
        }
      }
      ModifierOption? option;
      if (group != null) {
        for (final candidate in group.options) {
          if (candidate.id == historicalModifier.optionId) {
            option = candidate;
            break;
          }
        }
      }
      if (group == null || option == null) {
        problems.add(
          'Для «${historical.title}» недоступна добавка '
          '«${historicalModifier.optionTitle}»',
        );
        modifiersValid = false;
        break;
      }
      selectedModifiers.add(
        SelectedModifier(
          groupId: group.id,
          groupTitle: group.title,
          optionId: option.id,
          optionTitle: option.title,
          priceDelta: option.priceDelta,
        ),
      );
    }
    if (!modifiersValid) continue;

    final selectedGroupIds = selectedModifiers.map((item) => item.groupId).toSet();
    final missingRequired = product.modifierGroups
        .where((group) => group.required && !selectedGroupIds.contains(group.id))
        .toList();
    if (missingRequired.isNotEmpty) {
      problems.add(
        'Для «${historical.title}» нужно заново выбрать: '
        '${missingRequired.map((group) => group.title).join(', ')}',
      );
      continue;
    }

    restored.add(
      CartItem(
        product: product,
        qty: historical.qty,
        size: size,
        modifiers: selectedModifiers,
      ),
    );
  }

  if (problems.isNotEmpty || restored.length != order.items.length) {
    await _showRepeatProblem(
      context,
      'Не можем точно повторить заказ:\n\n${problems.join('\n')}',
    );
    return;
  }

  final cart = ref.read(cartProvider);
  if (!cart.isEmpty) {
    final replace = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Заменить текущую корзину?'),
        content: const Text(
          'Чтобы повторить заказ, текущие позиции будут заменены его полным составом.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Заменить'),
          ),
        ],
      ),
    );
    if (replace != true || !context.mounted) return;
  }

  final venues = await ref.read(venuesProvider(null).future);
  Venue? orderVenue;
  for (final venue in venues) {
    if (venue.id == order.venueId) {
      orderVenue = venue;
      break;
    }
  }
  if (orderVenue == null) {
    if (context.mounted) {
      await _showRepeatProblem(context, 'Точка этого заказа сейчас недоступна.');
    }
    return;
  }

  final cities = await ref.read(citiesProvider.future);
  for (final city in cities) {
    if (city.id == orderVenue.cityId) {
      ref.read(sessionProvider.notifier).setCity(city);
      break;
    }
  }
  ref.read(sessionProvider.notifier).setVenue(orderVenue);
  ref.read(cartProvider.notifier).replaceForVenue(restored);
  ref.invalidate(productsProvider(null));
  if (context.mounted) context.go('/cart');
}

Future<void> _showRepeatProblem(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Заказ нужно проверить'),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Понятно'),
        ),
      ],
    ),
  );
}

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.activeMode = false,
  });

  final String orderId;
  final bool activeMode;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen>
    with WidgetsBindingObserver {
  static const _refreshInterval = Duration(seconds: 5);
  Timer? _refreshTimer;
  bool _historyRedirectScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshOrder());
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _refreshOrder());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshOrder();
  }

  void _refreshOrder() => ref.invalidate(orderProvider(widget.orderId));

  void _openHistoryWhenFinished() {
    if (_historyRedirectScheduled) return;
    _historyRedirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(ordersProvider);
      context.go('/orders');
    });
  }

  void _closeOrder() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/menu');
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderProvider(widget.orderId));
    final productsAsync = ref.watch(productsProvider(null));
    final venuesAsync = ref.watch(venuesProvider(null));

    return orderAsync.when(
      loading: () => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: _closeOrder,
          ),
        ),
        body: Center(
          child: Text(
            'Ошибка заказа\n$e',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkMuted),
          ),
        ),
      ),
      data: (order) {
        final palette = context.kofePalette;
        final products = productsAsync.valueOrNull ?? const <Product>[];
        final productsById = {for (final item in products) item.id: item};
        Product? product;
        final line = order.summaryLine?.toLowerCase();
        if (line != null && line.isNotEmpty) {
          for (final p in products) {
            if (p.title.toLowerCase().contains(line) ||
                line.contains(p.title.toLowerCase())) {
              product = p;
              break;
            }
          }
        }
        product ??= products.isNotEmpty ? products.first : null;

        Venue? venue;
        final allVenues = venuesAsync.valueOrNull ?? const <Venue>[];
        if (order.venueId != null) {
          for (final v in allVenues) {
            if (v.id == order.venueId) {
              venue = v;
              break;
            }
          }
        }
        venue ??= allVenues.isNotEmpty ? allVenues.first : null;
        final venueName = venue?.shortName ?? 'Кофейня';
        final orderStatus = order.status;
        final isCancelled = orderStatus.isCancelled;
        final activeTimelineStep = orderStatus.timelineStep;
        if (widget.activeMode && orderStatus.isHistoryOrder) {
          _openHistoryWhenFinished();
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              widget.activeMode
                  ? 'Активный заказ № ${order.displayNumber}'
                  : 'Заказ № ${order.displayNumber}',
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: _closeOrder,
            ),
          ),
          body: SafeArea(
            minimum: KofeLayout.pageSafeArea,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                KofeSurface(
                  color: AppColors.creamWarm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        orderStatus.detailHeadline,
                        style: TextStyle(
                          color: isCancelled ? AppColors.danger : palette.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCancelled
                            ? 'Этот заказ не будет приготовлен'
                            : 'Самовывоз',
                        style: TextStyle(
                          color: palette.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                      if (activeTimelineStep != null) ...[
                        const SizedBox(height: 18),
                        _OrderProgressTracker(activeStep: activeTimelineStep),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                KofeSurface(
                  color: AppColors.creamWarm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const KofeRoundIcon(icon: Icons.location_on_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Адрес кофейни',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  venueName,
                        style: TextStyle(
                          color: palette.inkMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (venue != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: VenueMap(
                            venues: [venue],
                            selectedId: venue.id,
                            height: 140,
                            borderRadius: 0,
                            interactive: false,
                          ),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            color: palette.surfaceMuted,
                            alignment: Alignment.center,
                            child: const Text(
                              'Точка заказа недоступна',
                              style: TextStyle(
                                color: palette.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                KofeSurface(
                  color: AppColors.creamWarm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Состав заказа',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 14),
                      if (order.items.isNotEmpty)
                        for (var index = 0;
                            index < order.items.length;
                            index++) ...[
                          _OrderItemRow(
                            item: order.items[index],
                            product: productsById[order.items[index].productId],
                          ),
                          if (index != order.items.length - 1)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(
                                height: 1,
                        color: palette.line,
                              ),
                            ),
                        ]
                      else
                        _OrderItemRow(
                          item: OrderItemSummary(
                            productId: product?.id,
                            title: order.summaryLine ?? product?.title ?? 'Заказ',
                            qty: 1,
                            unitPrice: order.total,
                            lineTotal: order.total,
                          ),
                          product: product,
                        ),
                      const SizedBox(height: 14),
                      Divider(color: palette.line),
                      const SizedBox(height: 10),
                      if (order.bonusSpent > 0) ...[
                        Row(
                          children: [
                            const Text('Стоимость заказа'),
                            const Spacer(),
                            Text('${order.total.toStringAsFixed(0)} ₽'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Оплачено бонусами'),
                            const Spacer(),
                            Text(
                              '−${order.bonusSpent} ₽',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Text(
                            order.bonusSpent > 0 ? 'Оплачено рублями' : 'Итого',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Text(
                            '${(order.paymentTotal ?? order.total).toStringAsFixed(0)} ₽',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      if (order.bonusEarned > 0) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text('Начислено за заказ'),
                            const Spacer(),
                            Text(
                              '+${order.bonusEarned} бонусов',
                              style: const TextStyle(
                                color: palette.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (widget.activeMode)
                  ElevatedButton.icon(
                    onPressed: () => context.go('/menu'),
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('Вернуться в меню'),
                  )
                else if (!isCancelled)
                  ElevatedButton.icon(
                    onPressed: () => _repeatOrder(context, ref, order),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Повторить заказ'),
                  ),
                if (!widget.activeMode) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => _openReview(context),
                      child: Text(
                        'Оставить отзыв',
                        style: TextStyle(
                          color: palette.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openReview(BuildContext context) async {
    var food = 5;
    var service = 5;
    final comment = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Как вам заказ?',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Оценка помогает нам готовить ещё вкуснее',
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 16),
                  KofeSurface(
                    color: AppColors.creamWarm,
                    borderColor: AppColors.ink.withValues(alpha: 0.06),
                    child: Column(
                      children: [
                        const Text(
                          'Еда и напитки',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            5,
                            (i) => IconButton(
                              onPressed: () => setModal(() => food = i + 1),
                              icon: Icon(
                                i < food
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: AppColors.forest,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Обслуживание',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            5,
                            (i) => IconButton(
                              onPressed: () => setModal(() => service = i + 1),
                              icon: Icon(
                                i < service
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: AppColors.forest,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: comment,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Комментарий (необязательно)',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Спасибо за отзыв!')),
                      );
                    },
                    child: const Text('Отправить'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Оценить позднее',
                      style: TextStyle(color: AppColors.inkMuted),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    comment.dispose();
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({required this.item, this.product});

  final OrderItemSummary item;
  final Product? product;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    final details = <String>[
      if (item.sizeLabel != null)
        '${item.sizeLabel}${item.sizeMl == null ? '' : ' · ${item.sizeMl} мл'}',
      ...item.modifiers.map((modifier) => modifier.optionTitle),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: product != null
              ? ProductImage(asset: product!.imageAsset)
              : Icon(
                  Icons.local_cafe_outlined,
                  color: palette.ink,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                [
                  '× ${item.qty}',
                  if (details.isNotEmpty) details.join(', '),
                ].join(' · '),
                              style: TextStyle(
                                color: palette.inkMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${item.lineTotal.toStringAsFixed(0)} ₽',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _OrderProgressTracker extends StatelessWidget {
  const _OrderProgressTracker({required this.activeStep});

  final int activeStep;

  static const _steps = [
    ('Подтверждён', 'Кофейня приняла заказ', Icons.receipt_long_outlined),
    ('Готовится', 'Бариста готовит напитки', Icons.coffee_maker_outlined),
    ('Приготовлен', 'Можно забрать на точке', Icons.local_cafe_outlined),
    ('Выдан', 'Заказ передан вам', Icons.storefront_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Column(
      children: [
        for (var index = 0; index < _steps.length; index++) ...[
          _OrderProgressStep(
            title: _steps[index].$1,
            subtitle: _steps[index].$2,
            icon: _steps[index].$3,
            isCompleted: index < activeStep,
            isCurrent: index == activeStep,
          ),
          if (index < _steps.length - 1)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 2,
                height: 14,
                margin: const EdgeInsets.only(left: 20),
                color: index < activeStep ? palette.action : palette.line,
              ),
            ),
        ],
      ],
    );
  }
}

class _OrderProgressStep extends StatelessWidget {
  const _OrderProgressStep({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isCompleted,
    required this.isCurrent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isCompleted;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    final circleColor = isCompleted
        ? palette.action
        : isCurrent
        ? palette.accent
        : palette.surface;
    final circleIconColor = isCompleted
        ? palette.onAction
        : isCurrent
        ? palette.onAccent
        : palette.inkMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: circleColor,
            border: Border.all(
              color: isCurrent
                  ? palette.action
                  : isCompleted
                  ? palette.action
                  : palette.line,
              width: isCurrent ? 2.5 : 1.25,
            ),
          ),
          child: Icon(
            isCompleted ? Icons.check_rounded : icon,
            size: 20,
            color: circleIconColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isCurrent
                  ? palette.accent.withValues(alpha: 0.32)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrent ? palette.accent : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isCurrent || isCompleted
                              ? palette.ink
                              : palette.inkMuted,
                          fontSize: isCurrent ? 16 : 15,
                          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: palette.inkMuted,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: palette.action,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Сейчас',
                      style: TextStyle(
                        color: palette.onAction,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
