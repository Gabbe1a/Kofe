import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kofe_surface.dart';
import '../../core/widgets/product_image.dart';
import '../../data/models/models.dart';

/// Source 1 catalogue composition: venue, search, chips, 2-column product grid
/// and a floating cart summary. Data is still scoped by the selected venue.
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final _searchController = TextEditingController();
  String? _categoryId;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    final session = ref.watch(sessionProvider);
    final cart = ref.watch(cartProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider(_categoryId));

    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 132),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _TopBar(
                        venueLabel: session.venue?.shortName ?? 'Выбрать точку',
                        onVenue: () => context.go('/venues'),
                        onProfile: () => context.go('/profile'),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Меню',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Поиск напитков и десертов',
                          prefixIcon: Icon(Icons.search_rounded, color: palette.inkMuted),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: Icon(Icons.close_rounded, color: palette.inkMuted),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      categoriesAsync.when(
                        loading: () => const SizedBox(height: 38),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (categories) => _CategoryRail(
                          categories: categories,
                          selectedId: _categoryId,
                          onSelect: (id) => setState(() => _categoryId = id),
                        ),
                      ),
                      const SizedBox(height: 24),
                      productsAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (error, _) => _MenuMessage(
                          icon: Icons.wifi_off_rounded,
                          title: 'Не удалось загрузить меню',
                          message: '$error',
                        ),
                        data: (products) {
                          final visible = products.where(_matchesQuery).toList();
                          if (visible.isEmpty) {
                            return const _MenuMessage(
                              icon: Icons.search_off_rounded,
                              title: 'Ничего не нашли',
                              message: 'Попробуйте изменить запрос или категорию.',
                            );
                          }
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.655,
                            ),
                            itemCount: visible.length,
                            itemBuilder: (_, index) => _ProductTile(product: visible[index]),
                          );
                        },
                      ),
                    ]),
                  ),
                ),
              ],
            ),
            if (!cart.isEmpty)
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: _FloatingCart(
                  quantity: cart.totalQty,
                  total: cart.total,
                  onTap: () => context.go('/cart'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _matchesQuery(Product product) {
    if (_query.isEmpty) return true;
    return product.title.toLowerCase().contains(_query) ||
        product.description.toLowerCase().contains(_query);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.venueLabel, required this.onVenue, required this.onProfile});

  final String venueLabel;
  final VoidCallback onVenue;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onVenue,
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_outlined, size: 19, color: palette.ink),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      venueLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.ink, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: palette.inkMuted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: palette.surface,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onProfile,
            customBorder: const CircleBorder(),
            child: SizedBox(
              height: 42,
              width: 42,
              child: Icon(Icons.person_outline_rounded, color: palette.ink),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.categories, required this.selectedId, required this.onSelect});

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final id = index == 0 ? null : categories[index - 1].id;
          final label = index == 0 ? 'Все' : categories[index - 1].title;
          final active = selectedId == id;
          return Material(
            color: active ? palette.ink : palette.surface,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: () => onSelect(id),
              borderRadius: BorderRadius.circular(9),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active ? palette.canvas : palette.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
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

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return KofeSurface(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      onTap: () => context.push('/product/${product.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 13,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: palette.imageBackdrop,
                borderRadius: BorderRadius.circular(9),
              ),
              padding: const EdgeInsets.all(8),
              child: ProductImage(asset: product.imageAsset),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            product.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.ink, fontSize: 14, height: 1.15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${product.price.toStringAsFixed(0)} ₽',
                  style: TextStyle(color: palette.ink, fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              KofeAddButton(onTap: () => context.push('/product/${product.id}'), size: 34),
            ],
          ),
        ],
      ),
    );
  }
}

class _FloatingCart extends StatelessWidget {
  const _FloatingCart({required this.quantity, required this.total, required this.onTap});

  final int quantity;
  final double total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Material(
      color: palette.action,
      borderRadius: BorderRadius.circular(16),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.shopping_bag_outlined, color: palette.onAction),
              const SizedBox(width: 10),
              Text('$quantity', style: TextStyle(color: palette.onAction, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('Корзина', style: TextStyle(color: palette.onAction, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Text('${total.toStringAsFixed(0)} ₽', style: TextStyle(color: palette.onAction, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuMessage extends StatelessWidget {
  const _MenuMessage({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 62),
      child: Column(
        children: [
          Icon(icon, color: palette.inkMuted, size: 34),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: palette.inkMuted)),
        ],
      ),
    );
  }
}
