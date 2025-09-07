import 'package:flutter/material.dart';
import 'package:orgchat/pages/auth_gate.dart';
import 'package:orgchat/pages/login_page.dart';
import 'package:orgchat/services/auth_errors.dart';

Future<T> guard401<T>(BuildContext context, Future<T> Function() work) async {
  try {
    return await work();
  } on UnauthorizedException {
    await SessionManager.clear();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
    rethrow;
  }
}
