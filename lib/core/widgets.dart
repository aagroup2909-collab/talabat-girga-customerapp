import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import 'api.dart';
import 'format.dart';
import 'theme.dart';

void showError(BuildContext context, Object error) {
  final message = error is ApiException ? error.message : 'حدث خطأ غير متوقع.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.danger));
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// صورة من الشبكة مع بديل لو مفيش صورة.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.width, this.height, this.radius = 12, this.icon = Icons.storefront_outlined});

  final String? url;
  final double? width;
  final double? height;
  final double radius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: AppColors.primary.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.primary.withValues(alpha: 0.6), size: 28),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => placeholder,
            ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException ? (error as ApiException).message : 'حدث خطأ غير متوقع.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(160, 44)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.subtitle, this.action});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: const TextStyle(color: AppColors.muted), textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          ?trailing,
        ],
      ),
    );
  }
}

/// سطر في ملخص الحساب: "رسوم التوصيل ....... 15 ج.م"
class AmountRow extends StatelessWidget {
  const AmountRow(this.label, this.value, {super.key, this.bold = false, this.color, this.negative = false});

  final String label;
  final num value;
  final bool bold;
  final bool negative;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 17 : 14,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: color ?? (bold ? AppColors.ink : AppColors.muted),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(negative ? '- ${money(value)}' : money(value), style: style),
        ],
      ),
    );
  }
}

/// زر +/- للكمية.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({super.key, required this.value, required this.onChanged, this.step = 1, this.min = 0, this.compact = false});

  final double value;
  final double step;
  final double min;
  final bool compact;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 30.0 : 40.0;
    Widget btn(IconData icon, VoidCallback? onTap) => SizedBox(
          width: size,
          height: size,
          child: IconButton.filledTonal(
            padding: EdgeInsets.zero,
            iconSize: compact ? 16 : 20,
            onPressed: onTap,
            icon: Icon(icon),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.add, () => onChanged(value + step)),
        SizedBox(
          width: compact ? 36 : 48,
          child: Text(qty(value), textAlign: TextAlign.center, style: TextStyle(fontSize: compact ? 14 : 17, fontWeight: FontWeight.w700)),
        ),
        btn(min <= 0 && value - step <= 0 ? Icons.delete_outline : Icons.remove, value - step < min ? null : () => onChanged(value - step)),
      ],
    );
  }
}

/// بطاقة متجر في القوائم.
class StoreTile extends StatelessWidget {
  const StoreTile({super.key, required this.store, required this.onTap});

  final Store store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                children: [
                  NetImage(store.logo ?? store.cover, width: 72, height: 72),
                  if (!store.isOpenNow)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: const Text('مغلق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (store.storeType != null)
                      Text(store.storeType!.name, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
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

/// ⭐ 4.5 · 25 د · توصيل 15 ج.م
class StoreMeta extends StatelessWidget {
  const StoreMeta({super.key, required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w500);
    Widget item(IconData icon, String text, [Color? color]) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon, size: 15, color: color ?? AppColors.muted), const SizedBox(width: 3), Text(text, style: style)],
        );

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        item(Icons.star_rounded, store.ratingCount > 0 ? store.rating.toStringAsFixed(1) : 'جديد', AppColors.warning),
        if (store.estimatedMinutes != null) item(Icons.schedule, '${store.estimatedMinutes} د'),
        if (store.deliveryFee != null)
          item(Icons.delivery_dining_outlined, store.deliveryFee == 0 ? 'توصيل مجاني' : money(store.deliveryFee!)),
        if (store.distanceKm != null) item(Icons.near_me_outlined, distance(store.distanceKm)),
      ],
    );
  }
}
