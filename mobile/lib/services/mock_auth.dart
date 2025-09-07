// lib/services/mock_auth.dart  (حالا واقعی!)
import 'package:orgchat/services/chat_api.dart';

class MockAuthService {
  static final MockAuthService _i = MockAuthService._();
  MockAuthService._();
  factory MockAuthService() => _i;

  String? _username;

  Future<bool> login({required String code, required String password}) async {
    try {
      await ChatApi.login(code, password); // code همان username (کد پرسنلی)
      _username = code;
      return true;
    } catch (_) {
      return false;
    }
  }

  void logout() {
    _username = null;
    ChatApi.logout();
  }

  String? get currentUser => _username;
}
