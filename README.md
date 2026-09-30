# طلبات جرجا — تطبيق العميل (Flutter)

Customer mobile app for Talabat Girga (Flutter, Arabic-first RTL).

- Partner app (drivers + merchants): https://github.com/aagroup2909-collab/talabat-girga-partnerapp
- Backend and API reference: https://github.com/aagroup2909-collab/talabat-girga-backend — see `backend/docs/API.md` there.
- Production API: `https://talabat.ahgroup.online/api/v1`
- Run: `flutter pub get`, then the commands under "التشغيل" below.
- No secrets in this repo: keystores, `key.properties` and Firebase files are git-ignored; ask the project owner for them.

عربي أولًا (RTL). يتكلم مع الـ API الموجود في مستودع الـ backend (مرجع: `backend/docs/API.md`).

## التشغيل

```bash
# السيرفر المحلي على 9123 (من .claude/launch.json باسم backend)
flutter run                                   # محاكي أندرويد → http://10.0.2.2:9123/api/v1
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:9123/api/v1   # موبايل حقيقي على نفس الشبكة
```

موبايل حقيقي بكابل USB: `adb reverse tcp:9123 tcp:9123` ثم `--dart-define=API_BASE_URL=http://127.0.0.1:9123/api/v1`.

نسخة الإنتاج:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://talabat.ahgroup.online/api/v1
```

## الدخول والتسجيل

- الدخول: رقم الموبايل + كلمة المرور (`POST /auth/login`). العميل التجريبي محليًا: `01500000001` بكلمة مرور `DemoSeeder`.
- حساب جديد: البيانات ← `POST /auth/register/otp` ← شاشة الكود ← `POST /auth/register`. الكود محليًا هو `OTP_FIXED_CODE` في `backend/.env`؛ على السيرفر الحي يُرسل يدويًا على واتساب وصالح 30 دقيقة، لذلك التطبيق يحفظ (الرقم + الاسم + وقت الإرسال) على الجهاز ولا يطلب كودًا جديدًا لنفس الرقم خلال هذه المدة (الطلب الجديد يلغي الكود القديم). كلمة المرور لا تُحفظ.
- `409 password_required` عند الدخول (عميل قديم سجّل بالكود) ← نفس شاشة التسجيل بالرقم جاهز لتحديد كلمة المرور.
- نسيان كلمة المرور: لا يوجد استرجاع ذاتي — يعرض `support_phone` من `GET /config`.
- أي `401` يمسح التوكن ويرجع لشاشة الدخول.

## البنية

| المجلد | المحتوى |
|---|---|
| `lib/core/` | الإعدادات، عميل Dio + `ApiException` (رسائل السيرفر بالعربي)، الثيم، التنسيق، ويدجتس مشتركة |
| `lib/models/` | موديلات يدوية مطابقة لـ Resources في Laravel |
| `lib/data/repository.dart` | كل نداءات الـ API |
| `lib/state/` | Riverpod: الدخول، العناوين + موقع التصفح، السلة (محفوظة على الجهاز) |
| `lib/features/` | الشاشات: auth, home, store, cart, addresses, orders, account |

- **الموقع:** المتاجر تُعرض حول العنوان المختار ← موقع الجهاز ← مركز جرجا.
- **السلة:** من متجر واحد؛ الإضافة من متجر آخر تطلب تأكيد التفريغ. الحساب النهائي دائمًا من `/checkout/preview`.
- **التتبع:** polling كل 10 ثوانٍ طالما الطلب نشط. الخطوة التالية: Reverb على `private-order.{id}`.
- **الخرائط:** flutter_map + بلاطات OpenStreetMap (بدون مفتاح). للإنتاج يُفضّل مزود بلاطات مدفوع أو Google Maps لأن سياسة OSM لا تسمح بالاستخدام الكثيف.

## لم يُنفذ بعد

إشعارات FCM، Reverb، الروشتات (صيدليات)، إعادة الطلب، التذاكر، تعديل الاسم، خط عربي مضمّن (حاليًا خط النظام).
