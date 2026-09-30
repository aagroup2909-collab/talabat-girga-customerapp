import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/repository.dart';
import '../../state/auth.dart';
import 'auth_widgets.dart';

class RegisterArgs {
  const RegisterArgs({this.phone = '', this.existingAccount = false});

  final String phone;

  /// عميل قديم سجّل بالكود (login رجّع 409 password_required): يحدد كلمة المرور مرة واحدة.
  final bool existingAccount;
}

/// كود أُرسل ولم يُستخدم بعد. نحفظه على الجهاز لأن الكود يوصل يدويًا على واتساب وصالح 30 دقيقة:
/// لو العميل خرج من التطبيق ورجع لا نطلب كودًا جديدًا (الطلب الجديد يلغي الكود القديم).
class _PendingCode {
  _PendingCode({required this.phone, required this.name, required this.sentAt, required this.retryAfter});

  static const _key = 'pending_registration';
  static const validity = Duration(minutes: 30);

  final String phone;
  final String name;
  final DateTime sentAt;
  final int retryAfter;

  bool get isFresh => DateTime.now().difference(sentAt) < validity;

  int get resendInSeconds {
    final left = retryAfter - DateTime.now().difference(sentAt).inSeconds;
    return left > 0 ? left : 0;
  }

  static _PendingCode? load(WidgetRef ref) {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final pending = _PendingCode(
        phone: j['phone'],
        name: j['name'],
        sentAt: DateTime.fromMillisecondsSinceEpoch(j['sent_at']),
        retryAfter: j['retry_after'],
      );
      return pending.isFresh ? pending : null;
    } catch (_) {
      return null;
    }
  }

  // كلمة المرور لا تُحفظ على الجهاز أبدًا.
  Future<void> save(WidgetRef ref) => ref.read(prefsProvider).setString(
        _key,
        jsonEncode({'phone': phone, 'name': name, 'sent_at': sentAt.millisecondsSinceEpoch, 'retry_after': retryAfter}),
      );

  static Future<void> clear(WidgetRef ref) => ref.read(prefsProvider).remove(_key);
}

/// حساب جديد: البيانات ← كود واتساب ← دخول مباشر.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.args = const RegisterArgs()});

  final RegisterArgs args;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();

  /// أخطاء الحقول (محلية أو من السيرفر بنفس المفاتيح).
  Map<String, String> _errors = {};
  bool _busy = false;
  bool _codeStep = false;
  _PendingCode? _pending;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _phone.text = widget.args.phone;

    final pending = _PendingCode.load(ref);
    if (pending != null && (widget.args.phone.isEmpty || widget.args.phone == pending.phone)) {
      _pending = pending;
      _phone.text = pending.phone;
      _name.text = pending.name;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_name, _phone, _password, _confirm, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _normalizedPhone => normalizePhone(_phone.text);

  void _startResendCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  bool _validateForm() {
    final errors = <String, String>{};
    if (_name.text.trim().length < 2) errors['name'] = 'اكتب اسمك.';
    if (!isValidPhone(_normalizedPhone)) errors['phone'] = 'اكتب رقم موبايل مصري صحيح (11 رقم).';
    if (_password.text.length < minPasswordLength) {
      errors['password'] = 'كلمة المرور $minPasswordLength حروف أو أرقام على الأقل.';
    } else if (_confirm.text != _password.text) {
      errors['confirm'] = 'كلمتا المرور غير متطابقتين.';
    }
    setState(() => _errors = errors);
    return errors.isEmpty;
  }

  Map<String, String> _serverErrors(ApiException e) => {
        for (final field in ['name', 'phone', 'password', 'code'])
          if (e.fieldError(field) != null) field: e.fieldError(field)!,
      };

  Future<void> _submitForm() async {
    if (!_validateForm()) return;
    FocusScope.of(context).unfocus();

    // كود سبق إرساله لنفس الرقم وما زال صالحًا: لا نطلب كودًا جديدًا حتى لا يُلغى القديم.
    final pending = _pending;
    if (pending != null && pending.isFresh && pending.phone == _normalizedPhone) {
      _openCodeStep(pending.resendInSeconds);
      return;
    }
    await _sendCode();
  }

  Future<void> _sendCode() async {
    final phone = _normalizedPhone;
    setState(() {
      _busy = true;
      _errors = {};
    });
    try {
      final retryAfter = await ref.read(repositoryProvider).sendRegistrationCode(phone);
      final pending = _PendingCode(phone: phone, name: _name.text.trim(), sentAt: DateTime.now(), retryAfter: retryAfter);
      await pending.save(ref);
      if (!mounted) return;
      _pending = pending;
      _code.clear();
      _openCodeStep(retryAfter);
    } on ApiException catch (e) {
      if (!mounted) return;
      final errors = _serverErrors(e);
      // خطأ غير مرتبط بحقل (مثل 429): يظهر حيث يقف المستخدم.
      if (errors.isEmpty) errors[_codeStep ? 'code' : 'phone'] = e.message;
      setState(() {
        _errors = errors;
        // خطأ في الرقم أثناء "إعادة الإرسال" → ارجع للبيانات ليراه.
        if (errors.containsKey('phone')) _codeStep = false;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openCodeStep(int resendIn) {
    setState(() {
      _codeStep = true;
      _errors = {};
    });
    _startResendCountdown(resendIn);
  }

  Future<void> _register() async {
    final code = _code.text.trim();
    if (code.length < 4) {
      setState(() => _errors = {'code': 'اكتب الكود اللي وصلك على واتساب.'});
      return;
    }

    setState(() {
      _busy = true;
      _errors = {};
    });
    try {
      final result = await ref.read(repositoryProvider).register(
            name: _name.text.trim(),
            phone: _normalizedPhone,
            password: _password.text,
            code: code,
          );
      await _PendingCode.clear(ref);
      await ref.read(authProvider.notifier).signIn(result);
      // التوجيه للرئيسية يتم تلقائيًا من الراوتر.
    } on ApiException catch (e) {
      if (!mounted) return;
      final errors = _serverErrors(e);
      if (errors.isEmpty) errors['code'] = e.message;
      setState(() {
        _errors = errors;
        // خطأ في بيانات الخطوة الأولى → ارجع لها.
        if (errors.keys.any((k) => k != 'code')) _codeStep = false;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.args.existingAccount;

    return PopScope(
      // زر الرجوع من شاشة الكود يرجع للبيانات بدل الخروج.
      canPop: !_codeStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _codeStep = false);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_codeStep ? 'كود التحقق' : (existing ? 'تحديد كلمة المرور' : 'حساب جديد'))),
        body: SafeArea(
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: _codeStep ? _buildCodeStep() : _buildForm(existing),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildForm(bool existing) {
    final phoneTaken = _errors['phone']?.contains('مسجل بالفعل') ?? false;
    final pending = _pending;
    final codeWaiting = pending != null && pending.isFresh && pending.phone == _normalizedPhone;

    return [
      if (existing)
        const NoticeBox(
          icon: Icons.verified_user_outlined,
          text: 'حسابك موجود عندنا، ومحتاج تحدد كلمة مرور مرة واحدة بس.\nحسابك وطلباتك وعناوينك كلها محفوظة.',
        ),
      if (codeWaiting) ...[
        if (existing) const SizedBox(height: 12),
        const NoticeBox(
          icon: Icons.chat_outlined,
          color: AppColors.success,
          text: 'بعتنالك كود على واتساب لهذا الرقم وما زال صالحًا.\nاكتب كلمة المرور واضغط متابعة عشان تدخّل الكود.',
        ),
      ],
      const FieldLabel('الاسم'),
      TextField(
        controller: _name,
        autofocus: !existing && _name.text.isEmpty,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.name],
        inputFormatters: [LengthLimitingTextInputFormatter(100)],
        decoration: InputDecoration(hintText: 'اسمك', prefixIcon: const Icon(Icons.person_outline), errorText: _errors['name']),
      ),
      const FieldLabel('رقم الموبايل'),
      PhoneField(
        controller: _phone,
        errorText: _errors['phone'],
        // يحدّث ملاحظة "الكود ما زال صالحًا" لو الرقم اتغير.
        onChanged: (_) => setState(() => _errors.remove('phone')),
      ),
      if (phoneTaken)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(onPressed: () => context.pop(), child: const Text('تسجيل الدخول')),
        ),
      FieldLabel(existing ? 'كلمة المرور الجديدة' : 'كلمة المرور'),
      PasswordField(
        controller: _password,
        isNew: true,
        hint: '$minPasswordLength حروف أو أرقام على الأقل',
        errorText: _errors['password'],
        textInputAction: TextInputAction.next,
      ),
      const FieldLabel('تأكيد كلمة المرور'),
      PasswordField(
        controller: _confirm,
        isNew: true,
        hint: 'اكتبها مرة تانية',
        errorText: _errors['confirm'],
        onSubmitted: (_) => _submitForm(),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _busy ? null : _submitForm,
        child: _busy ? const ButtonSpinner() : const Text('متابعة'),
      ),
      const SizedBox(height: 12),
      const Text(
        'هنبعتلك كود تحقق على واتساب لتأكيد رقمك.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, fontSize: 13),
      ),
    ];
  }

  List<Widget> _buildCodeStep() {
    return [
      const SizedBox(height: 8),
      const Center(child: Icon(Icons.chat_outlined, size: 56, color: AppColors.success)),
      const SizedBox(height: 12),
      const Text('هيوصلك الكود على واتساب', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'على الرقم '),
          TextSpan(text: _normalizedPhone, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
        ]),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 16),
      const NoticeBox(
        icon: Icons.schedule,
        color: AppColors.success,
        text: 'خدمة العملاء بتبعت الكود بنفسها، فممكن ياخد كام دقيقة.\nالكود صالح لمدة 30 دقيقة — تقدر تخرج من التطبيق وترجع تكتبه.',
      ),
      const SizedBox(height: 24),
      Directionality(
        textDirection: TextDirection.ltr,
        child: TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          style: const TextStyle(fontSize: 28, letterSpacing: 14, fontWeight: FontWeight.w700),
          decoration: InputDecoration(hintText: '• • • •', error: rtlFieldError(context, _errors['code'])),
          onSubmitted: (_) => _register(),
        ),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _busy ? null : _register,
        child: _busy ? const ButtonSpinner() : const Text('تأكيد وإنشاء الحساب'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _resendIn > 0 || _busy ? null : _sendCode,
        child: Text(_resendIn > 0 ? 'إعادة إرسال الكود بعد $_resendIn ث' : 'ما وصلش؟ إعادة إرسال الكود'),
      ),
      TextButton(
        onPressed: _busy ? null : () => setState(() => _codeStep = false),
        child: const Text('تعديل البيانات', style: TextStyle(color: AppColors.muted)),
      ),
    ];
  }
}
