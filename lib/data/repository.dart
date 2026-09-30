import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../core/api.dart';
import '../models/models.dart';

class LoginResult {
  LoginResult({required this.token, required this.user, required this.needsProfile});
  final String token;
  final User user;
  final bool needsProfile;
}

class PlacedOrder {
  PlacedOrder({required this.order, this.paymentUrl});
  final Order order;
  final String? paymentUrl;
}

/// صفحة من نتائج مرقّمة (Laravel paginator).
class Paged<T> {
  Paged({required this.items, required this.hasMore});
  final List<T> items;
  final bool hasMore;
}

/// كل نداءات الـ API الخاصة بتطبيق العميل.
class Repository {
  Repository(this._api);

  final Api _api;

  List<Map<String, dynamic>> _data(dynamic res) => (res['data'] as List).cast<Map<String, dynamic>>();

  Paged<T> _paged<T>(dynamic res, T Function(Map<String, dynamic>) parse) {
    final meta = res['meta'] as Map?;
    return Paged(
      items: _data(res).map(parse).toList(),
      hasMore: meta != null && (meta['current_page'] as num) < (meta['last_page'] as num),
    );
  }

  // ---------- عام ----------
  Future<Map<String, dynamic>> config() async => (await _api.get('/config') as Map).cast<String, dynamic>();

  // ---------- الدخول ----------
  LoginResult _session(dynamic res) => LoginResult(
        token: res['token'],
        user: User.fromJson(res['user']),
        needsProfile: res['needs_profile'] == true,
      );

  /// 422 → errors.phone، 429 → محاولات كثيرة، 409 code=password_required → عميل قديم بلا كلمة مرور.
  Future<LoginResult> login(String phone, String password) async => _session(await _api.post('/auth/login', {
        'phone': phone,
        'password': password,
        'app': 'customer',
        'device_name': 'customer-app',
      }));

  /// الخطوة 1 من التسجيل: يرسل الكود ويرجع عدد الثواني قبل السماح بإعادة الإرسال.
  Future<int> sendRegistrationCode(String phone) async {
    final res = await _api.post('/auth/register/otp', {'phone': phone});
    return (res['retry_after'] as num?)?.toInt() ?? 60;
  }

  /// الخطوة 2: إنشاء الحساب (أو تحديد كلمة المرور لعميل قديم) والدخول مباشرة.
  Future<LoginResult> register({
    required String name,
    required String phone,
    required String password,
    required String code,
  }) async =>
      _session(await _api.post('/auth/register', {
        'name': name,
        'phone': phone,
        'password': password,
        'password_confirmation': password,
        'code': code,
        'device_name': 'customer-app',
      }));

  Future<void> changePassword({required String current, required String password}) => _api.post('/me/password', {
        'current_password': current,
        'password': password,
        'password_confirmation': password,
      });

  Future<void> logout() => _api.post('/auth/logout');

  Future<User> me() async => User.fromJson((await _api.get('/me'))['data']);

  Future<User> updateMe({required String name}) async => User.fromJson((await _api.post('/me', {'name': name}))['data']);

  // ---------- الكتالوج ----------
  Future<HomeData> home(LatLng at) async =>
      HomeData.fromJson(await _api.get('/customer/home', query: {'lat': at.latitude, 'lng': at.longitude}));

  Future<Paged<Store>> stores(
    LatLng at, {
    int? storeTypeId,
    String? search,
    String sort = 'nearest',
    bool openNow = false,
    int page = 1,
  }) async {
    final res = await _api.get('/customer/stores', query: {
      'lat': at.latitude,
      'lng': at.longitude,
      'store_type_id': storeTypeId,
      'search': search,
      'sort': sort,
      'open_now': openNow ? 1 : null,
      'page': page,
    });
    return _paged(res, Store.fromJson);
  }

  Future<Store> store(int id, LatLng? at) async => Store.fromJson((await _api.get('/customer/stores/$id', query: {
        'lat': at?.latitude,
        'lng': at?.longitude,
      }))['data']);

  // ---------- العناوين ----------
  Future<List<Address>> addresses() async => _data(await _api.get('/customer/addresses')).map(Address.fromJson).toList();

  Future<Address> saveAddress(Address a) async {
    final res = a.id == null
        ? await _api.post('/customer/addresses', a.toJson())
        : await _api.put('/customer/addresses/${a.id}', a.toJson());
    return Address.fromJson(res['data']);
  }

  Future<void> deleteAddress(int id) => _api.delete('/customer/addresses/$id');

  // ---------- الطلبات ----------
  Future<Quote> preview(Map<String, dynamic> body) async =>
      Quote.fromJson((await _api.post('/customer/checkout/preview', body))['data']);

  Future<PlacedOrder> placeOrder(Map<String, dynamic> body) async {
    final res = await _api.post('/customer/orders', body);
    return PlacedOrder(order: Order.fromJson(res['data']), paymentUrl: res['payment_url']);
  }

  Future<Paged<Order>> orders({required bool active, int page = 1}) async =>
      _paged(await _api.get('/customer/orders', query: {'filter': active ? 'active' : 'past', 'page': page}), Order.fromJson);

  Future<Order> order(int id) async => Order.fromJson((await _api.get('/customer/orders/$id'))['data']);

  Future<Order> cancelOrder(int id, {String? reason}) async =>
      Order.fromJson((await _api.post('/customer/orders/$id/cancel', {'reason': reason}))['data']);

  Future<String> paymentUrl(int id) async => (await _api.post('/customer/orders/$id/pay'))['payment_url'];

  Future<void> review(int id, {required int storeRating, int? driverRating, String? comment}) =>
      _api.post('/customer/orders/$id/review', {
        'store_rating': storeRating,
        'driver_rating': driverRating,
        'comment': comment,
      });
}

final repositoryProvider = Provider<Repository>((ref) => Repository(ref.watch(apiProvider)));

final appConfigProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.watch(repositoryProvider).config());
