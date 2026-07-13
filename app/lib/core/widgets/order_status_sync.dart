import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_providers.dart';
import '../providers.dart';

/// Keeps customer order statuses fresh while the app is open.
///
/// Webhooks update the server instantly; the app reconciles its read model on
/// resume and every few seconds instead of relying on stale in-memory data.
class OrderStatusSync extends ConsumerStatefulWidget {
  const OrderStatusSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OrderStatusSync> createState() => _OrderStatusSyncState();
}

class _OrderStatusSyncState extends ConsumerState<OrderStatusSync>
    with WidgetsBindingObserver {
  static const _refreshInterval = Duration(seconds: 10);
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _refreshOrders());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshOrders();
  }

  void _refreshOrders() {
    if (!ref.read(sessionProvider).isAuthed) return;
    ref.invalidate(ordersProvider);
    ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
