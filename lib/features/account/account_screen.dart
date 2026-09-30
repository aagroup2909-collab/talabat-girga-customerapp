import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/repository.dart';
import '../../state/auth.dart';
import '../../state/cart.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final supportPhone = ref.watch(appConfigProvider).value?['support_phone'] as String?;

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: Colors.white, size: 30),
              ),
              title: Text(user?.name ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              subtitle: Directionality(textDirection: TextDirection.ltr, child: Text(user?.phone ?? '', textAlign: TextAlign.end)),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('عناويني'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/addresses'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('طلباتي'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.go('/orders'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('تغيير كلمة المرور'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push('/change-password'),
                ),
                if (supportPhone != null && supportPhone.isNotEmpty) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.support_agent),
                    title: const Text('اتصل بالدعم'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => launchUrl(Uri(scheme: 'tel', path: supportPhone)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('تسجيل الخروج؟'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('خروج')),
                    ],
                  ),
                );
                if (ok != true) return;
                ref.read(cartProvider.notifier).clear();
                await ref.read(authProvider.notifier).signOut();
              },
            ),
          ),
        ],
      ),
    );
  }
}
