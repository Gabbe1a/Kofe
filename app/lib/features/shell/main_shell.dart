import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data_providers.dart';
import '../../core/order_status.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final isAuthed = ref.watch(sessionProvider.select((session) => session.isAuthed));
    final orders = ref.watch(ordersProvider).valueOrNull ?? const <OrderSummary>[];
    final activeOrder = isAuthed ? _firstActiveOrder(orders) : null;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (activeOrder != null)
            _ActiveOrderBar(
              order: activeOrder,
              onTap: () => context.push('/active-order/${activeOrder.id}'),
            ),
          KofeBottomBar(
            currentIndex: navigationShell.currentIndex,
            cartBadge: cart.totalQty,
            onTap: (i) => navigationShell.goBranch(
              i,
              initialLocation: i == navigationShell.currentIndex,
            ),
          ),
        ],
      ),
    );
  }

  static OrderSummary? _firstActiveOrder(List<OrderSummary> orders) {
    for (final order in orders) {
      if (order.status.isActiveOrder) return order;
    }
    return null;
  }
}

class _ActiveOrderBar extends StatelessWidget {
  const _ActiveOrderBar({required this.order, required this.onTap});

  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    final shortId = order.id.length > 8 ? order.id.substring(0, 8) : order.id;
    final step = order.status.timelineStep ?? 0;
    return ColoredBox(
      color: palette.canvas,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Material(
          color: palette.surface,
          elevation: 5,
          shadowColor: Colors.black.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            button: true,
            label: 'Открыть активный заказ. ${order.status.localized}',
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 11),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        order.status == 'ready'
                            ? Icons.notifications_active_outlined
                            : Icons.local_cafe_outlined,
                        color: palette.onAccent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'АКТИВНЫЙ ЗАКАЗ · №$shortId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.inkMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            order.status.detailHeadline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 7),
                          _MiniOrderProgress(activeStep: step),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: palette.ink,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniOrderProgress extends StatelessWidget {
  const _MiniOrderProgress({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Row(
      children: [
        for (var index = 0; index < 4; index++) ...[
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: index <= activeStep ? palette.action : palette.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          if (index < 3) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class KofeBottomBar extends StatelessWidget {
  const KofeBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.cartBadge = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int cartBadge;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: palette.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.line)),
        ),
        padding: EdgeInsets.only(top: 10, bottom: bottomPad + 7),
        child: Row(
          children: [
            _item(context, 0, Icons.person_outline_rounded, 'Профиль'),
            _item(context, 1, Icons.storefront_outlined, 'Меню'),
            _item(
              context,
              2,
              Icons.shopping_bag_outlined,
              'Корзина',
              badge: cartBadge,
            ),
            _item(context, 3, Icons.location_on_outlined, 'Точки'),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    int index,
    IconData icon,
    String label, {
    int badge = 0,
  }) {
    final palette = context.kofePalette;
    final active = index == currentIndex;
    final color = active ? palette.ink : palette.inkMuted;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 23),
                if (badge > 0)
                  Positioned(
                    top: -5,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
