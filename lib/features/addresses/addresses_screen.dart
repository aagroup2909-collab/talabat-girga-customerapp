import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/location.dart';

IconData addressIcon(Address a) => switch (a.label) {
      'البيت' => Icons.home_outlined,
      'الشغل' => Icons.work_outline,
      _ => Icons.location_on_outlined,
    };

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('عناويني')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/addresses/new'),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('عنوان جديد'),
      ),
      body: addresses.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(addressesProvider)),
        data: (list) => list.isEmpty
            ? const EmptyView(
                icon: Icons.location_off_outlined,
                title: 'لا توجد عناوين',
                subtitle: 'أضف عنوانك لنعرض لك المتاجر القريبة منك',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _AddressCard(address: list[i]),
              ),
      ),
    );
  }
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard({required this.address});

  final Address address;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العنوان؟'),
        content: Text(address.details),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(addressesProvider.notifier).remove(address.id!);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Icon(addressIcon(address), color: AppColors.primary),
        ),
        title: Row(
          children: [
            Flexible(child: Text(address.title, style: const TextStyle(fontWeight: FontWeight.w700))),
            if (address.isDefault) ...[
              const SizedBox(width: 8),
              const _Badge('افتراضي', AppColors.success),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(address.details, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (address.outsideZones)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('خارج نطاق التوصيل حاليًا', style: TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => v == 'edit' ? context.push('/addresses/edit', extra: address) : _delete(context, ref),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('تعديل')),
            PopupMenuItem(value: 'delete', child: Text('حذف')),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

/// ورقة اختيار عنوان التوصيل (من الرئيسية والدفع).
Future<void> showAddressPicker(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final list = ref.watch(addressesProvider).value ?? const <Address>[];
        final current = ref.watch(currentAddressProvider);

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text('التوصيل إلى', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final a in list)
                        ListTile(
                          leading: Icon(addressIcon(a), color: a.id == current?.id ? AppColors.primary : AppColors.muted),
                          title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(a.details, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: a.id == current?.id ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                          onTap: () {
                            ref.read(selectedAddressIdProvider.notifier).select(a.id!);
                            Navigator.pop(ctx);
                          },
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await context.push('/addresses/new');
                    },
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('إضافة عنوان جديد'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
