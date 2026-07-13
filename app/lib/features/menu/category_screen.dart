import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kofe_surface.dart';
import '../../core/widgets/product_image.dart';
import '../../data/models/models.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key, required this.categoryId});
  final String categoryId;
  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final title = categories.where((item) => item.id == widget.categoryId).firstOrNull?.title ?? 'Категория';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                decoration: InputDecoration(hintText: 'Поиск в категории', prefixIcon: Icon(Icons.search_rounded, color: palette.inkMuted)),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ref.watch(productsProvider(widget.categoryId)).when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Не удалось загрузить товары\n$error', textAlign: TextAlign.center)),
                  data: (products) {
                    final visible = products.where((product) => _query.isEmpty || product.title.toLowerCase().contains(_query) || product.description.toLowerCase().contains(_query)).toList();
                    if (visible.isEmpty) return Center(child: Text('Ничего не нашли', style: TextStyle(color: palette.inkMuted)));
                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .66),
                      itemCount: visible.length,
                      itemBuilder: (_, index) => _CategoryProductTile(product: visible[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryProductTile extends StatelessWidget {
  const _CategoryProductTile({required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) {
    final palette = context.kofePalette;
    return KofeSurface(
      padding: const EdgeInsets.all(10),
      onTap: () => context.push('/product/${product.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Container(width: double.infinity, decoration: BoxDecoration(color: palette.imageBackdrop, borderRadius: BorderRadius.circular(9)), child: ProductImage(asset: product.imageAsset))),
        const SizedBox(height: 9),
        Text(product.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('${product.price.toStringAsFixed(0)} ₽', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
