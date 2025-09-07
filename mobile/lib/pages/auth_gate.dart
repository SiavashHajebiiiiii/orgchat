import 'package:flutter/material.dart';
import '../services/session_manager.dart';
import '../services/mock_data.dart';
import 'chat_list_page.dart';
import 'login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _ensureRepoReady() async {
    final loggedIn = await SessionManager.isLoggedIn();
    if (!loggedIn) return false;

    final user = await SessionManager.getUser(); // باید code و name برگرداند
    if (user != null && user.code.isNotEmpty) {
      final repo = MockChatRepo.instance;
      // اگر قبلاً ست نشده یا با کد دیگری ست شده، تنظیم کن
      if (repo.me != user.code) {
        repo.me = user.code;
      }
      // اگر هنوز گفتگویی نداریم، یکبار فیک دِیتا را لود کن
      if (repo.conversations.isEmpty) {
        repo.seed(currentUserCode: user.code);
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _ensureRepoReady(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        final ready = snap.data ?? false;
        return ready ? const ChatListPage() : const LoginPage();
      },
    );
  }
}

class SessionManager {
  // کلیدهای ذخیره‌سازی واحد
  static const _kToken = 'auth_token';
  static const _kUserCode = 'auth_user_code';
  static const _kUserName = 'auth_user_name';

  // معیار لاگین = وجود توکن
  static Future<bool> isLoggedIn() async {
    final sp = await SharedPreferences.getInstance();
    return (sp.getString(_kToken)?.isNotEmpty ?? false);
  }

  // Token
  static Future<void> saveToken(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kToken, token);
  }

  static Future<String?> getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kToken);
  }

  // User (اختیاری ولی برای UI مفید)
  static Future<void> saveUser({required String code, String? name}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kUserCode, code);
    if (name != null) await sp.setString(_kUserName, name);
  }

  static Future<UserInfo?> getUser() async {
    final sp = await SharedPreferences.getInstance();
    final code = sp.getString(_kUserCode);
    if (code == null || code.isEmpty) return null;
    final name = sp.getString(_kUserName) ?? '';
    return UserInfo(code: code, name: name);
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kToken);
    await sp.remove(_kUserCode);
    await sp.remove(_kUserName);
  }
}

class UserInfo {
  final String code;
  final String name;
  const UserInfo({required this.code, required this.name});
}
