import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../../state/location.dart';
import '../addresses/addresses_screen.dart';
import '../cart/cart_bar.dart';

final homeProvider = FutureProvider.autoDispose<HomeData>((ref) async {
  final at = await ref.watch(browseLocationProvider.future);
  return ref.watch(repositoryProvider).home(at);
});

IconData storeTypeIcon(String slug) => switch (slug) {
      'restaurants' => Icons.restaurant,
      'supermarkets' => Icons.local_grocery_store_outlined,
      'pharmacies' => Icons.local_pharmacy_outlined,
      'sweets' => Icons.cake_outlined,
      'vegetables' => Icons.eco_outlined,
      _ => Icons.storefront_outlined,
    };

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 16,
        toolbarHeight: 64,
        title: const _DeliverToHeader(),
      ),
      bottomNavigationBar: const CartBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(addressesProvider);
          ref.invalidate(homeProvider);
          await ref.read(homeProvider.future);
        },
        child: home.when(
          loading: () => const LoadingView(),
          error: (e, _) => ListView(children: [
            SizedBox(height: 400, child: ErrorView(error: e, onRetry: () => ref.invalidate(homeProvider))),
          ]),
          data: (data) => _HomeBody(data: data),
        ),
      ),
    );
  }
}

class _DeliverToHeader extends ConsumerWidget {
  const _DeliverToHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(currentAddressProvider);
    final hasAddresses = (ref.watch(addressesProvider).value ?? const []).isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => hasAddresses ? showAddressPicker(context) : context.push('/addresses/new'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('التوصيل إلى', style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 18, color: AppColors.primary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    address?.title ?? 'أضف عنوان التوصيل',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: TextField(
            readOnly: true,
            onTap: () => context.push('/search'),
            decoration: const InputDecoration(
              hintText: 'ابحث عن متجر أو منتج',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        if (!data.inServiceArea)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Card(
              color: AppColors.warning.withValues(alpha: 0.12),
              child: const ListTile(
                leading: Icon(Icons.info_outline, color: AppColors.warning),
                title: Text('هذا الموقع خارج نطاق التوصيل حاليًا'),
                subtitle: Text('نعمل حاليًا داخل جرجا. اختر عنوانًا آخر.'),
              ),
            ),
          ),
        if (data.banners.isNotEmpty) _Banners(banners: data.banners),
        if (data.storeTypes.isNotEmpty) ...[
          const SectionTitle('الأقسام'),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: data.storeTypes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _StoreTypeItem(type: data.storeTypes[i]),
            ),
          ),
        ],
        if (data.featured.isNotEmpty) ...[
          const SectionTitle('مميز'),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: data.featured.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _FeaturedCard(store: data.featured[i]),
            ),
          ),
        ],
        SectionTitle(
          'قريب منك',
          trailing: TextButton(onPressed: () => context.push('/stores'), child: const Text('عرض الكل')),
        ),
        if (data.nearby.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: EmptyView(icon: Icons.storefront_outlined, title: 'لا توجد متاجر قريبة من هذا العنوان'),
          )
        else
          for (final store in data.nearby)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: StoreTile(store: store, onTap: () => context.push('/store/${store.id}')),
            ),
      ],
    );
  }
}

class _Banners extends StatelessWidget {
  const _Banners({required this.banners});

  final List<Banner> banners;

  void _open(BuildContext context, Banner b) {
    if (b.storeId != null) {
      context.push('/store/${b.storeId}');
    } else if (b.storeTypeId != null) {
      context.push('/stores?type=${b.storeTypeId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 150,
        child: PageView.builder(
          controller: PageController(viewportFraction: 0.9),
          itemCount: banners.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => _open(context, banners[i]),
              child: NetImage(banners[i].image, radius: 16, icon: Icons.local_offer_outlined),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreTypeItem extends StatelessWidget {
  const _StoreTypeItem({required this.type});

  final StoreType type;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/stores?type=${type.id}&title=${Uri.encodeComponent(type.name)}'),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: type.icon != null
                  ? NetImage(type.icon, radius: 20)
                  : Icon(storeTypeIcon(type.slug), color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 6),
            Text(
              type.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/store/${store.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NetImage(store.cover ?? store.logo, height: 120, width: double.infinity, radius: 0),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    StoreMeta(store: store),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
