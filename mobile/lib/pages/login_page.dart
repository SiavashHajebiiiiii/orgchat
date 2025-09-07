import 'package:flutter/material.dart';
import 'package:orgchat/pages/chat_list_page.dart';
import 'package:orgchat/services/session_manager.dart';
import '../widgets/app_logo.dart';
import '../services/mock_auth.dart';
// توجه: mock_data دیگه لازم نیست چون از API واقعی استفاده می‌کنیم
// import '../services/mock_data.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _remember = true;
  bool _loading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final code = _codeCtrl.text.trim();
    final pass = _passCtrl.text;

    final ok = await MockAuthService().login(
      code: code, // code = کد پرسنلی (username)
      password: pass,
    );

    setState(() => _loading = false);
    if (!mounted) return;

    if (ok) {
      // حالا currentUser فقط همون کد پرسنلی (String) هست
      final meCode = MockAuthService().currentUser!;

      // اگر SessionManager نیاز به name داره، فعلاً همون کد رو بجای نام ذخیره می‌کنیم
      await SessionManager.setLoggedIn(code: meCode, name: meCode);

      // دیگه seed ماک لازم نیست چون لیست‌ها از API میان
      // MockChatRepo.instance.seed(currentUserCode: meCode);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خوش آمدید $meCode 👋')));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatListPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('کد پرسنلی یا رمز عبور نادرست است')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppLogo(),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _codeCtrl,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'کد پرسنلی',
                                  hintText: 'مثلاً 1010',
                                  prefixIcon: Icon(Icons.badge),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'کد پرسنلی را وارد کنید';
                                  }
                                  if (v.trim().length < 3) {
                                    return 'کد پرسنلی معتبر نیست';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passCtrl,
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _onLoginPressed(),
                                decoration: InputDecoration(
                                  labelText: 'رمز عبور',
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    onPressed:
                                        () => setState(() {
                                          _obscure = !_obscure;
                                        }),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'رمز عبور را وارد کنید';
                                  }
                                  if (v.length < 4) {
                                    return 'رمز عبور حداقل ۴ کاراکتر باشد';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _remember,
                                    onChanged:
                                        (v) => setState(() {
                                          _remember = v ?? true;
                                        }),
                                  ),
                                  const Text('مرا به خاطر بسپار'),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () {},
                                    child: const Text('فراموشی رمز؟'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton(
                                  onPressed: _loading ? null : _onLoginPressed,
                                  child:
                                      _loading
                                          ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : const Text('ورود'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Opacity(
                      opacity: 0.7,
                      child: Text(
                        'برای تست: کد 1010 / رمز 12345',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
