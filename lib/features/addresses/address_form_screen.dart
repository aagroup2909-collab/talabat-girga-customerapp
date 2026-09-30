import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/models.dart';
import '../../state/location.dart';

/// إضافة / تعديل عنوان: حرّك الخريطة لتضع الدبوس على البيت ثم اكتب التفاصيل.
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.address});

  final Address? address;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  static const _labels = ['البيت', 'الشغل', 'آخر'];

  final _map = MapController();
  final _formKey = GlobalKey<FormState>();
  late final _line = TextEditingController(text: widget.address?.addressLine);
  late final _building = TextEditingController(text: widget.address?.building);
  late final _floor = TextEditingController(text: widget.address?.floor);
  late final _apartment = TextEditingController(text: widget.address?.apartment);
  late final _landmark = TextEditingController(text: widget.address?.landmark);
  late final _phone = TextEditingController(text: widget.address?.phone);
  late String _label = widget.address?.label ?? _labels.first;
  late bool _isDefault = widget.address?.isDefault ?? false;

  late LatLng _center = widget.address?.point ?? AppConfig.girgaCenter;
  bool _moving = false;
  bool _locating = false;
  bool _saving = false;
  Map<String, List<String>> _errors = {};

  bool get _isEdit => widget.address?.id != null;

  @override
  void initState() {
    super.initState();
    // عنوان جديد: ابدأ من موقع الجهاز.
    if (!_isEdit) WidgetsBinding.instance.addPostFrameCallback((_) => _goToMyLocation());
  }

  @override
  void dispose() {
    for (final c in [_line, _building, _floor, _apartment, _landmark, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    final here = await getDeviceLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (here == null) {
      showMessage(context, 'فعّل خدمة الموقع أو حرّك الخريطة يدويًا.');
      return;
    }
    _map.move(here, 17);
    setState(() => _center = here);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errors = {};
    });

    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

    try {
      final saved = await ref.read(addressesProvider.notifier).save(Address(
            id: widget.address?.id,
            label: _label,
            addressLine: _line.text.trim(),
            building: opt(_building),
            floor: opt(_floor),
            apartment: opt(_apartment),
            landmark: opt(_landmark),
            phone: opt(_phone),
            lat: _center.latitude,
            lng: _center.longitude,
            isDefault: _isDefault,
          ));
      // العنوان الجديد يصبح عنوان التوصيل الحالي.
      if (!_isEdit) ref.read(selectedAddressIdProvider.notifier).select(saved.id!);
      if (mounted) context.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.errors);
      showError(context, e);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل العنوان' : 'عنوان جديد')),
      body: Column(
        children: [
          SizedBox(
            height: 300,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 16,
                    onPositionChanged: (camera, hasGesture) {
                      _center = camera.center;
                      if (hasGesture && !_moving) setState(() => _moving = true);
                    },
                    onMapEvent: (e) {
                      if (e is MapEventMoveEnd || e is MapEventFlingAnimationEnd) {
                        setState(() => _moving = false);
                      }
                    },
                  ),
                  children: [
                    TileLayer(urlTemplate: AppConfig.tileUrl, userAgentPackageName: AppConfig.mapUserAgent),
                    const SimpleAttributionWidget(source: Text('OpenStreetMap')),
                  ],
                ),
                // الدبوس ثابت في منتصف الخريطة؛ الخريطة هي اللي بتتحرك.
                IgnorePointer(
                  child: Center(
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 150),
                      offset: Offset(0, _moving ? -0.7 : -0.5),
                      child: const Icon(Icons.location_on, size: 48, color: AppColors.primary),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        _moving ? 'حرّك الخريطة...' : 'ضع الدبوس على مكان التوصيل بالضبط',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'my-location',
                    onPressed: _locating ? null : _goToMyLocation,
                    backgroundColor: Colors.white,
                    child: _locating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final l in _labels)
                        ChoiceChip(label: Text(l), selected: _label == l, onSelected: (_) => setState(() => _label = l)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _line,
                    decoration: InputDecoration(
                      labelText: 'الشارع / المنطقة *',
                      errorText: _errors['address_line']?.first,
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب اسم الشارع أو المنطقة' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _building, decoration: const InputDecoration(labelText: 'العمارة'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: _floor, decoration: const InputDecoration(labelText: 'الدور'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: _apartment, decoration: const InputDecoration(labelText: 'الشقة'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _landmark,
                    decoration: const InputDecoration(labelText: 'علامة مميزة', hintText: 'مثال: بجوار مسجد ...'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'رقم تليفون للتوصيل (اختياري)'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('العنوان الافتراضي'),
                    value: _isDefault,
                    onChanged: (v) => setState(() => _isDefault = v),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'جاري الحفظ...' : 'حفظ العنوان'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
