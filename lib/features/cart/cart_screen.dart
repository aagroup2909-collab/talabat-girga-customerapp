import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import '../../state/cart.dart';
import '../../state/location.dart';
import '../addresses/addresses_screen.dart';
import '../orders/orders_screen.dart';

/// السلة + معاينة الحساب من السيرفر + تأكيد الطلب.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _coupon = TextEditingController();
  final _notes = TextEditingController();
  String? _appliedCoupon;
  String _payment = 'cash';

  Quote? _quote;
  ApiException? _quoteError;
  bool _quoting = false;
  bool _placing = false;
  Timer? _debounce;
  int _quoteRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshQuote());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _coupon.dispose();
    _notes.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _body({bool withPayment = false}) {
    final cart = ref.read(cartProvider);
    final address = ref.read(currentAddressProvider);
    if (cart.isEmpty || address == null) return null;
    return {
      'store_id': cart.storeId,
      'address_id': address.id,
      'items': cart.toRequestItems(),
      if (_appliedCoupon != null) 'coupon': _appliedCoupon,
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      if (withPayment) 'payment_method': _payment,
    };
  }

  /// أي تغيير في السلة أو العنوان أو الكوبون → إعادة حساب من السيرفر.
  void _scheduleQuote() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _refreshQuote);
  }

  Future<void> _refreshQuote() async {
    final body = _body();
    if (body == null) {
      setState(() {
        _quote = null;
        _quoteError = null;
      });
      return;
    }
    final id = ++_quoteRequest;
    setState(() => _quoting = true);
    try {
      final quote = await ref.read(repositoryProvider).preview(body);
      if (id != _quoteRequest || !mounted) return;
      setState(() {
        _quote = quote;
        _quoteError = null;
      });
    } on ApiException catch (e) {
      if (id != _quoteRequest || !mounted) return;
      setState(() {
        _quote = null;
        _quoteError = e;
      });
    } catch (e) {
      if (id == _quoteRequest && mounted) setState(() => _quoteError = ApiException('تعذر حساب الطلب.'));
    } finally {
      if (id == _quoteRequest && mounted) setState(() => _quoting = false);
    }
  }

  void _applyCoupon() {
    final code = _coupon.text.trim();
    setState(() => _appliedCoupon = code.isEmpty ? null : code);
    FocusScope.of(context).unfocus();
    _refreshQuote();
  }

  Future<void> _placeOrder() async {
    final body = _body(withPayment: true);
    if (body == null) return;

    // كوبون غير صالح: السيرفر يرفض الطلب، فنطلب من العميل إزالته.
    if (_quote?.couponError != null) {
      showMessage(context, 'أزل الكوبون غير الصالح أولًا.');
      return;
    }

    setState(() => _placing = true);
    try {
      final placed = await ref.read(repositoryProvider).placeOrder(body);
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(ordersProvider);
      if (!mounted) return;
      context.go('/orders/${placed.order.id}');
      if (placed.paymentUrl != null) {
        await launchUrl(Uri.parse(placed.paymentUrl!), mode: LaunchMode.externalApplication);
      }
    } on ApiException catch (e) {
      if (mounted) showError(context, e);
      _refreshQuote();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final address = ref.watch(currentAddressProvider);
    final cardEnabled = ref.watch(appConfigProvider).value?['card_payments_enabled'] == true;

    ref.listen(cartProvider, (_, _) => _scheduleQuote());
    ref.listen(currentAddressProvider, (prev, next) {
      if (prev?.id != next?.id) _scheduleQuote();
    });

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('السلة')),
        body: EmptyView(
          icon: Icons.shopping_bag_outlined,
          title: 'سلتك فاضية',
          subtitle: 'أضف منتجات من أي متجر لتبدأ طلبك',
          action: FilledButton(
            onPressed: () => context.go('/'),
            style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
            child: const Text('تصفح المتاجر'),
          ),
        ),
      );
    }

    final quote = _quote;
    final canPlace = address != null && quote != null && !quote.belowMinimum && !_quoting && !_placing && _quoteError == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('السلة'),
        actions: [
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تفريغ السلة؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تفريغ')),
                  ],
                ),
              );
              if (ok == true) ref.read(cartProvider.notifier).clear();
            },
            child: const Text('تفريغ'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------- المتجر والمنتجات ----------
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storefront_outlined, color: AppColors.primary),
                  title: Text(cart.storeName ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                  trailing: TextButton(
                    onPressed: () => context.push('/store/${cart.storeId}'),
                    child: const Text('أضف المزيد'),
                  ),
                ),
                const Divider(),
                for (final line in cart.lines) _CartLineTile(line: line),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---------- العنوان ----------
          const _Label('عنوان التوصيل'),
          Card(
            child: address == null
                ? ListTile(
                    leading: const Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
                    title: const Text('أضف عنوان التوصيل'),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => context.push('/addresses/new'),
                  )
                : ListTile(
                    leading: Icon(addressIcon(address), color: AppColors.primary),
                    title: Text(address.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(address.details, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Text('تغيير', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    onTap: () => showAddressPicker(context),
                  ),
          ),
          const SizedBox(height: 16),

          // ---------- الكوبون والملاحظات ----------
          const _Label('كود الخصم'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _coupon,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'اكتب الكود',
                    prefixIcon: const Icon(Icons.local_offer_outlined),
                    errorText: quote?.couponError,
                    helperText: quote?.coupon != null && quote!.couponError == null ? 'تم تطبيق الخصم' : null,
                    helperStyle: const TextStyle(color: AppColors.success),
                  ),
                  onSubmitted: (_) => _applyCoupon(),
                ),
              ),
              const SizedBox(width: 8),
              if (_appliedCoupon != null)
                IconButton(
                  onPressed: () {
                    _coupon.clear();
                    _applyCoupon();
                  },
                  icon: const Icon(Icons.close),
                )
              else
                OutlinedButton(
                  onPressed: _applyCoupon,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(80, 50)),
                  child: const Text('تطبيق'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const _Label('ملاحظات للمتجر أو السائق'),
          TextField(
            controller: _notes,
            maxLines: 2,
            maxLength: 500,
            decoration: const InputDecoration(hintText: 'مثال: اتصل قبل الوصول', counterText: ''),
          ),
          const SizedBox(height: 16),

          // ---------- الدفع ----------
          const _Label('طريقة الدفع'),
          Card(
            child: RadioGroup<String>(
              groupValue: _payment,
              onChanged: (v) => setState(() => _payment = v ?? 'cash'),
              child: Column(
                children: [
                  const RadioListTile<String>(
                    value: 'cash',
                    title: Text('كاش عند الاستلام'),
                    secondary: Icon(Icons.payments_outlined),
                  ),
                  if (cardEnabled)
                    const RadioListTile<String>(
                      value: 'card',
                      title: Text('بطاقة بنكية'),
                      secondary: Icon(Icons.credit_card),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---------- الحساب ----------
          const _Label('ملخص الحساب'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSummary(cart, address),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: canPlace ? _placeOrder : null,
          child: _placing
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(quote == null ? 'تأكيد الطلب' : 'تأكيد الطلب · ${money(quote.total)}'),
        ),
      ),
    );
  }

  Widget _buildSummary(Cart cart, Address? address) {
    if (address == null) {
      return Column(
        children: [
          AmountRow('المنتجات', cart.subtotal),
          const SizedBox(height: 8),
          const Text('أضف عنوانًا لحساب رسوم التوصيل', style: TextStyle(color: AppColors.muted)),
        ],
      );
    }
    if (_quoteError != null) {
      return Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(_quoteError!.message, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600))),
          IconButton(onPressed: _refreshQuote, icon: const Icon(Icons.refresh)),
        ],
      );
    }
    final q = _quote;
    if (q == null) return const Padding(padding: EdgeInsets.all(12), child: LoadingView());

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: _quoting ? 0.5 : 1,
      child: Column(
        children: [
          AmountRow('المنتجات', q.subtotal),
          AmountRow('رسوم التوصيل (${distance(q.distanceKm)})', q.deliveryFee),
          if (q.serviceFee > 0) AmountRow('رسوم الخدمة', q.serviceFee),
          if (q.discount > 0) AmountRow('الخصم', q.discount, negative: true, color: AppColors.success),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
          AmountRow('الإجمالي', q.total, bold: true),
          if (q.belowMinimum)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'الحد الأدنى للطلب ${money(q.minOrderAmount)} — أضف ${money(q.minOrderAmount - q.subtotal)}',
                style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, right: 4, left: 4),
        child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (line.options.isNotEmpty)
                  Text(line.optionsText, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                if (line.notes != null)
                  Text('ملاحظة: ${line.notes}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                const SizedBox(height: 6),
                Text(money(line.total), style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          QuantityStepper(
            compact: true,
            value: line.quantity,
            step: line.step,
            onChanged: (v) => ref.read(cartProvider.notifier).changeQuantity(line, v - line.quantity),
          ),
        ],
      ),
    );
  }
}
