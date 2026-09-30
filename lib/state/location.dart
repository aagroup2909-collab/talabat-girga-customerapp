import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../data/repository.dart';
import '../models/models.dart';
import 'auth.dart';

/// عناوين العميل من السيرفر.
class AddressesController extends AsyncNotifier<List<Address>> {
  @override
  Future<List<Address>> build() async {
    final user = ref.watch(authProvider.select((s) => s.user?.id));
    if (user == null) return [];
    return ref.read(repositoryProvider).addresses();
  }

  /// لا ننتظر إعادة تحميل القائمة حتى لا تتأخر الشاشة.
  Future<Address> save(Address address) async {
    final saved = await ref.read(repositoryProvider).saveAddress(address);
    ref.invalidateSelf();
    return saved;
  }

  Future<void> remove(int id) async {
    await ref.read(repositoryProvider).deleteAddress(id);
    ref.invalidateSelf();
    await future;
  }
}

final addressesProvider = AsyncNotifierProvider<AddressesController, List<Address>>(AddressesController.new);

/// العنوان المختار للتوصيل (محفوظ على الجهاز).
class SelectedAddressController extends Notifier<int?> {
  static const _key = 'selected_address_id';

  @override
  int? build() => ref.watch(prefsProvider).getInt(_key);

  void select(int id) {
    ref.read(prefsProvider).setInt(_key, id);
    state = id;
  }
}

final selectedAddressIdProvider = NotifierProvider<SelectedAddressController, int?>(SelectedAddressController.new);

/// العنوان الحالي: المختار ← الافتراضي ← الأول.
final currentAddressProvider = Provider<Address?>((ref) {
  final list = ref.watch(addressesProvider).value ?? const [];
  if (list.isEmpty) return null;
  final id = ref.watch(selectedAddressIdProvider);
  return list.where((a) => a.id == id).firstOrNull ?? list.where((a) => a.isDefault).firstOrNull ?? list.first;
});

/// موقع الجهاز (أو null لو مفيش صلاحية / الخدمة مقفولة).
Future<LatLng?> getDeviceLocation({bool askPermission = true}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && askPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 5)),
    );
    return LatLng(pos.latitude, pos.longitude);
  } catch (_) {
    return Geolocator.getLastKnownPosition().then((p) => p == null ? null : LatLng(p.latitude, p.longitude)).catchError((_) => null);
  }
}

/// للرئيسية: لا ننتظر الموقع أكثر من 8 ثوانٍ (نرجع لمركز جرجا بدل شاشة تحميل طويلة).
final deviceLocationProvider = FutureProvider<LatLng?>(
  (ref) => getDeviceLocation().timeout(const Duration(seconds: 8), onTimeout: () => null),
);

/// النقطة التي نعرض المتاجر حولها: العنوان الحالي ← موقع الجهاز ← مركز جرجا.
final browseLocationProvider = FutureProvider<LatLng>((ref) async {
  await ref.watch(addressesProvider.future).catchError((_) => <Address>[]);
  final address = ref.watch(currentAddressProvider);
  if (address != null) return address.point;
  final device = await ref.watch(deviceLocationProvider.future);
  return device ?? AppConfig.girgaCenter;
});
