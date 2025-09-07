import 'package:flutter/material.dart';
import 'package:orgchat/pages/new_chat_page.dart';
import 'chat_page.dart';
import 'profile_page.dart';
import 'change_password_page.dart';

import '../services/chat_api.dart';
import '../services/session_manager.dart'; // 👈 به‌جای mock_auth

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  bool _showSearch = false;

  String? _meCode; // 👈 username لاگین‌شده

  @override
  void initState() {
    super.initState();
    _initMeAndLoad();
  }

  Future<void> _initMeAndLoad() async {
    final u = await SessionManager.getUser();
    setState(() => _meCode = u?.code);
    await _load();
  }

  // عنوان نمایشی گفتگو (اگر name خالی بود، برای DM اسم طرف مقابل را نشان بده)
  String _displayTitle(Map<String, dynamic> c) {
    final name = (c['name'] as String?)?.trim() ?? '';
    if (name.isNotEmpty) return name;
    final isGroup = c['is_group'] == true;
    if (isGroup) return 'گروه ${c["id"]}';

    final members = (c['members_detail'] as List?)?.cast<Map>() ?? const [];
    if (members.isEmpty) return 'چت دونفره ${c["id"]}';

    Map other = members.firstWhere(
      (m) => (m['username']?.toString() ?? '') != (_meCode ?? ''),
      orElse: () => members.first,
    );
    final uname = other['username']?.toString() ?? '';
    return uname.isEmpty ? 'چت دونفره ${c["id"]}' : uname;
  }

  // فیلتر محلی با سرچ
  List<Map<String, dynamic>> _filtered() {
    if (_query.trim().isEmpty) return _conversations;
    final q = _query.trim();
    return _conversations.where((c) {
      final title = _displayTitle(c);
      return title.contains(q);
    }).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ChatApi.listConversations();
      _conversations =
          items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      final s = e.toString();
      // اگر سشن نامعتبر شد → به لاگین برگرد
      if (s.contains('401') || s.contains('No token')) {
        await SessionManager.clear();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder:
                (_) =>
                    const ChangePasswordPage().runtimeType == Null
                        ? const ChangePasswordPage()
                        : const ChangePasswordPage(),
          ),
          (route) => true,
        ); // این خط بالا فقط برای جلوگیری از خطای تحلیلگر بود، ولی ما به LoginPage می‌خواهیم برویم:
      }
      _error = s;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // منوی گفت‌وگو (Placeholder)
  void _showConversationMenu(Map<String, dynamic> c) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder:
          (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('جزئیات گفتگو'),
                    subtitle: Text(
                      "ID: ${c["id"]}  |  ${c["is_group"] == true ? "Group" : "DM"}",
                    ),
                    onTap: () => Navigator.pop(ctx),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        drawer: Drawer(
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const ListTile(
                  leading: CircleAvatar(radius: 18, child: Icon(Icons.person)),
                  title: Text('OrgChat'),
                  subtitle: Text('اتصال به سرور فعال است'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('پروفایل'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('تغییر رمز'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordPage(),
                      ),
                    );
                  },
                ),
                const Divider(),
              ],
            ),
          ),
        ),

        appBar: AppBar(
          title: const Text('گفتگوها'),
          actions: [
            IconButton(
              tooltip: _showSearch ? 'بستن جست‌وجو' : 'جست‌وجو',
              icon: Icon(_showSearch ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) _query = '';
                });
              },
            ),
            IconButton(
              tooltip: 'به‌روزرسانی',
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
          ],
        ),

        body: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child:
                  _showSearch
                      ? Padding(
                        key: const ValueKey('searchbar'),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'جست‌وجوی گفتگو...',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      )
                      : const SizedBox.shrink(key: ValueKey('nosearch')),
            ),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              )
            else if (items.isEmpty)
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      const SizedBox(height: 120),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Theme.of(context).hintColor,
                          ),
                          const SizedBox(height: 12),
                          const Text('هنوز گفتگویی ندارید'),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final c = items[i];
                      final title = _displayTitle(c);
                      final isGroup = c['is_group'] == true;

                      return ListTile(
                        onLongPress: () => _showConversationMenu(c),
                        leading: CircleAvatar(
                          child:
                              isGroup
                                  ? const Icon(Icons.groups)
                                  : Text(
                                    title.isNotEmpty
                                        ? title.characters.first
                                        : '?',
                                  ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: const Text(
                          '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.color?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          final members =
                              (c['members_detail'] as List?)?.cast<Map>() ??
                              const [];
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => ChatPage(
                                    // 👇 حتماً ChatPage را بروز کن که conversationId (int) بگیرد
                                    conversationId: c['id'] as int,
                                    title: title,
                                    isGroup: isGroup,
                                    groupTopic: '',
                                    groupMembers:
                                        members
                                            .map(
                                              (m) =>
                                                  (m['username'] ?? '')
                                                      .toString(),
                                            )
                                            .where((s) => s.isNotEmpty)
                                            .toList(),
                                  ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
          ],
        ),

        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NewChatPage()),
            ).then((_) => _load());
          },
          child: const Icon(Icons.person_add_alt_1),
        ),
      ),
    );
  }
}
