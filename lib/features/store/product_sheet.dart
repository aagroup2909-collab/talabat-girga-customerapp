import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/cart.dart';

/// يطلب تأكيد تفريغ السلة لو فيها طلب من متجر آخر. يرجع true لو مسموح بالإضافة.
Future<bool> confirmStoreSwitch(BuildContext context, WidgetRef ref, Store store) async {
  final cart = ref.read(cartProvider);
  if (!ref.read(cartProvider.notifier).conflictsWith(store.id)) return true;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('بدء سلة جديدة؟'),
      content: Text('سلتك فيها طلب من "${cart.storeName}". الطلب يكون من متجر واحد فقط، هل تريد تفريغ السلة؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لا')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تفريغ وإضافة')),
      ],
    ),
  );
  return ok == true;
}

Future<void> showProductSheet(BuildContext context, {required Store store, required Product product}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ProductSheet(store: store, product: product),
  );
}

class _ProductSheet extends ConsumerStatefulWidget {
  const _ProductSheet({required this.store, required this.product});

  final Store store;
  final Product product;

  @override
  ConsumerState<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends ConsumerState<_ProductSheet> {
  /// optionId → valueIds المختارة
  final Map<int, List<int>> _selected = {};
  final _notes = TextEditingController();
  double _quantity = 1;

  Product get p => widget.product;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  List<CartOption> get _chosen => [
        for (final o in p.options)
          for (final v in o.values)
            if (_selected[o.id]?.contains(v.id) ?? false)
              CartOption(valueId: v.id, optionName: o.name, valueName: v.name, price: v.price),
      ];

  double get _unitTotal => p.price + _chosen.fold<double>(0, (s, o) => s + o.price);

  ProductOption? get _missingRequired =>
      p.options.where((o) => o.isRequired && (_selected[o.id]?.isEmpty ?? true)).firstOrNull;

  void _toggle(ProductOption o, OptionValue v) {
    final current = _selected[o.id] ?? [];
    setState(() {
      if (!o.isMultiple) {
        _selected[o.id] = [v.id];
      } else if (current.contains(v.id)) {
        _selected[o.id] = [...current]..remove(v.id);
      } else if (o.maxSelections == null || current.length < o.maxSelections!) {
        _selected[o.id] = [...current, v.id];
      } else {
        showMessage(context, 'أقصى اختيار في "${o.name}" هو ${o.maxSelections}');
      }
    });
  }

  Future<void> _add() async {
    if (!await confirmStoreSwitch(context, ref, widget.store)) return;
    ref.read(cartProvider.notifier).add(
          store: widget.store,
          line: CartLine(
            productId: p.id,
            name: p.name,
            image: p.image,
            unitPrice: p.price,
            options: _chosen,
            quantity: _quantity,
            step: p.quantityStep,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final canOrder = p.isAvailable && widget.store.isOpenNow;
    final missing = _missingRequired;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  if (p.image != null) ...[
                    NetImage(p.image, height: 200, width: double.infinity, radius: 16),
                    const SizedBox(height: 16),
                  ],
                  Text(p.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                  if (p.description?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 6),
                    Text(p.description!, style: const TextStyle(color: AppColors.muted)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(money(p.price), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      if (p.unit != 'piece') Text(' / ${p.unitLabel}', style: const TextStyle(color: AppColors.muted)),
                      if (p.comparePrice != null && p.comparePrice! > p.price) ...[
                        const SizedBox(width: 8),
                        Text(
                          money(p.comparePrice!),
                          style: const TextStyle(color: AppColors.muted, decoration: TextDecoration.lineThrough),
                        ),
                      ],
                    ],
                  ),
                  for (final o in p.options) _OptionGroup(option: o, selected: _selected[o.id] ?? const [], onTap: _toggle),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notes,
                    maxLength: 255,
                    decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', hintText: 'مثال: بدون بصل', counterText: ''),
                  ),
                ],
              ),
            ),
            const Divider(),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    QuantityStepper(
                      value: _quantity,
                      step: p.quantityStep,
                      min: p.quantityStep,
                      onChanged: (v) => setState(() => _quantity = v),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: canOrder && missing == null ? _add : null,
                        child: Text(
                          !widget.store.isOpenNow
                              ? 'المتجر مغلق الآن'
                              : !p.isAvailable
                                  ? 'غير متوفر حاليًا'
                                  : missing != null
                                      ? 'اختر ${missing.name}'
                                      : 'أضف للسلة · ${money(_unitTotal * _quantity)}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionGroup extends StatelessWidget {
  const _OptionGroup({required this.option, required this.selected, required this.onTap});

  final ProductOption option;
  final List<int> selected;
  final void Function(ProductOption, OptionValue) onTap;

  @override
  Widget build(BuildContext context) {
    final hint = option.isMultiple
        ? (option.maxSelections != null ? 'اختر حتى ${option.maxSelections}' : 'اختر ما تريد')
        : 'اختر واحدًا';

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(option.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (option.isRequired ? AppColors.primary : AppColors.muted).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  option.isRequired ? 'مطلوب' : 'اختياري',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: option.isRequired ? AppColors.primary : AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          Text(hint, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const SizedBox(height: 4),
          for (final v in option.values)
            InkWell(
              onTap: v.isAvailable ? () => onTap(option, v) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      option.isMultiple
                          ? (selected.contains(v.id) ? Icons.check_box : Icons.check_box_outline_blank)
                          : (selected.contains(v.id) ? Icons.radio_button_checked : Icons.radio_button_off),
                      color: v.isAvailable ? (selected.contains(v.id) ? AppColors.primary : AppColors.muted) : AppColors.line,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          v.isAvailable ? v.name : '${v.name} (غير متوفر)',
                          style: TextStyle(color: v.isAvailable ? AppColors.ink : AppColors.muted),
                        ),
                      ),
                    ),
                    if (v.price > 0)
                      Text('+ ${money(v.price)}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
