import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../../state/cart.dart';
import '../../state/location.dart';
import '../cart/cart_bar.dart';
import 'product_sheet.dart';

final storeProvider = FutureProvider.autoDispose.family<Store, int>((ref, id) async {
  final at = await ref.watch(browseLocationProvider.future);
  return ref.watch(repositoryProvider).store(id, at);
});

class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key, required this.storeId});

  final int storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider(storeId));

    return store.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(error: e, onRetry: () => ref.invalidate(storeProvider(storeId))),
      ),
      data: (s) => _StoreView(store: s),
    );
  }
}

class _StoreView extends StatefulWidget {
  const _StoreView({required this.store});

  final Store store;

  @override
  State<_StoreView> createState() => _StoreViewState();
}

class _StoreViewState extends State<_StoreView> {
  late final List<MenuCategory> _categories = widget.store.categories.where((c) => c.products.isNotEmpty).toList();
  late final _sectionKeys = [for (final _ in _categories) GlobalKey()];
  int _activeCategory = 0;

  void _jumpTo(int i) {
    setState(() => _activeCategory = i);
    final ctx = _sectionKeys[i].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOut, alignment: 0.02);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;

    return Scaffold(
      bottomNavigationBar: CartBar(storeId: store.id),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            backgroundColor: AppColors.background,
            title: Text(store.name),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  NetImage(store.cover, radius: 0),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black38, Colors.transparent, Colors.transparent],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _StoreHeader(store: store)),
          if (_categories.length > 1)
            SliverPersistentHeader(
              pinned: true,
              delegate: _CategoryTabs(
                names: [for (final c in _categories) c.name],
                active: _activeCategory,
                onTap: _jumpTo,
              ),
            ),
          if (_categories.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyView(icon: Icons.menu_book_outlined, title: 'لا توجد منتجات بعد'),
            ),
          for (var i = 0; i < _categories.length; i++)
            SliverToBoxAdapter(
              child: Column(
                key: _sectionKeys[i],
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(_categories[i].name),
                  for (final p in _categories[i].products)
                    _ProductTile(store: store, product: p),
                ],
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NetImage(store.logo, width: 60, height: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    if (store.address != null) Text(store.address!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          if (store.description?.isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            Text(store.description!, style: const TextStyle(color: AppColors.muted)),
          ],
          const SizedBox(height: 12),
          StoreMeta(store: store),
          if (store.minOrderAmount > 0) ...[
            const SizedBox(height: 6),
            Text('الحد الأدنى للطلب: ${money(store.minOrderAmount)}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ],
          if (!store.isOpenNow) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Text(
                'المتجر مغلق الآن${_nextOpening(store)}',
                style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _nextOpening(Store store) {
    // day_of_week بنفس ترقيم السيرفر: 0 = الأحد.
    final today = DateTime.now().weekday % 7;
    final h = store.hours.where((h) => h.dayOfWeek == today).firstOrNull;
    if (h == null || h.isClosed || h.opensAt == null) return '';
    return ' — يفتح ${h.opensAt}';
  }
}

class _CategoryTabs extends SliverPersistentHeaderDelegate {
  _CategoryTabs({required this.names, required this.active, required this.onTap});

  final List<String> names;
  final int active;
  final ValueChanged<int> onTap;

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: names.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ChoiceChip(
          label: Text(names[i]),
          selected: i == active,
          showCheckmark: false,
          onSelected: (_) => onTap(i),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_CategoryTabs old) => old.active != active || old.names != names;
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.store, required this.product});

  final Store store;
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = product;
    final inCart = ref.watch(cartProvider.select((c) => c.storeId == store.id ? c.quantityOf(p.id) : 0.0));

    return InkWell(
      onTap: () => showProductSheet(context, store: store, product: p),
      child: Opacity(
        opacity: p.isAvailable ? 1 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (inCart > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                            child: Text(qty(inCart), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(child: Text(p.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700))),
                      ],
                    ),
                    if (p.description?.isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          p.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(money(p.price), style: const TextStyle(fontWeight: FontWeight.w800)),
                        if (p.unit != 'piece') Text(' / ${p.unitLabel}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                        if (p.comparePrice != null && p.comparePrice! > p.price) ...[
                          const SizedBox(width: 6),
                          Text(
                            money(p.comparePrice!),
                            style: const TextStyle(color: AppColors.muted, fontSize: 12.5, decoration: TextDecoration.lineThrough),
                          ),
                        ],
                        if (!p.isAvailable) ...[
                          const SizedBox(width: 8),
                          const Text('غير متوفر', style: TextStyle(color: AppColors.danger, fontSize: 12.5)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (p.image != null) ...[
                const SizedBox(width: 12),
                NetImage(p.image, width: 88, height: 88, icon: Icons.fastfood_outlined),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
