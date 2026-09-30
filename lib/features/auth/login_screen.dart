import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/repository.dart';
import '../../state/auth.dart';
import 'auth_widgets.dart';
import 'register_screen.dart';

/// الدخول برقم الموبايل + كلمة المرور.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _phoneError;
  String? _passwordError;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final phone = normalizePhone(_phone.text);
    setState(() {
      _phoneError = isValidPhone(phone) ? null : 'اكتب رقم موبايل مصري صحيح (11 رقم).';
      _passwordError = _password.text.isEmpty ? 'اكتب كلمة المرور.' : null;
    });
    if (_phoneError != null || _passwordError != null) return;

    setState(() => _busy = true);
    try {
      final result = await ref.read(repositoryProvider).login(phone, _password.text);
      await ref.read(authProvider.notifier).signIn(result);
      // التوجيه للرئيسية يتم تلقائيًا من الراوتر.
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409 && e.code == 'password_required') {
        // عميل قديم سجّل بالكود: يحدد كلمة المرور مرة واحدة من شاشة التسجيل بنفس الرقم.
        context.push('/register', extra: RegisterArgs(phone: phone, existingAccount: true));
      } else {
        // 422: رسالة السيرفر في errors.phone — 429: "محاولات كثيرة" من ApiException.
        setState(() => _phoneError = e.fieldError('phone') ?? e.message);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 36),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(26)),
                  child: const Icon(Icons.delivery_dining, color: Colors.white, size: 52),
                ),
              ),
              const SizedBox(height: 20),
              const Text('طلبات جرجا', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('كل اللي تحتاجه يوصلك لحد باب البيت', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 20),
              const FieldLabel('رقم الموبايل'),
              PhoneField(
                controller: _phone,
                errorText: _phoneError,
                onChanged: (_) {
                  if (_phoneError != null) setState(() => _phoneError = null);
                },
              ),
              const FieldLabel('كلمة المرور'),
              PasswordField(
                controller: _password,
                errorText: _passwordError,
                onChanged: (_) {
                  if (_passwordError != null || _phoneError != null) setState(() => _passwordError = _phoneError = null);
                },
                onSubmitted: (_) => _login(),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => showForgotPasswordDialog(context),
                  child: const Text('نسيت كلمة المرور؟'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _login,
                child: _busy ? const ButtonSpinner() : const Text('دخول'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('أول مرة معانا؟', style: TextStyle(color: AppColors.muted)),
                  TextButton(
                    onPressed: () => context.push('/register', extra: RegisterArgs(phone: normalizePhone(_phone.text))),
                    child: const Text('حساب جديد', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// لو الحساب بدون اسم (needs_profile للعميل).
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).updateName(_name.text.trim());
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أكمل بياناتك')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('اسمك', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(controller: _name, autofocus: true, decoration: const InputDecoration(hintText: 'الاسم')),
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('متابعة')),
        ],
      ),
    );
  }
}
