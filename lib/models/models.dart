import 'package:latlong2/latlong.dart';

import '../core/config.dart';

double _d(Object? v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
double? _dn(Object? v) => v == null ? null : _d(v);
int? _in(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
DateTime? _dt(Object? v) => v == null ? null : DateTime.tryParse('$v');
List<Map<String, dynamic>> _list(Object? v) => v is List ? v.cast<Map<String, dynamic>>() : const [];

class User {
  User({required this.id, required this.name, required this.phone, this.email});

  final int id;
  final String name;
  final String phone;
  final String? email;

  factory User.fromJson(Map<String, dynamic> j) =>
      User(id: j['id'], name: j['name'] ?? '', phone: j['phone'] ?? '', email: j['email']);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone, 'email': email};
}

class StoreType {
  StoreType({required this.id, required this.name, required this.slug, this.icon, this.supportsPrescriptions = false});

  final int id;
  final String name;
  final String slug;
  final String? icon;
  final bool supportsPrescriptions;

  factory StoreType.fromJson(Map<String, dynamic> j) => StoreType(
        id: j['id'],
        name: j['name'] ?? '',
        slug: j['slug'] ?? '',
        icon: fixMediaUrl(j['icon']),
        supportsPrescriptions: j['supports_prescriptions'] == true,
      );
}

class Banner {
  Banner({required this.id, this.title, this.image, this.storeId, this.storeTypeId, this.url});

  final int id;
  final String? title;
  final String? image;
  final int? storeId;
  final int? storeTypeId;
  final String? url;

  factory Banner.fromJson(Map<String, dynamic> j) => Banner(
        id: j['id'],
        title: j['title'],
        image: fixMediaUrl(j['image']),
        storeId: _in(j['store_id']),
        storeTypeId: _in(j['store_type_id']),
        url: j['url'],
      );
}

class OptionValue {
  OptionValue({required this.id, required this.name, required this.price, required this.isAvailable});

  final int id;
  final String name;
  final double price;
  final bool isAvailable;

  factory OptionValue.fromJson(Map<String, dynamic> j) =>
      OptionValue(id: j['id'], name: j['name'] ?? '', price: _d(j['price']), isAvailable: j['is_available'] != false);
}

class ProductOption {
  ProductOption({
    required this.id,
    required this.name,
    required this.isMultiple,
    required this.isRequired,
    required this.maxSelections,
    required this.values,
  });

  final int id;
  final String name;
  final bool isMultiple;
  final bool isRequired;

  /// null = بلا حد (للاختيار المتعدد).
  final int? maxSelections;
  final List<OptionValue> values;

  factory ProductOption.fromJson(Map<String, dynamic> j) => ProductOption(
        id: j['id'],
        name: j['name'] ?? '',
        isMultiple: j['type'] == 'multiple',
        isRequired: j['is_required'] == true,
        maxSelections: _in(j['max_selections']),
        values: _list(j['values']).map(OptionValue.fromJson).toList(),
      );
}

class Product {
  Product({
    required this.id,
    required this.storeId,
    required this.name,
    this.description,
    this.image,
    required this.price,
    this.comparePrice,
    required this.unit,
    required this.unitLabel,
    required this.isAvailable,
    required this.options,
  });

  final int id;
  final int storeId;
  final String name;
  final String? description;
  final String? image;
  final double price;
  final double? comparePrice;
  final String unit;
  final String unitLabel;
  final bool isAvailable;
  final List<ProductOption> options;

  /// المنتجات بالوزن تقبل كسور (السيرفر يسمح من 0.1).
  bool get isWeighed => unit == 'kg' || unit == 'liter';
  double get quantityStep => isWeighed ? 0.25 : 1;

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'],
        storeId: j['store_id'],
        name: j['name'] ?? '',
        description: j['description'],
        image: fixMediaUrl(j['image']),
        price: _d(j['price']),
        comparePrice: _dn(j['compare_price']),
        unit: j['unit'] ?? 'piece',
        unitLabel: j['unit_label'] ?? '',
        isAvailable: j['is_available'] != false,
        options: _list(j['options']).map(ProductOption.fromJson).toList(),
      );
}

class MenuCategory {
  MenuCategory({required this.id, required this.name, required this.products});

  final int id;
  final String name;
  final List<Product> products;

  factory MenuCategory.fromJson(Map<String, dynamic> j) => MenuCategory(
        id: j['id'],
        name: j['name'] ?? '',
        products: _list(j['products']).map(Product.fromJson).toList(),
      );
}

class StoreHour {
  StoreHour({required this.dayOfWeek, required this.day, this.opensAt, this.closesAt, required this.isClosed});

  /// 0 = الأحد ... 6 = السبت
  final int dayOfWeek;
  final String day;
  final String? opensAt;
  final String? closesAt;
  final bool isClosed;

  factory StoreHour.fromJson(Map<String, dynamic> j) => StoreHour(
        dayOfWeek: _in(j['day_of_week']) ?? 0,
        day: j['day'] ?? '',
        opensAt: j['opens_at'],
        closesAt: j['closes_at'],
        isClosed: j['is_closed'] == true,
      );
}

class Store {
  Store({
    required this.id,
    required this.name,
    this.description,
    this.logo,
    this.cover,
    this.phone,
    this.address,
    required this.lat,
    required this.lng,
    this.storeType,
    required this.rating,
    required this.ratingCount,
    required this.minOrderAmount,
    required this.avgPrepMinutes,
    required this.isOpenNow,
    required this.isFeatured,
    this.distanceKm,
    this.deliveryFee,
    this.estimatedMinutes,
    this.hours = const [],
    this.categories = const [],
  });

  final int id;
  final String name;
  final String? description;
  final String? logo;
  final String? cover;
  final String? phone;
  final String? address;
  final double lat;
  final double lng;
  final StoreType? storeType;
  final double rating;
  final int ratingCount;
  final double minOrderAmount;
  final int avgPrepMinutes;
  final bool isOpenNow;
  final bool isFeatured;
  final double? distanceKm;
  final double? deliveryFee;
  final int? estimatedMinutes;
  final List<StoreHour> hours;
  final List<MenuCategory> categories;

  LatLng get point => LatLng(lat, lng);

  factory Store.fromJson(Map<String, dynamic> j) => Store(
        id: j['id'],
        name: j['name'] ?? '',
        description: j['description'],
        logo: fixMediaUrl(j['logo']),
        cover: fixMediaUrl(j['cover']),
        phone: j['phone'],
        address: j['address'],
        lat: _d(j['lat']),
        lng: _d(j['lng']),
        storeType: j['store_type'] is Map ? StoreType.fromJson(j['store_type']) : null,
        rating: _d(j['rating']),
        ratingCount: _in(j['rating_count']) ?? 0,
        minOrderAmount: _d(j['min_order_amount']),
        avgPrepMinutes: _in(j['avg_prep_minutes']) ?? 0,
        isOpenNow: j['is_open_now'] == true,
        isFeatured: j['is_featured'] == true,
        distanceKm: _dn(j['distance_km']),
        deliveryFee: _dn(j['delivery_fee']),
        estimatedMinutes: _in(j['estimated_minutes']),
        hours: _list(j['hours']).map(StoreHour.fromJson).toList(),
        categories: _list(j['categories']).map(MenuCategory.fromJson).toList(),
      );
}

class HomeData {
  HomeData({
    required this.inServiceArea,
    required this.storeTypes,
    required this.banners,
    required this.featured,
    required this.nearby,
  });

  final bool inServiceArea;
  final List<StoreType> storeTypes;
  final List<Banner> banners;
  final List<Store> featured;
  final List<Store> nearby;

  factory HomeData.fromJson(Map<String, dynamic> j) => HomeData(
        inServiceArea: j['in_service_area'] != false,
        storeTypes: _list(j['store_types']).map(StoreType.fromJson).toList(),
        banners: _list(j['banners']).map(Banner.fromJson).toList(),
        featured: _list(j['featured']).map(Store.fromJson).toList(),
        nearby: _list(j['nearby']).map(Store.fromJson).toList(),
      );
}

class Address {
  Address({
    this.id,
    this.label,
    required this.addressLine,
    this.building,
    this.floor,
    this.apartment,
    this.landmark,
    this.phone,
    required this.lat,
    required this.lng,
    this.zoneId,
    this.isDefault = false,
    this.fullText,
  });

  final int? id;
  final String? label;
  final String addressLine;
  final String? building;
  final String? floor;
  final String? apartment;
  final String? landmark;
  final String? phone;
  final double lat;
  final double lng;
  final int? zoneId;
  final bool isDefault;
  final String? fullText;

  LatLng get point => LatLng(lat, lng);
  String get title => (label?.isNotEmpty ?? false) ? label! : addressLine;
  String get details => fullText ?? addressLine;

  /// خارج مناطق الخدمة لو السيرفر لم يجد منطقة للنقطة.
  bool get outsideZones => zoneId == null;

  factory Address.fromJson(Map<String, dynamic> j) => Address(
        id: j['id'],
        label: j['label'],
        addressLine: j['address_line'] ?? '',
        building: j['building'],
        floor: j['floor'],
        apartment: j['apartment'],
        landmark: j['landmark'],
        phone: j['phone'],
        lat: _d(j['lat']),
        lng: _d(j['lng']),
        zoneId: _in(j['zone_id']),
        isDefault: j['is_default'] == true,
        fullText: j['full_text'],
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'address_line': addressLine,
        'building': building,
        'floor': floor,
        'apartment': apartment,
        'landmark': landmark,
        'phone': phone,
        'lat': lat,
        'lng': lng,
        'is_default': isDefault,
      };
}

class QuoteItem {
  QuoteItem({required this.name, required this.quantity, required this.total, required this.optionsText, this.notes});

  final String name;
  final double quantity;
  final double total;
  final String optionsText;
  final String? notes;

  factory QuoteItem.fromJson(Map<String, dynamic> j) => QuoteItem(
        name: j['name'] ?? '',
        quantity: _d(j['quantity']),
        total: _d(j['total']),
        optionsText: _list(j['options']).map((o) => o['value'] ?? '').where((v) => '$v'.isNotEmpty).join('، '),
        notes: j['notes'],
      );
}

/// ناتج /checkout/preview — نفس حساب السيرفر عند إنشاء الطلب.
class Quote {
  Quote({
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.serviceFee,
    required this.discount,
    required this.total,
    required this.distanceKm,
    required this.minOrderAmount,
    this.coupon,
    this.couponError,
  });

  final List<QuoteItem> items;
  final double subtotal;
  final double deliveryFee;
  final double serviceFee;
  final double discount;
  final double total;
  final double distanceKm;
  final double minOrderAmount;
  final String? coupon;
  final String? couponError;

  bool get belowMinimum => subtotal < minOrderAmount;

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        items: _list(j['items']).map(QuoteItem.fromJson).toList(),
        subtotal: _d(j['subtotal']),
        deliveryFee: _d(j['delivery_fee']),
        serviceFee: _d(j['service_fee']),
        discount: _d(j['discount']),
        total: _d(j['total']),
        distanceKm: _d(j['distance_km']),
        minOrderAmount: _d(j['min_order_amount']),
        coupon: j['coupon'],
        couponError: j['coupon_error'],
      );
}

class Driver {
  Driver({required this.id, this.name, this.phone, this.avatar, this.vehicle, this.plate, required this.rating, this.lat, this.lng});

  final int id;
  final String? name;
  final String? phone;
  final String? avatar;
  final String? vehicle;
  final String? plate;
  final double rating;
  final double? lat;
  final double? lng;

  LatLng? get point => lat != null && lng != null ? LatLng(lat!, lng!) : null;

  factory Driver.fromJson(Map<String, dynamic> j) => Driver(
        id: j['id'],
        name: j['name'],
        phone: j['phone'],
        avatar: fixMediaUrl(j['avatar']),
        vehicle: j['vehicle_type_label'],
        plate: j['vehicle_plate'],
        rating: _d(j['rating']),
        lat: _dn(j['lat']),
        lng: _dn(j['lng']),
      );
}

enum OrderStatus {
  pending('بانتظار المتجر'),
  accepted('المتجر قبل الطلب'),
  preparing('جاري التجهيز'),
  ready('جاهز للاستلام'),
  pickedUp('في الطريق إليك'),
  delivered('تم التوصيل'),
  cancelled('ملغي');

  const OrderStatus(this.label);
  final String label;

  static OrderStatus parse(String? s) => switch (s) {
        'accepted' => accepted,
        'preparing' => preparing,
        'ready' => ready,
        'picked_up' => pickedUp,
        'delivered' => delivered,
        'cancelled' => cancelled,
        _ => pending,
      };

  bool get isActive => this != delivered && this != cancelled;

  /// خطوات التتبع بالترتيب (بدون الإلغاء).
  static const steps = [pending, accepted, preparing, ready, pickedUp, delivered];
}

class OrderItem {
  OrderItem({required this.name, required this.quantity, required this.total, required this.optionsText, this.notes});

  final String name;
  final double quantity;
  final double total;
  final String optionsText;
  final String? notes;

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        name: j['name'] ?? '',
        quantity: _d(j['quantity']),
        total: _d(j['total']),
        optionsText: _list(j['options']).map((o) => o['value'] ?? '').where((v) => '$v'.isNotEmpty).join('، '),
        notes: j['notes'],
      );
}

class Order {
  Order({
    required this.id,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.isLate,
    this.store,
    this.driver,
    this.deliveryAddress,
    this.deliveryPoint,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.serviceFee,
    required this.discount,
    required this.total,
    this.deliveryCode,
    required this.paymentMethod,
    required this.paymentStatus,
    this.notes,
    this.estimatedDeliveryAt,
    this.cancelReason,
    required this.canCancel,
    required this.canReview,
    required this.timeline,
    this.createdAt,
  });

  final int id;
  final String number;
  final OrderStatus status;
  final String statusLabel;
  final bool isLate;
  final Store? store;
  final Driver? driver;
  final String? deliveryAddress;
  final LatLng? deliveryPoint;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double serviceFee;
  final double discount;
  final double total;
  final String? deliveryCode;
  final String paymentMethod;
  final String paymentStatus;
  final String? notes;
  final DateTime? estimatedDeliveryAt;
  final String? cancelReason;
  final bool canCancel;
  final bool canReview;
  final Map<String, DateTime?> timeline;
  final DateTime? createdAt;

  /// وقت الوصول لكل خطوة من الـ timeline.
  DateTime? stepTime(OrderStatus s) => timeline[switch (s) {
        OrderStatus.pending => 'created_at',
        OrderStatus.accepted => 'accepted_at',
        OrderStatus.preparing => 'preparing_at',
        OrderStatus.ready => 'ready_at',
        OrderStatus.pickedUp => 'picked_up_at',
        OrderStatus.delivered => 'delivered_at',
        OrderStatus.cancelled => 'cancelled_at',
      }];

  bool get awaitingCardPayment => paymentMethod == 'card' && paymentStatus != 'paid' && status.isActive;

  factory Order.fromJson(Map<String, dynamic> j) {
    final delivery = (j['delivery'] as Map?)?.cast<String, dynamic>() ?? const {};
    final lat = _dn(delivery['lat']);
    final lng = _dn(delivery['lng']);
    final timeline = (j['timeline'] as Map?)?.cast<String, dynamic>() ?? const {};

    return Order(
      id: j['id'],
      number: '${j['number'] ?? j['id']}',
      status: OrderStatus.parse(j['status']),
      statusLabel: j['status_label'] ?? '',
      isLate: j['is_late'] == true,
      store: j['store'] is Map ? Store.fromJson(j['store']) : null,
      driver: j['driver'] is Map ? Driver.fromJson(j['driver']) : null,
      deliveryAddress: delivery['address'],
      deliveryPoint: lat != null && lng != null ? LatLng(lat, lng) : null,
      items: _list(j['items']).map(OrderItem.fromJson).toList(),
      subtotal: _d(j['subtotal']),
      deliveryFee: _d(j['delivery_fee']),
      serviceFee: _d(j['service_fee']),
      discount: _d(j['discount']),
      total: _d(j['total']),
      deliveryCode: j['delivery_code']?.toString(),
      paymentMethod: j['payment_method'] ?? 'cash',
      paymentStatus: j['payment_status'] ?? '',
      notes: j['notes'],
      estimatedDeliveryAt: _dt(j['estimated_delivery_at']),
      cancelReason: j['cancel_reason'],
      canCancel: j['can_cancel'] == true,
      canReview: j['can_review'] == true,
      timeline: timeline.map((k, v) => MapEntry(k, _dt(v))),
      createdAt: _dt(j['created_at']),
    );
  }
}
