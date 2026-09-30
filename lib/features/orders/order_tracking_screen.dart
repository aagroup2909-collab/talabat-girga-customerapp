import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import 'orders_screen.dart';

final orderProvider = FutureProvider.autoDispose.family<Order, int>(
  (ref, id) => ref.watch(repositoryProvider).order(id),
);

/// تتبع الطلب: يتحدث كل 10 ثوانٍ طالما الطلب نشط.
/// TODO: الاشتراك في قناة Reverb private-order.{id} بدل الـ polling.
class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(AppConfig.orderPollInterval, (_) {
      final order = ref.read(orderProvider(widget.orderId)).value;
      if (order == null || order.status.isActive) ref.invalidate(orderProvider(widget.orderId));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderProvider(widget.orderId));

    // لما الحالة تتغير نحدّث قائمة الطلبات كمان.
    ref.listen(orderProvider(widget.orderId), (prev, next) {
      if (prev?.value?.status != next.value?.status) ref.invalidate(ordersProvider);
    });

    return Scaffold(
      appBar: AppBar(title: Text(order.value != null ? 'طلب #${order.value!.number}' : 'تتبع الطلب')),
      body: order.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(orderProvider(widget.orderId))),
        data: (o) => RefreshIndicator(
          onRefresh: () => ref.refresh(orderProvider(widget.orderId).future),
          child: _OrderBody(order: o),
        ),
      ),
    );
  }
}

class _OrderBody extends ConsumerWidget {
  const _OrderBody({required this.order});

  final Order order;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الطلب؟'),
        content: TextField(controller: reason, decoration: const InputDecoration(hintText: 'السبب (اختياري)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('إلغاء الطلب'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(repositoryProvider).cancelOrder(order.id, reason: reason.text.trim().isEmpty ? null : reason.text.trim());
      ref.invalidate(orderProvider(order.id));
      ref.invalidate(ordersProvider);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    try {
      final url = await ref.read(repositoryProvider).paymentUrl(order.id);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showMap = order.status.isActive && order.deliveryPoint != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusHeader(order: order),
        if (order.awaitingCardPayment) ...[
          const SizedBox(height: 12),
          Card(
            color: AppColors.warning.withValues(alpha: 0.12),
            child: ListTile(
              leading: const Icon(Icons.credit_card, color: AppColors.warning),
              title: const Text('الطلب بانتظار الدفع'),
              trailing: FilledButton(
                onPressed: () => _pay(context, ref),
                style: FilledButton.styleFrom(minimumSize: const Size(90, 40)),
                child: const Text('ادفع'),
              ),
            ),
          ),
        ],
        if (order.status.isActive && order.deliveryCode != null) ...[
          const SizedBox(height: 12),
          _DeliveryCode(code: order.deliveryCode!),
        ],
        if (showMap) ...[
          const SizedBox(height: 12),
          _TrackingMap(order: order),
        ],
        if (order.driver != null && order.status.isActive) ...[
          const SizedBox(height: 12),
          _DriverCard(driver: order.driver!),
        ],
        if (order.status != OrderStatus.cancelled) ...[
          const SizedBox(height: 12),
          _Steps(order: order),
        ],
        if (order.canReview) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.star_rounded, color: AppColors.warning, size: 32),
              title: const Text('كيف كان طلبك؟', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('قيّم المتجر والسائق'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => showReviewSheet(context, order),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _Details(order: order),
        if (order.canCancel) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _cancel(context, ref),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('إلغاء الطلب'),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('يمكن الإلغاء قبل قبول المتجر فقط', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(order.status);
    final (icon, subtitle) = switch (order.status) {
      OrderStatus.pending => (Icons.hourglass_top_rounded, 'في انتظار موافقة ${order.store?.name ?? 'المتجر'}'),
      OrderStatus.accepted || OrderStatus.preparing => (Icons.soup_kitchen_outlined, 'المتجر يجهز طلبك'),
      OrderStatus.ready => (Icons.inventory_2_outlined, order.driver == null ? 'نبحث عن سائق لطلبك' : 'السائق في طريقه للمتجر'),
      OrderStatus.pickedUp => (Icons.delivery_dining, 'السائق في الطريق إليك'),
      OrderStatus.delivered => (Icons.check_circle_outline, 'بالهناء والشفاء!'),
      OrderStatus.cancelled => (Icons.cancel_outlined, order.cancelReason ?? 'تم إلغاء الطلب'),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 28, backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color, size: 30)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.status.label, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted)),
                  if (order.status.isActive && order.estimatedDeliveryAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'الوصول المتوقع ${timeOfDay(order.estimatedDeliveryAt)}${order.isLate ? ' (متأخر قليلًا)' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryCode extends StatelessWidget {
  const _DeliveryCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary.withValues(alpha: 0.07),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('كود الاستلام', style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('أعطِ هذا الكود للسائق عند الاستلام فقط', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                ],
              ),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(code, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 6, color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingMap extends StatefulWidget {
  const _TrackingMap({required this.order});

  final Order order;

  @override
  State<_TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<_TrackingMap> {
  final _map = MapController();
  bool _fittedWithDriver = false;

  List<LatLng> get _points => [widget.order.deliveryPoint!, ?widget.order.store?.point, ?widget.order.driver?.point];

  /// ملاحظة: initialCameraFit لا يحمّل البلاطات قبل أول حركة، فنضبط الكاميرا بعد جاهزية الخريطة.
  void _fit() {
    final points = _points;
    if (points.length < 2) return;
    _map.fitCamera(CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(48), maxZoom: 17));
  }

  @override
  void didUpdateWidget(_TrackingMap old) {
    super.didUpdateWidget(old);
    // أعد الضبط مرة واحدة لما يظهر السائق لأول مرة؛ بعدها لا نحرك الكاميرا مع كل تحديث.
    if (!_fittedWithDriver && widget.order.driver?.point != null) {
      _fittedWithDriver = true;
      _fit();
    }
  }

  Marker _marker(LatLng p, IconData icon, Color color) => Marker(
        point: p,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final destination = widget.order.deliveryPoint!;
    final store = widget.order.store?.point;
    final driver = widget.order.driver?.point;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: destination,
            initialZoom: 15,
            onMapReady: () {
              _fittedWithDriver = driver != null;
              _fit();
            },
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
          ),
          children: [
            TileLayer(urlTemplate: AppConfig.tileUrl, userAgentPackageName: AppConfig.mapUserAgent),
            MarkerLayer(markers: [
              if (store != null) _marker(store, Icons.storefront, AppColors.ink),
              _marker(destination, Icons.home_rounded, AppColors.success),
              if (driver != null) _marker(driver, Icons.delivery_dining, AppColors.primary),
            ]),
          ],
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver});

  final Driver driver;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: driver.avatar != null
              ? NetImage(driver.avatar, width: 48, height: 48, radius: 24)
              : const Icon(Icons.person, color: AppColors.primary),
        ),
        title: Text(driver.name ?? 'السائق', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text([
          if (driver.vehicle != null) driver.vehicle!,
          if (driver.plate != null) driver.plate!,
          if (driver.rating > 0) '★ ${driver.rating.toStringAsFixed(1)}',
        ].join(' · ')),
        trailing: driver.phone == null
            ? null
            : IconButton.filled(
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: driver.phone)),
                icon: const Icon(Icons.call),
              ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final current = OrderStatus.steps.indexOf(order.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          children: [
            for (var i = 0; i < OrderStatus.steps.length; i++)
              _StepRow(
                label: OrderStatus.steps[i].label,
                time: order.stepTime(OrderStatus.steps[i]),
                done: i <= current,
                active: i == current && order.status.isActive,
                last: i == OrderStatus.steps.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, this.time, required this.done, required this.active, required this.last});

  final String label;
  final DateTime? time;
  final bool done;
  final bool active;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.primary : AppColors.line;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: done ? color : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: done ? Icon(active ? Icons.more_horiz : Icons.check, size: 14, color: Colors.white) : null,
              ),
              if (!last) Expanded(child: Container(width: 2, color: color)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                        color: done ? AppColors.ink : AppColors.muted,
                      ),
                    ),
                  ),
                  if (time != null) Text(timeOfDay(time), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.store?.name ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${qty(item.quantity)}×  ', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name),
                          if (item.optionsText.isNotEmpty)
                            Text(item.optionsText, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Text(money(item.total)),
                  ],
                ),
              ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
            AmountRow('المنتجات', order.subtotal),
            AmountRow('التوصيل', order.deliveryFee),
            if (order.serviceFee > 0) AmountRow('رسوم الخدمة', order.serviceFee),
            if (order.discount > 0) AmountRow('الخصم', order.discount, negative: true, color: AppColors.success),
            AmountRow(order.paymentMethod == 'card' ? 'الإجمالي (بطاقة)' : 'الإجمالي (كاش)', order.total, bold: true),
            if (order.deliveryAddress != null) ...[
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 20, color: AppColors.muted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(order.deliveryAddress!, style: const TextStyle(color: AppColors.muted))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> showReviewSheet(BuildContext context, Order order) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReviewSheet(order: order),
  );
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.order});

  final Order order;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  int _store = 0;
  int _driver = 0;
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).review(
            widget.order.id,
            storeRating: _store,
            driverRating: _driver == 0 ? null : _driver,
            comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
          );
      ref.invalidate(orderProvider(widget.order.id));
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(context, 'شكرًا لتقييمك!');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _stars(int value, ValueChanged<int> onChanged) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              onPressed: () => onChanged(i),
              iconSize: 36,
              icon: Icon(i <= value ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.warning),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('قيّم ${widget.order.store?.name ?? 'المتجر'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          _stars(_store, (v) => setState(() => _store = v)),
          if (widget.order.driver != null) ...[
            const SizedBox(height: 8),
            Text('قيّم السائق ${widget.order.driver!.name ?? ''}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            _stars(_driver, (v) => setState(() => _driver = v)),
          ],
          const SizedBox(height: 8),
          TextField(controller: _comment, maxLines: 3, decoration: const InputDecoration(hintText: 'تعليق (اختياري)')),
          const SizedBox(height: 16),
          FilledButton(onPressed: _store == 0 || _busy ? null : _submit, child: const Text('إرسال التقييم')),
        ],
      ),
    );
  }
}
