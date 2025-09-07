import 'package:flutter/material.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _repCtrl = TextEditingController();
  bool _ob1 = true, _ob2 = true, _ob3 = true;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _repCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_newCtrl.text != _repCtrl.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تکرار رمز مطابقت ندارد')));
      return;
    }
    // فعلاً ماک: فقط پیام موفقیت
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('رمز با موفقیت تغییر کرد (نمونه UI)')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تغییر رمز')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _oldCtrl,
                  obscureText: _ob1,
                  decoration: InputDecoration(
                    labelText: 'رمز فعلی',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _ob1 ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _ob1 = !_ob1),
                    ),
                  ),
                  validator:
                      (v) =>
                          (v == null || v.isEmpty)
                              ? 'رمز فعلی را وارد کنید'
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newCtrl,
                  obscureText: _ob2,
                  decoration: InputDecoration(
                    labelText: 'رمز جدید',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _ob2 ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _ob2 = !_ob2),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'رمز جدید را وارد کنید';
                    if (v.length < 4) return 'حداقل ۴ کاراکتر باشد';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _repCtrl,
                  obscureText: _ob3,
                  decoration: InputDecoration(
                    labelText: 'تکرار رمز جدید',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _ob3 ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _ob3 = !_ob3),
                    ),
                  ),
                  validator:
                      (v) =>
                          (v == null || v.isEmpty)
                              ? 'تکرار رمز را وارد کنید'
                              : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('ثبت'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
