import 'package:shared_preferences/shared_preferences.dart';

class SessionUser {
  final String code;
  final String name;
  const SessionUser({required this.code, required this.name});
}

class SessionManager {
  // کلیدهای ذخیره‌سازی
  static const _kToken = 'auth_token'; // ✅ معیار اصلی لاگین
  static const _kLoggedIn = 'logged_in'; // (سازگاری با گذشته)
  static const _kCode = 'user_code';
  static const _kName = 'user_name';

  /// معیار لاگین = وجود توکن؛ اگر نبود، از فلگ قدیمی هم پشتیبانی می‌کند.
  static Future<bool> isLoggedIn() async {
    final p = await SharedPreferences.getInstance();
    final t = p.getString(_kToken);
    if (t != null && t.isNotEmpty) return true; // ✅ معیار جدید
    return p.getBool(_kLoggedIn) ?? false; // سازگاری قدیمی
  }

  static Future<String?> getAuthHeader() async {
    final t = await getToken();
    if (t == null || t.isEmpty) return null;
    return 'Token $t';
  }
  // ---------------- Token ----------------

  /// ذخیرهٔ توکن (برای Auth واقعی با بک‌اند)
  static Future<void> saveToken(String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
    // برای سازگاری با کدی که فقط logged_in را چک می‌کند:
    await p.setBool(_kLoggedIn, true);
  }

  /// دریافت توکن؛ اگر وجود نداشت null برمی‌گرداند.
  static Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kToken);
  }

  // ---------------- User ----------------

  /// ذخیرهٔ اطلاعات کاربر (مثلاً code = username یا کد پرسنلی)
  static Future<void> saveUser({required String code, String? name}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kCode, code);
    if (name != null) await p.setString(_kName, name);
  }

  /// گرفتن اطلاعات کاربر فعلی
  static Future<SessionUser?> getUser() async {
    final p = await SharedPreferences.getInstance();
    final code = p.getString(_kCode) ?? '';
    final name = p.getString(_kName) ?? '';
    if (code.isEmpty) return null;
    return SessionUser(code: code, name: name);
  }

  // ---------------- Legacy (سازگاری با کد قدیمی) ----------------

  /// فقط برای کد قدیمی که قبل از توکن استفاده می‌شد.
  /// پیشنهاد: به‌جای این، از saveToken + saveUser استفاده کن.
  static Future<void> setLoggedIn({
    required String code,
    required String name,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLoggedIn, true);
    await p.setString(_kCode, code);
    await p.setString(_kName, name);
  }

  // ---------------- Logout ----------------

  /// پاک‌کردن سشن (توکن و اطلاعات کاربر)
  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kLoggedIn);
    await p.remove(_kCode);
    await p.remove(_kName);
  }
}
