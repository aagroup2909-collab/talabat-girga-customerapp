import 'package:flutter_test/flutter_test.dart';
import 'package:talabat_girga_customer/models/models.dart';
import 'package:talabat_girga_customer/state/cart.dart';

void main() {
  test('Store parses the API shape with menu options', () {
    final store = Store.fromJson({
      'id': 1,
      'name': 'مطعم',
      'lat': 26.34,
      'lng': 31.89,
      'rating': 0,
      'rating_count': 0,
      'min_order_amount': 50,
      'avg_prep_minutes': 20,
      'is_open_now': true,
      'is_featured': true,
      'delivery_fee': 15,
      'categories': [
        {
          'id': 1,
          'name': 'مشويات',
          'products': [
            {
              'id': 1,
              'store_id': 1,
              'name': 'نص فرخة',
              'price': 120,
              'unit': 'piece',
              'unit_label': 'قطعة',
              'is_available': true,
              'options': [
                {
                  'id': 1,
                  'name': 'الإضافات',
                  'type': 'multiple',
                  'is_required': false,
                  'max_selections': null,
                  'values': [
                    {'id': 1, 'name': 'أرز', 'price': 15, 'is_available': true},
                  ],
                },
              ],
            },
          ],
        },
      ],
    });

    final product = store.categories.single.products.single;
    expect(store.deliveryFee, 15.0);
    expect(product.options.single.isMultiple, isTrue);
    expect(product.options.single.maxSelections, isNull);
    expect(product.options.single.values.single.price, 15.0);
  });

  test('Cart line merges by product + options and builds the order payload', () {
    CartLine line(double q, List<int> opts) => CartLine(
          productId: 10,
          name: 'x',
          unitPrice: 100,
          options: [for (final o in opts) CartOption(valueId: o, optionName: 'o', valueName: 'v$o', price: 5)],
          quantity: q,
          step: 1,
        );

    expect(line(1, [2, 1]).key, line(3, [1, 2]).key);
    expect(line(1, [1]).key, isNot(line(1, [2]).key));
    expect(line(2, [1, 2]).total, 220);
    expect(line(2, [1]).toRequest(), {'product_id': 10, 'quantity': 2.0, 'options': [1]});
  });
}
