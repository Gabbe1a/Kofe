import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kofe_surface.dart';
import '../../data/models/models.dart';

class PromoScreen extends ConsumerStatefulWidget {
  const PromoScreen({super.key});
  @override
  ConsumerState<PromoScreen> createState() => _PromoScreenState();
}

class _PromoScreenState extends ConsumerState<PromoScreen> {
  final _controller = PageController();
  int _page = 0;
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  void _close() { ref.read(sessionProvider.notifier).markPromoSeen(); context.go('/menu'); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ref.watch(promoSlidesProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Не удалось загрузить акции\n$error', textAlign: TextAlign.center)),
        data: (slides) => _PromoPager(slides: slides, controller: _controller, page: _page, onPage: (index) => setState(() => _page = index), onClose: _close),
      ),
    );
  }
}

class _PromoPager extends StatelessWidget {
  const _PromoPager({required this.slides, required this.controller, required this.page, required this.onPage, required this.onClose});
  final List<PromoSlide> slides;
  final PageController controller;
  final int page;
  final ValueChanged<int> onPage;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    if (slides.isEmpty) return Center(child: ElevatedButton(onPressed: onClose, child: const Text('В меню')));
    return SafeArea(
      child: Column(children: [
        Align(alignment: Alignment.topRight, child: IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded))),
        Expanded(
          child: PageView.builder(
            controller: controller,
            itemCount: slides.length,
            onPageChanged: onPage,
            itemBuilder: (_, index) {
              final slide = slides[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    flex: 6,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(width: double.infinity, child: slide.imageAsset == null ? _PromoFallback() : _PromoImage(source: slide.imageAsset!)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(slide.title, style: Theme.of(context).textTheme.displayLarge),
                  const SizedBox(height: 12),
                  Text(slide.body, style: TextStyle(color: palette.inkMuted, height: 1.4)),
                  if (slide.ctaUrl != null) TextButton(onPressed: () => launchUrl(Uri.parse(slide.ctaUrl!)), child: const Text('Подробнее')),
                  const Spacer(flex: 2),
                ]),
              );
            },
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(slides.length, (index) => AnimatedContainer(duration: const Duration(milliseconds: 180), width: index == page ? 18 : 7, height: 7, margin: const EdgeInsets.all(4), decoration: BoxDecoration(color: index == page ? palette.ink : palette.line, borderRadius: BorderRadius.circular(99))))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: page == slides.length - 1 ? onClose : () => controller.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic), child: Text(page == slides.length - 1 ? 'В меню' : 'Далее'))),
        ),
      ]),
    );
  }
}

class _PromoFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return ColoredBox(color: palette.imageBackdrop, child: Center(child: Icon(Icons.local_cafe_rounded, color: palette.ink, size: 60)));
  }
}

class _PromoImage extends StatelessWidget {
  const _PromoImage({required this.source});
  final String source;
  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(source);
    final network = uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
    return network ? Image.network(source, fit: BoxFit.cover, errorBuilder: (_, _, _) => _PromoFallback()) : Image.asset(source, fit: BoxFit.cover, errorBuilder: (_, _, _) => _PromoFallback());
  }
}
