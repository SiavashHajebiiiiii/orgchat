// lib/services/chat_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_manager.dart';
import 'auth_errors.dart'; // ← فایل ساده با UnauthorizedException

class ChatApi {
  // اگر داخل LAN تست می‌کنی عوضش کن
  // static const String baseUrl = "http://192.168.43.40:8000";
  static const String baseUrl = "http://103.75.199.146";

  // ---------- Auth ----------
  static Future<String> login(String username, String password) async {
    final url = Uri.parse("$baseUrl/api/auth/login/");
    final resp = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({"username": username, "password": password}),
    );

    if (resp.statusCode == 200) {
      final map = jsonDecode(resp.body) as Map;
      final token = map["token"] as String;
      await SessionManager.saveToken(token);
      await SessionManager.saveUser(code: username); // اختیاری
      return token;
    }
    throw Exception("Login failed: ${resp.statusCode} ${resp.body}");
  }

  static Future<void> logout() async {
    await SessionManager.clear();
  }

  // ---------- Private: headers + unified sender ----------
  static Future<Map<String, String>> _headers() async {
    final t = await SessionManager.getToken();
    if (t == null || t.isEmpty) throw UnauthorizedException();
    return {
      "Authorization": "Token $t",
      "Content-Type": "application/json",
      "Accept": "application/json",
    };
  }

  /// همهٔ درخواست‌ها از این مسیر بروند تا 401 یکجا مدیریت شود.
  static Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? jsonBody,
  }) async {
    final url = Uri.parse("$baseUrl$path");
    final h = await _headers();

    http.Response r;
    switch (method) {
      case 'GET':
        r = await http.get(url, headers: h);
        break;
      case 'POST':
        r = await http.post(url, headers: h, body: jsonEncode(jsonBody));
        break;
      default:
        throw UnsupportedError('HTTP $method not supported');
    }

    if (r.statusCode == 401) {
      // فقط علامت بده بالا؛ پاک‌سازی و ناوبری در UI انجام می‌شود.
      throw UnauthorizedException();
    }
    return r;
  }

  // ---------- Conversations ----------
  static Future<List<dynamic>> listConversations() async {
    final r = await _send('GET', "/api/chat/conversations/");
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      if (body is Map && body["results"] is List) return body["results"];
      return body as List<dynamic>;
    }
    throw Exception("listConversations failed: ${r.statusCode} ${r.body}");
  }

  static Future<Map<String, dynamic>> createConversation({
    required bool isGroup,
    String name = "",
    List<int> members = const [],
  }) async {
    final r = await _send(
      'POST',
      "/api/chat/conversations/",
      jsonBody: {"name": name, "is_group": isGroup, "members": members},
    );
    if (r.statusCode == 201 || r.statusCode == 200) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    throw Exception("createConversation failed: ${r.statusCode} ${r.body}");
  }

  // ---------- Messages ----------
  static Future<List<dynamic>> listMessages(
    int conversationId, {
    int? afterId,
  }) async {
    final q = (afterId != null) ? "?after_id=$afterId" : "";
    final r = await _send('GET', "/api/chat/messages/$conversationId/$q");
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body);
      if (body is Map && body["results"] is List) return body["results"];
      return body as List<dynamic>;
    }
    throw Exception("listMessages failed: ${r.statusCode} ${r.body}");
  }

  static Future<Map<String, dynamic>> sendMessage({
    required int conversationId,
    required String text,
  }) async {
    final r = await _send(
      'POST',
      "/api/chat/messages/send/",
      jsonBody: {"conversation_id": conversationId, "text": text},
    );
    if (r.statusCode == 201) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    throw Exception("sendMessage failed: ${r.statusCode} ${r.body}");
  }
}
