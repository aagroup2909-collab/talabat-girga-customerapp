import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../state/cart.dart';

/// شريط "عرض السلة" أسفل الشاشات لما السلة فيها حاجة.
class CartBar extends ConsumerWidget {
  const CartBar({super.key, this.storeId});

  /// لو محدد: يظهر فقط لو السلة من نفس المتجر.
  final int? storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    if (cart.isEmpty || (storeId != null && cart.storeId != storeId)) return const SizedBox.shrink();

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/cart'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                  child: Text('${cart.count}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('عرض السلة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                      if (storeId == null && cart.storeName != null)
                        Text(cart.storeName!, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1),
                    ],
                  ),
                ),
                Text(money(cart.subtotal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
