import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data_providers.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kofe_surface.dart';
import '../../core/widgets/product_image.dart';
import '../../data/models/models.dart';

/// Product hero and lower configuration sheet. All prices stay model-driven.
class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({super.key, required this.productId}) : editingCartIndex = null;

  const ProductScreen.editCartItem({super.key, required this.editingCartIndex}) : productId = null;

  final String? productId;
  final int? editingCartIndex;

  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  Product? _product;
  ProductSize? _size;
  int _qty = 1;
  final Map<String, ModifierOption> _mods = {};
  String? _initializedFor;

  bool get _editing => widget.editingCartIndex != null;

  void _ensureInit(Product product, {CartItem? cartItem}) {
    final signature = '${product.id}|${product.sizes.map((e) => e.id).join(',')}|${product.modifierGroups.map((e) => e.id).join(',')}';
    if (_initializedFor == signature) return;
    _initializedFor = signature;
    _product = product;
    _qty = cartItem?.qty ?? 1;
    _size = cartItem?.size;
    _mods.clear();
    if (_size == null && product.sizes.isNotEmpty) {
      _size = product.sizes.length > 1 ? product.sizes[1] : product.sizes.first;
    }
    for (final group in product.modifierGroups) {
      final fromCart = cartItem?.modifiers.where((item) => item.groupId == group.id).firstOrNull;
      ModifierOption? selected;
      for (final option in group.options) {
        if (option.id == fromCart?.optionId) selected = option;
        if (selected == null && option.isDefault) selected = option;
      }
      if (selected == null && group.required && group.options.isNotEmpty) selected = group.options.first;
      if (selected != null) _mods[group.id] = selected;
    }
  }

  double get _unitPrice => (_product?.price ?? 0) +
      (_size?.priceDelta ?? 0) +
      _mods.values.fold<double>(0, (sum, item) => sum + item.priceDelta);

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      final index = widget.editingCartIndex!;
      final items = ref.watch(cartProvider).items;
      if (index < 0 || index >= items.length) return const _RemovedCartItem();
      final item = items[index];
      final product = ref.watch(productProvider(item.product.id)).valueOrNull ?? item.product;
      _ensureInit(product, cartItem: item);
      return _loaded(product);
    }

    return ref.watch(productProvider(widget.productId!)).when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => _ProductError(message: '$error'),
      data: (product) {
        _ensureInit(product);
        return _loaded(product);
      },
    );
  }

  Widget _loaded(Product product) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              _ProductHero(product: product, cartQuantity: ref.watch(cartProvider).totalQty),
              Expanded(
                child: Container(
                  width: double.infinity,
                  transform: Matrix4.translationValues(0, -24, 0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).extension<KofePalette>()!.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: _ProductSheet(
                    product: product,
                    selectedSize: _size,
                    selectedModifiers: _mods,
                    onSize: (size) => setState(() => _size = size),
                    onModifier: _openModifierSheet,
                    onReset: () => _resetModifiers(product),
                  ),
                ),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _HeroIcon(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => context.canPop() ? context.pop() : context.go('/menu'),
                  ),
                  const Spacer(),
                  _HeroIcon(
                    icon: Icons.shopping_bag_outlined,
                    badge: ref.watch(cartProvider).totalQty,
                    onTap: () => context.go('/cart'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Theme.of(context).extension<KofePalette>()!.surface,
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: Row(
            children: [
              KofeQuantityControl(
                value: _qty,
                onMinus: () => setState(() => _qty = (_qty - 1).clamp(1, 99)),
                onPlus: () => setState(() => _qty = (_qty + 1).clamp(1, 99)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: () => _save(product),
                  child: Text('${_editing ? 'Обновить' : 'В корзину'} · ${(_unitPrice * _qty).toStringAsFixed(0)} ₽'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetModifiers(Product product) {
    setState(() {
      _mods.clear();
      for (final group in product.modifierGroups) {
        final option = group.options.where((item) => item.isDefault).firstOrNull ??
            (group.required && group.options.isNotEmpty ? group.options.first : null);
        if (option != null) _mods[group.id] = option;
      }
    });
  }

  Future<void> _openModifierSheet(ModifierGroup group) async {
    var draft = _mods[group.id];
    final chosen = await showModalBottomSheet<ModifierOption>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final palette = context.kofePalette;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.title, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 16),
                  ...group.options.map((option) {
                    final active = draft?.id == option.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: active ? palette.surfaceMuted : palette.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => setModalState(() => draft = option),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              children: [
                                Expanded(child: Text(option.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                                if (option.priceDelta > 0)
                                  Text('+${option.priceDelta.toStringAsFixed(0)} ₽', style: TextStyle(color: palette.inkMuted)),
                                const SizedBox(width: 10),
                                Icon(active ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: palette.ink),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: draft == null && group.required ? null : () => Navigator.pop(context, draft),
                      child: const Text('Готово'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (chosen != null) setState(() => _mods[group.id] = chosen);
  }

  void _save(Product product) {
    final modifiers = _mods.entries.map((entry) {
      final group = product.modifierGroups.firstWhere((item) => item.id == entry.key);
      return SelectedModifier(
        groupId: group.id,
        groupTitle: group.title,
        optionId: entry.value.id,
        optionTitle: entry.value.title,
        priceDelta: entry.value.priceDelta,
      );
    }).toList();
    if (_editing) {
      ref.read(cartProvider.notifier).updateItem(
        widget.editingCartIndex!,
        product: product,
        qty: _qty,
        size: _size,
        modifiers: modifiers,
      );
    } else {
      ref.read(cartProvider.notifier).add(product: product, qty: _qty, size: _size, modifiers: modifiers);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_editing ? 'Настройки обновлены' : 'Добавлено в корзину')),
    );
    context.canPop() ? context.pop() : context.go('/cart');
  }
}

class _ProductHero extends StatelessWidget {
  const _ProductHero({required this.product, required this.cartQuantity});

  final Product product;
  final int cartQuantity;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Container(
      height: 360,
      width: double.infinity,
      color: palette.imageBackdrop,
      padding: const EdgeInsets.fromLTRB(48, 58, 48, 22),
      child: ProductImage(asset: product.imageAsset, fit: BoxFit.contain),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({required this.icon, required this.onTap, this.badge = 0});

  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: palette.surface.withValues(alpha: 0.92),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 19, color: palette.ink)),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: -2,
            top: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: palette.ink, borderRadius: BorderRadius.circular(10)),
              child: Text('$badge', style: TextStyle(color: palette.canvas, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }
}

class _ProductSheet extends StatelessWidget {
  const _ProductSheet({
    required this.product,
    required this.selectedSize,
    required this.selectedModifiers,
    required this.onSize,
    required this.onModifier,
    required this.onReset,
  });

  final Product product;
  final ProductSize? selectedSize;
  final Map<String, ModifierOption> selectedModifiers;
  final ValueChanged<ProductSize> onSize;
  final ValueChanged<ModifierGroup> onModifier;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      children: [
        Text(
          product.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 23,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          product.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: palette.inkMuted, fontSize: 13, height: 1.25),
        ),
        if (product.nutrition != null) ...[
          const SizedBox(height: 8),
          _NutritionRow(nutrition: product.nutrition!),
        ],
        if (product.sizes.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Размер', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: product.sizes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final size = product.sizes[index];
                final active = size.id == selectedSize?.id;
                return Material(
                  color: active ? palette.ink : palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => onSize(size),
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 76,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(size.label, style: TextStyle(color: active ? palette.canvas : palette.ink, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text('${size.ml} мл', style: TextStyle(color: active ? palette.canvas.withValues(alpha: .75) : palette.inkMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (product.modifierGroups.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Настроить напиток', style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(onPressed: onReset, child: const Text('Сбросить')),
            ],
          ),
          const SizedBox(height: 2),
          ...product.modifierGroups.map(
            (group) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: KofeSurface(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                onTap: () => onModifier(group),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(group.title, style: TextStyle(color: palette.inkMuted, fontSize: 12)),
                          const SizedBox(height: 3),
                          Text(selectedModifiers[group.id]?.title ?? 'Выбрать', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 15, color: palette.inkMuted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _NutritionRow extends StatelessWidget {
  const _NutritionRow({required this.nutrition});

  final Nutrition nutrition;

  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    final values = [
      ('${nutrition.weightG.toStringAsFixed(0)} г', 'Вес'),
      ('${nutrition.proteins} г', 'Белки'),
      ('${nutrition.fats} г', 'Жиры'),
      ('${nutrition.carbs} г', 'Углеводы'),
      ('${nutrition.kcal.toStringAsFixed(0)}', 'Ккал'),
    ];
    return Row(
      children: values.map((item) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 2),
            Text(item.$2, style: TextStyle(color: palette.inkMuted, fontSize: 11)),
          ],
        ),
      )).toList(),
    );
  }
}

class _ProductError extends StatelessWidget {
  const _ProductError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Не удалось загрузить товар\n$message', textAlign: TextAlign.center))),
  );
}

class _RemovedCartItem extends StatelessWidget {
  const _RemovedCartItem();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: const Center(child: Text('Эта позиция уже удалена из корзины')),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
