import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/kofe_surface.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Scaffold(
      backgroundColor: palette.canvas,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: palette.line, borderRadius: BorderRadius.circular(99)))),
                  const SizedBox(height: 18),
                  Row(children: [Expanded(child: Text('Способ оплаты', style: Theme.of(context).textTheme.headlineMedium)), IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded))]),
                  const SizedBox(height: 16),
                  KofeSurface(
                    padding: const EdgeInsets.all(16),
                    color: palette.surfaceMuted,
                    borderColor: palette.line,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KofeRoundIcon(icon: Icons.shield_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Онлайн через ЮKassa', style: TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 5),
                              Text('После нажатия «Перейти к оплате» откроется защищённая страница ЮKassa. Данные карты в приложении не сохраняются.', style: TextStyle(color: palette.inkMuted, fontSize: 13, height: 1.35)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Понятно'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
