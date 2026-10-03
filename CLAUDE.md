# Talabat Girga — customer app (Flutter)

Customer mobile app for طلبات جرجا, a delivery platform in Girga, Egypt. More than one developer works on this repo, each with their own Claude Code session: `git pull` before starting, commit and push only your own focused changes.

Read `README.md` (run commands, auth flow, structure). The API reference is `backend/docs/API.md` in the backend repo (`talabat-girga-backend`); if both repos are cloned side by side it is at `../../backend/docs/API.md`.

## Rules for this codebase

- **Arabic-first, RTL.** Every user-facing string is Egyptian Arabic. Numbers (phone, codes, prices) use Western digits. Phone and code fields are LTR inside the RTL UI; put their error text through `rtlFieldError` (`lib/features/auth/auth_widgets.dart`) so punctuation sits on the right side.
- **All API calls go through `lib/data/repository.dart`.** Errors arrive as `ApiException` (`lib/core/api.dart`): use `fieldError('phone')` etc. for 422 field errors, `code` for 403/409 codes. 429 is shown as an Arabic "too many attempts" message.
- **The server is the source of truth for money:** the cart shows `/checkout/preview`, never a client-side total, before placing an order.
- Models in `lib/models/models.dart` are hand-written to match the Laravel Resources; when the API changes, update the model and the README.
- State: Riverpod 3 (`Notifier`/`AsyncNotifier`, no codegen). Navigation: go_router; auth redirect in `lib/app.dart`. Any 401 clears the token and goes to `/login`.
- Match the existing style: small screens in `lib/features/<area>/`, shared widgets in `lib/core/widgets.dart`, theme tokens in `lib/core/theme.dart` (orange `#F2671F`).

## Behaviour that looks odd but is intended

- Registration codes are sent manually over WhatsApp and stay valid 30 minutes. The app remembers phone + name + send time (never the password) and does not request a new code for the same number in that window, because a new request cancels the code staff already sent.
- Order tracking polls every 10 seconds; the hosting has no WebSockets.
- Maps use flutter_map + OpenStreetMap tiles. With `initialCameraFit` tiles do not load until the first move, so the camera is fitted in `onMapReady`.
- Icon buttons inside text fields are wrapped in `ExcludeFocus` so keyboard "Next" moves to the next field.

## Run and test

- Production API is `https://talabat.ahgroup.online/api/v1`. Local default is `http://10.0.2.2:9123/api/v1` (emulator).
- Real phone over USB: `adb reverse tcp:9123 tcp:9123` and `--dart-define=API_BASE_URL=http://127.0.0.1:9123/api/v1`.
- Local demo customer: 01500000001, password from `DemoSeeder` in the backend. Registration code locally = `OTP_FIXED_CODE` in the backend `.env`.
- Never create test accounts or request registration codes on production: on the live server a real person has to send each code by hand.
- Before committing: `flutter analyze` (must be clean) and `flutter test`.
- Release APK: `flutter build apk --release --dart-define=API_BASE_URL=https://talabat.ahgroup.online/api/v1`. It is still signed with the debug key; the upload keystore and `key.properties` are never committed — ask the project owner.
