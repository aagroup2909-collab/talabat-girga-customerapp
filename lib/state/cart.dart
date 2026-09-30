import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../models/models.dart';

class CartOption {
  CartOption({required this.valueId, required this.optionName, required this.valueName, required this.price});

  final int valueId;
  final String optionName;
  final String valueName;
  final double price;

  factory CartOption.fromJson(Map<String, dynamic> j) =>
      CartOption(valueId: j['v'], optionName: j['o'], valueName: j['n'], price: (j['p'] as num).toDouble());

  Map<String, dynamic> toJson() => {'v': valueId, 'o': optionName, 'n': valueName, 'p': price};
}

class CartLine {
  CartLine({
    required this.productId,
    required this.name,
    this.image,
    required this.unitPrice,
    required this.options,
    required this.quantity,
    required this.step,
    this.notes,
  });

  final int productId;
  final String name;
  final String? image;
  final double unitPrice;
  final List<CartOption> options;
  final double quantity;
  final double step;
  final String? notes;

  /// نفس المنتج بنفس الإضافات والملاحظات = سطر واحد.
  String get key => '$productId|${(options.map((o) => o.valueId).toList()..sort()).join(',')}|${notes ?? ''}';

  double get optionsPrice => options.fold(0, (s, o) => s + o.price);
  double get total => (unitPrice + optionsPrice) * quantity;
  String get optionsText => options.map((o) => o.valueName).join('، ');

  CartLine copyWith({double? quantity}) => CartLine(
        productId: productId,
        name: name,
        image: image,
        unitPrice: unitPrice,
        options: options,
        quantity: quantity ?? this.quantity,
        step: step,
        notes: notes,
      );

  Map<String, dynamic> toRequest() => {
        'product_id': productId,
        'quantity': quantity,
        if (options.isNotEmpty) 'options': options.map((o) => o.valueId).toList(),
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };

  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
        productId: j['product_id'],
        name: j['name'],
        image: j['image'],
        unitPrice: (j['unit_price'] as num).toDouble(),
        options: (j['options'] as List).map((o) => CartOption.fromJson(o)).toList(),
        quantity: (j['quantity'] as num).toDouble(),
        step: (j['step'] as num?)?.toDouble() ?? 1,
        notes: j['notes'],
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'name': name,
        'image': image,
        'unit_price': unitPrice,
        'options': options.map((o) => o.toJson()).toList(),
        'quantity': quantity,
        'step': step,
        'notes': notes,
      };
}

/// السلة من متجر واحد فقط (السيرفر ينشئ الطلب لمتجر واحد).
class Cart {
  const Cart({this.storeId, this.storeName, this.lines = const []});

  final int? storeId;
  final String? storeName;
  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;
  double get subtotal => lines.fold(0, (s, l) => s + l.total);
  int get count => lines.fold(0, (s, l) => s + (l.step < 1 ? 1 : l.quantity.round()));

  double quantityOf(int productId) =>
      lines.where((l) => l.productId == productId).fold(0, (s, l) => s + l.quantity);

  List<Map<String, dynamic>> toRequestItems() => lines.map((l) => l.toRequest()).toList();

  Map<String, dynamic> toJson() => {
        'store_id': storeId,
        'store_name': storeName,
        'lines': lines.map((l) => l.toJson()).toList(),
      };

  factory Cart.fromJson(Map<String, dynamic> j) => Cart(
        storeId: j['store_id'],
        storeName: j['store_name'],
        lines: (j['lines'] as List).map((l) => CartLine.fromJson(l)).toList(),
      );
}

class CartController extends Notifier<Cart> {
  static const _key = 'cart_v1';

  @override
  Cart build() {
    final raw = ref.watch(prefsProvider).getString(_key);
    if (raw == null) return const Cart();
    try {
      return Cart.fromJson(jsonDecode(raw));
    } catch (_) {
      return const Cart();
    }
  }

  /// هل الإضافة ستستبدل سلة متجر آخر؟
  bool conflictsWith(int storeId) => !state.isEmpty && state.storeId != storeId;

  void add({required Store store, required CartLine line}) {
    final lines = conflictsWith(store.id) ? <CartLine>[] : [...state.lines];
    final i = lines.indexWhere((l) => l.key == line.key);
    if (i >= 0) {
      lines[i] = lines[i].copyWith(quantity: lines[i].quantity + line.quantity);
    } else {
      lines.add(line);
    }
    _set(Cart(storeId: store.id, storeName: store.name, lines: lines));
  }

  void changeQuantity(CartLine line, double delta) {
    final lines = [...state.lines];
    final i = lines.indexWhere((l) => l.key == line.key);
    if (i < 0) return;
    final q = double.parse((lines[i].quantity + delta).toStringAsFixed(2));
    if (q <= 0) {
      lines.removeAt(i);
    } else {
      lines[i] = lines[i].copyWith(quantity: q);
    }
    _set(lines.isEmpty ? const Cart() : Cart(storeId: state.storeId, storeName: state.storeName, lines: lines));
  }

  void clear() => _set(const Cart());

  void _set(Cart cart) {
    state = cart;
    ref.read(prefsProvider).setString(_key, jsonEncode(cart.toJson()));
  }
}

final cartProvider = NotifierProvider<CartController, Cart>(CartController.new);
