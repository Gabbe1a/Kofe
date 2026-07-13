import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/product_image.dart';

/// First launch is a purposeful welcome; subsequent launches stay frictionless.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleTransit();
  }

  void _scheduleTransit() {
    _timer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted || !ref.read(sessionProvider).hasSeenWelcome) return;
      _continueToApp();
    });
  }

  void _continueToApp() {
    final session = ref.read(sessionProvider);
    if (session.venueId != null && session.promoSeen) {
      context.go(session.isAuthed ? '/profile' : '/menu');
    } else if (session.venueId != null) {
      context.go('/promo');
    } else if (session.cityId != null) {
      context.go('/venue');
    } else {
      context.go('/city');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seen = ref.watch(sessionProvider.select((s) => s.hasSeenWelcome));
    return seen
        ? const _TransitSplash()
        : _WelcomeScreen(
            onStart: () {
              ref.read(sessionProvider.notifier).markWelcomeSeen();
              context.go('/city');
            },
          );
  }
}

class _TransitSplash extends StatelessWidget {
  const _TransitSplash();

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Scaffold(
      backgroundColor: palette.canvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(shape: BoxShape.circle, color: palette.ink),
              child: Icon(Icons.local_cafe_rounded, color: palette.canvas, size: 32),
            ),
            const SizedBox(height: 14),
            Text('КОФЕ', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF191919)),
          Positioned(
            top: 68,
            left: 0,
            right: 0,
            height: 390,
            child: Opacity(
              opacity: 0.92,
              child: ProductImage(
                asset: 'assets/images/products/iced_latte_bottle.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00191919), Color(0x66191919), Color(0xFF191919)],
                stops: [0, 0.46, 0.72],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'КОФЕ',
                    style: TextStyle(
                      color: Color(0xFFF4F4F4),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Кофе\nв твоём ритме',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: const Color(0xFFF4F4F4),
                      fontSize: 42,
                      height: 0.98,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Выбирайте точку, настраивайте напиток и забирайте заказ без очереди.',
                    style: TextStyle(color: Color(0xFFD0D0D0), height: 1.35, fontSize: 15),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF4F4F4),
                        foregroundColor: const Color(0xFF191919),
                      ),
                      onPressed: onStart,
                      child: const Text('Выбрать точку'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
