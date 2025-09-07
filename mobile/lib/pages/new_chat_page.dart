import 'package:flutter/material.dart';
import '../services/mock_data.dart';
import 'chat_page.dart';

// + اضافه‌ها:
import '../services/chat_api.dart';
import '../services/mock_auth.dart';

class NewChatPage extends StatefulWidget {
  const NewChatPage({super.key});

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  final repo = MockChatRepo.instance;
  String _q = '';

  void _openCreateGroupSheet() {
    final selected = <String>{};
    final nameCtrl = TextEditingController();
    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final me = repo.me;
        List pickable() =>
            repo.users.where((u) => u.code != me).where((u) {
              if (query.trim().isEmpty) return true;
              final q = query.trim();
              return u.name.contains(q) || u.code.contains(q);
            }).toList();

        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder:
                (ctx, setStateSheet) => Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ساخت گروه',
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'نام گروه',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'جست‌وجوی همکار (نام یا کد پرسنلی)...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => setStateSheet(() => query = v),
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: pickable().length,
                            itemBuilder: (_, i) {
                              final u = pickable()[i];
                              final checked = selected.contains(u.code);
                              return CheckboxListTile(
                                dense: true,
                                title: Text('${u.name}  •  ${u.code}'),
                                value: checked,
                                onChanged:
                                    (v) => setStateSheet(() {
                                      if (v == true)
                                        selected.add(u.code);
                                      else
                                        selected.remove(u.code);
                                    }),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('انصراف'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () async {
                                final title = nameCtrl.text.trim();
                                if (title.isEmpty || selected.isEmpty) return;

                                // چون آی‌دی یوزرهای بک‌اند را نداریم، ساخت گروه سمت سرور فعلاً غیرفعال:
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'ساخت گروه از اپ فعلاً متصل نیست (نیاز به user_idها).',
                                    ),
                                  ),
                                );
                                // اگر بعداً متصل شد: ChatApi.createConversation(isGroup: true, name: title, members: [ids...])

                                // تلاش برای ناوبری فقط وقتی آی‌دی عددی داشته باشیم (در موک معمولاً رشته است و عددی نیست)
                                final conv = repo.createGroupWithMembers(
                                  title: title,
                                  members: selected,
                                );
                                final cid = int.tryParse(conv.id.toString());
                                if (cid == null) {
                                  return; // چیزی برای باز کردن نداریم
                                }
                                if (!mounted) return;
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => ChatPage(
                                          conversationId: cid, // 👈 تغییر اصلی
                                          title: conv.title,
                                          isGroup: true,
                                        ),
                                  ),
                                );
                              },
                              child: const Text('ایجاد گروه'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = repo.me;
    final items =
        repo.users.where((u) {
          if (u.code == me) return false;
          if (_q.trim().isEmpty) return true;
          final q = _q.trim();
          return u.name.contains(q) || u.code.contains(q);
        }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('انتخاب مخاطب')),
        body: Column(
          children: [
            // اکشن‌های بالای لیست
            Card(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.groups)),
                    title: const Text('گروه جدید'),
                    onTap: _openCreateGroupSheet,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'جست‌وجوی همکار (نام یا کد پرسنلی)...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final u = items[i];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      u.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('کد: ${u.code}'),
                    // تپ = باز/یافتن DM واقعی روی سرور
                    onTap: () async {
                      // اول از سرور کانورسیشن دونفره موجود را پیدا کن
                      try {
                        final meCode = MockAuthService().currentUser;
                        final convs = await ChatApi.listConversations();
                        Map<String, dynamic>? match;
                        for (final c in convs) {
                          final isGroup = c['is_group'] == true;
                          if (isGroup) continue;
                          final members =
                              (c['members_detail'] as List?)?.cast<Map>() ??
                              const [];
                          final hasOther = members.any(
                            (m) => (m['username']?.toString() ?? '') == u.code,
                          );
                          final hasMe = members.any(
                            (m) =>
                                (m['username']?.toString() ?? '') ==
                                (meCode ?? ''),
                          );
                          if (hasOther && hasMe) {
                            match = Map<String, dynamic>.from(c as Map);
                            break;
                          }
                        }
                        if (match == null) {
                          // فعلاً ساخت DM از اپ را وصل نکردیم (نیاز به user_id)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'گفتگوی دونفره‌ای یافت نشد. (ایجاد DM از اپ بعداً وصل می‌شود)',
                              ),
                            ),
                          );
                          return;
                        }
                        final cid = match['id'] as int;
                        if (!mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ChatPage(
                                  conversationId: cid, // 👈 تغییر اصلی
                                  title: u.name,
                                  isGroup: false,
                                  groupMembers: [u.code],
                                ),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطا در بازیابی گفتگو: $e')),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
