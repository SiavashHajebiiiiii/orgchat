import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // فعلاً ماک ساده: نام و عکس
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('پروفایل')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
              const SizedBox(height: 16),
              const Text(
                'نام و نام خانوادگی',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('کد پرسنلی: 1001'),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('اطلاعات بیشتر'),
                subtitle: const Text('اینجا می‌تونیم جزئیات بیشتری نشون بدیم'),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
