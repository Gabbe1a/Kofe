/// Customer-facing labels and progress for the technical status codes returned
/// by the order API. The backend deliberately keeps codes stable for staff and
/// integrations; only the mobile presentation is localized here.
extension OrderStatusPresentation on String {
  String get _normalized => trim().toLowerCase().replaceAll('-', '_');

  String get localized {
    switch (_normalized) {
      case 'pending_payment':
      case 'awaiting_payment':
      case 'payment_pending':
        return 'Ожидает оплаты';
      case 'payment_failed':
      case 'failed':
        return 'Оплата не прошла';
      case 'confirmed':
        return 'Подтверждён';
      case 'preparing':
        return 'Готовится';
      case 'ready':
        return 'Готов';
      case 'issued':
        return 'Выдан';
      case 'completed':
      case 'done':
      case 'fulfilled':
      case 'выполнен':
        return 'Выполнен';
      case 'cancelled':
      case 'canceled':
      case 'отменён':
      case 'отменен':
        return 'Отменён';
      case 'refunded':
        return 'Возврат оформлен';
      case 'new':
        return 'Новый';
      default:
        // Never expose a new technical code to a customer before a label is
        // added above. The raw value remains available to staff in the admin.
        return 'Обрабатывается';
    }
  }

  bool get isCancelled => switch (_normalized) {
    'cancelled' || 'canceled' || 'отменён' || 'отменен' || 'refunded' => true,
    _ => false,
  };

  int? get timelineStep => switch (_normalized) {
    'confirmed' => 0,
    'preparing' => 1,
    'ready' => 2,
    'issued' || 'completed' || 'done' || 'fulfilled' || 'выполнен' => 3,
    _ => null,
  };

  String get detailHeadline => switch (_normalized) {
    'pending_payment' || 'awaiting_payment' || 'payment_pending' => 'Ожидаем оплату',
    'payment_failed' || 'failed' => 'Оплата не прошла',
    'confirmed' => 'Заказ подтверждён',
    'preparing' => 'Готовим ваш заказ',
    'ready' => 'Заказ готов — можно забирать',
    'issued' || 'completed' || 'done' || 'fulfilled' || 'выполнен' => 'Заказ выдан',
    'cancelled' || 'canceled' || 'отменён' || 'отменен' => 'Заказ отменён',
    'refunded' => 'Возврат оформлен',
    _ => 'Статус заказа обновляется',
  };
}
