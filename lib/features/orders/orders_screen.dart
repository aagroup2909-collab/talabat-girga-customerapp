import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/repository.dart';
import '../../models/models.dart';

/// true = الطلبات الحالية، false = السابقة
final ordersProvider = FutureProvider.autoDispose.family<Paged<Order>, bool>(
  (ref, active) => ref.watch(repositoryProvider).orders(active: active),
);

Color statusColor(OrderStatus s) => switch (s) {
      OrderStatus.pending => AppColors.warning,
      OrderStatus.delivered => AppColors.success,
      OrderStatus.cancelled => AppColors.danger,
      _ => AppColors.primary,
    };

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلباتي'),
          bottom: const TabBar(tabs: [Tab(text: 'الحالية'), Tab(text: 'السابقة')]),
        ),
        body: const TabBarView(children: [_OrdersList(active: true), _OrdersList(active: false)]),
      ),
    );
  }
}

class _OrdersList extends ConsumerWidget {
  const _OrdersList({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider(active));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(ordersProvider(active).future),
      child: orders.when(
        loading: () => const LoadingView(),
        error: (e, _) => ListView(children: [
          SizedBox(height: 400, child: ErrorView(error: e, onRetry: () => ref.invalidate(ordersProvider(active)))),
        ]),
        data: (page) => page.items.isEmpty
            ? ListView(children: [
                SizedBox(
                  height: 400,
                  child: EmptyView(
                    icon: Icons.receipt_long_outlined,
                    title: active ? 'لا توجد طلبات حالية' : 'لا توجد طلبات سابقة',
                  ),
                ),
              ])
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: page.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => OrderCard(order: page.items[i]),
              ),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(order.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              NetImage(order.store?.logo, width: 56, height: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.store?.name ?? 'طلب #${order.number}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      '#${order.number} · ${dateTime(order.createdAt)}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                          child: Text(order.statusLabel, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        const Spacer(),
                        Text(money(order.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
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
