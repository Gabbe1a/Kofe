import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/data_providers.dart';
import '../../core/order_status.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kofe_surface.dart';
import '../../core/widgets/product_image.dart';
import '../../data/models/models.dart';
import '../venues/venue_map.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat('dd.MM.yyyy HH:mm');
    final ordersAsync = ref.watch(ordersProvider);
    final productsAsync = ref.watch(productsProvider(null));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('История заказов'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
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
              style: const TextStyle(color: AppColors.inkMuted),
            ),
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return const Center(
                child: Text(
                  'Заказов пока нет',
                  style: TextStyle(color: AppColors.inkMuted),
                ),
              );
            }
            final firstProductId = productsAsync.valueOrNull?.isNotEmpty == true
                ? productsAsync.valueOrNull!.first.id
                : null;
            return ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final order = orders[i];
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
                              'Заказ № ${order.id}',
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
                                  : AppColors.sageSoft,
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
                                      : AppColors.forest,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  order.status.localized,
                                  style: TextStyle(
                                    color: cancelled
                                        ? AppColors.danger
                                        : AppColors.forest,
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
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        color: AppColors.ink.withValues(alpha: 0.08),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              summary,
                              style: const TextStyle(
                                color: AppColors.inkMuted,
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
                      if (!cancelled && firstProductId != null) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.creamWarm,
                              foregroundColor: AppColors.ink,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () =>
                                context.push('/product/$firstProductId'),
                            child: const Text(
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

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen>
    with WidgetsBindingObserver {
  static const _refreshInterval = Duration(seconds: 10);
  Timer? _refreshTimer;

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
            onPressed: () => context.pop(),
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
        final products = productsAsync.valueOrNull ?? const <Product>[];
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

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text('Заказ № ${order.id}'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => context.pop(),
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
                          color: isCancelled ? AppColors.danger : AppColors.forest,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCancelled
                            ? 'Этот заказ не будет приготовлен'
                            : 'Самовывоз',
                        style: const TextStyle(
                          color: AppColors.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                      if (activeTimelineStep != null) ...[
                        const SizedBox(height: 18),
                        _OrderTimeline(activeStep: activeTimelineStep),
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
                                  style: const TextStyle(
                                    color: AppColors.inkMuted,
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
                            color: AppColors.sageSoft.withValues(alpha: 0.55),
                            alignment: Alignment.center,
                            child: const Text(
                              'Точка заказа недоступна',
                              style: TextStyle(
                                color: AppColors.forest,
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
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: product != null
                                ? ProductImage(asset: product.imageAsset)
                                : const Icon(
                                    Icons.local_cafe_outlined,
                                    color: AppColors.forest,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.summaryLine ??
                                      product?.title ??
                                      'Заказ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (venue != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    venue.fullAddress,
                                    style: const TextStyle(
                                      color: AppColors.inkMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '${order.total.toStringAsFixed(0)} ₽',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(color: AppColors.ink.withValues(alpha: 0.08)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text(
                            'Итого',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Text(
                            '${order.total.toStringAsFixed(0)} ₽',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (product != null)
                  ElevatedButton.icon(
                    onPressed: () => context.push('/product/${product!.id}'),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Повторить заказ'),
                  ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => _openReview(context),
                    child: const Text(
                      'Оставить отзыв',
                      style: TextStyle(
                        color: AppColors.forest,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
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

class _OrderTimeline extends StatelessWidget {
  const _OrderTimeline({required this.activeStep});

  final int activeStep;

  static const _steps = [
    ('Подтвержден', Icons.check_rounded),
    ('Готовится', Icons.coffee_maker_outlined),
    ('Приготовлен', Icons.local_cafe_outlined),
    ('Выдан', Icons.storefront_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final after = i ~/ 2;
          final done = after < activeStep;
          return Expanded(
            child: Container(
              height: 2,
              color: done
                  ? AppColors.forest
                  : AppColors.ink.withValues(alpha: 0.12),
            ),
          );
        }
        final step = i ~/ 2;
        final done = step <= activeStep;
        final active = step == activeStep;
        return Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.forest : AppColors.surface,
                border: Border.all(
                  color: done
                      ? AppColors.forest
                      : AppColors.ink.withValues(alpha: 0.2),
                  width: active ? 3 : 1.5,
                ),
              ),
              child: Icon(
                _steps[step].$2,
                size: 14,
                color: done ? AppColors.cream : AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 64,
              child: Text(
                _steps[step].$1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: done ? AppColors.forest : AppColors.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
