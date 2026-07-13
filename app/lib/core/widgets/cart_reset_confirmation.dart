import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Confirms a venue/city change before cart data is discarded.
Future<bool> confirmCartReset(BuildContext context, {required bool hasItems}) async {
  if (!hasItems) return true;
  final approved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Очистить корзину?'),
      content: const Text(
        'При смене города или кофейни цены и наличие могут отличаться. '
        'Текущие товары будут удалены из корзины.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Оставить'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.forest),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Очистить'),
        ),
      ],
    ),
  );
  return approved ?? false;
}
