import 'package:flutter/foundation.dart';

class MockUser {
  final String code;
  final String name;
  final DateTime lastSeen;

  const MockUser(this.code, this.name, {required this.lastSeen});

  bool get isOnline => DateTime.now().difference(lastSeen).inMinutes <= 2;
}

class Message {
  final String id;
  final String conversationId;
  final String senderCode; // کد پرسنلی فرستنده
  final String text;
  final DateTime ts;

  // قابلیت ریپلای + ری‌اکشن (بعداً استفاده می‌کنیم)
  final String? replyToId;
  final Map<String, String> reactions;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderCode,
    required this.text,
    required this.ts,
    this.replyToId,
    Map<String, String>? reactions,
  }) : reactions = reactions ?? {};
}

class Conversation {
  final String id;
  String title; // نام فرد/گروه
  final bool isGroup;
  int unread;
  final List<Message> messages;

  /// اعضای گفتگو (کدهای پرسنلی). برای DM شامل ۲ نفر
  final Set<String> memberCodes;

  /// وضعیت بی‌صدا
  bool muted;

  /// کاربران در حال تایپ
  Set<String> typingUsers;

  /// موضوع گروه (برای گروه‌ها)
  final String topic;

  /// لیست اعضا (نمایشی؛ مثلا نام‌ها) - برای گروه‌ها
  final List<String> members;

  Conversation({
    required this.id,
    required this.title,
    required this.isGroup,
    this.unread = 0,
    List<Message>? messages,
    Set<String>? memberCodes,
    this.muted = false,
    Set<String>? initialTypingUsers,

    // 👇 این دو تا را اضافه کن با پیش‌فرض
    this.topic = "",
    this.members = const [],
  }) : messages = messages ?? [],
       memberCodes = memberCodes ?? {},
       typingUsers = initialTypingUsers ?? {};

  DateTime get lastActivity =>
      messages.isNotEmpty
          ? messages.last.ts
          : DateTime.fromMillisecondsSinceEpoch(0);
}

class MockChatRepo extends ChangeNotifier {
  static final MockChatRepo instance = MockChatRepo._();
  MockChatRepo._();

  String? me; // کد پرسنلی کاربر فعلی

  /// کاربران فیک سازمان
  final List<MockUser> users = [
    MockUser('1001', 'کاربر تست', lastSeen: DateTime.now()),
    MockUser(
      '2001',
      'مدیر تست',
      lastSeen: DateTime.now().subtract(const Duration(minutes: 3)),
    ),
    MockUser(
      '3001',
      'مریم رستگار',
      lastSeen: DateTime.now().subtract(const Duration(minutes: 25)),
    ),
    MockUser('3002', 'مهدی سهرابی', lastSeen: DateTime.now()),
    MockUser(
      '3003',
      'واحد منابع انسانی',
      lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    MockUser(
      '3004',
      'واحد فناوری اطلاعات',
      lastSeen: DateTime.now().subtract(const Duration(minutes: 1)),
    ),
    MockUser(
      '3005',
      'واحد مالی',
      lastSeen: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  final List<Conversation> conversations = [];

  MockUser? userByCode(String code) => users.firstWhere(
    (u) => u.code == code,
    orElse:
        () =>
            MockUser('', '', lastSeen: DateTime.fromMillisecondsSinceEpoch(0)),
  );

  /// دیتای اولیه
  void seed({required String currentUserCode}) {
    me = currentUserCode;
    conversations
      ..clear()
      ..addAll([
        Conversation(
          id: 'c1',
          title: 'گروه فناوری اطلاعات',
          isGroup: true,
          unread: 2,
          memberCodes: {'1001', '2001', '3004'},
          messages: [
            Message(
              id: 'm1',
              conversationId: 'c1',
              senderCode: '2001',
              text: 'سلام، گزارش مانیتورینگ آماده شد.',
              ts: DateTime.now().subtract(const Duration(minutes: 35)),
            ),
            Message(
              id: 'm2',
              conversationId: 'c1',
              senderCode: currentUserCode,
              text: 'عالیه، عصر مروری می‌کنیم.',
              ts: DateTime.now().subtract(const Duration(minutes: 12)),
            ),
          ],
        ),
        Conversation(
          id: 'c2',
          title: 'واحد منابع انسانی',
          isGroup: true,
          unread: 0,
          memberCodes: {'1001', '2001', '3003'},
          messages: [
            Message(
              id: 'm3',
              conversationId: 'c2',
              senderCode: '2001',
              text: 'جلسه آموزش فردا ساعت ۹.',
              ts: DateTime.now().subtract(const Duration(hours: 2)),
            ),
          ],
        ),
        Conversation(
          id: 'c3',
          title: 'مریم رستگار',
          isGroup: false,
          unread: 1,
          memberCodes: {'1001', '3001'},
          messages: [
            Message(
              id: 'm4',
              conversationId: 'c3',
              senderCode: '3001',
              text: 'فایل صورتجلسه رو فرستادم.',
              ts: DateTime.now().subtract(const Duration(minutes: 5)),
            ),
          ],
        ),
        Conversation(
          id: 'c4',
          title: 'مهدی سهرابی',
          isGroup: false,
          unread: 0,
          memberCodes: {'1001', '3002'},
          messages: [
            Message(
              id: 'm5',
              conversationId: 'c4',
              senderCode: '3002',
              text: 'سلام، امروز فرصت داری؟',
              ts: DateTime.now().subtract(const Duration(minutes: 60)),
            ),
          ],
        ),
        Conversation(
          id: 'c5',
          title: 'واحد مالی',
          isGroup: true,
          unread: 3,
          memberCodes: {'1001', '3005', '2001'},
          messages: [
            Message(
              id: 'm6',
              conversationId: 'c5',
              senderCode: '3005',
              text: 'صورت‌حساب‌ها تا آخر هفته آماده می‌شه.',
              ts: DateTime.now().subtract(const Duration(hours: 4)),
            ),
          ],
        ),
      ]);
    conversations.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    notifyListeners();
  }

  Conversation? byId(String id) {
    final idx = conversations.indexWhere((c) => c.id == id);
    if (idx == -1) return null;
    return conversations[idx];
  }

  void sendMessage(String convId, String text, {String? replyToId}) {
    if (me == null) return;
    final idx = conversations.indexWhere((c) => c.id == convId);
    if (idx == -1) return;

    final conv = conversations[idx];
    conv.messages.add(
      Message(
        id: 'm${DateTime.now().microsecondsSinceEpoch}',
        conversationId: convId,
        senderCode: me!,
        text: text,
        ts: DateTime.now(),
        replyToId: replyToId,
      ),
    );

    _bubbleToTop(convId);
    notifyListeners();
  }

  void markAsRead(String convId) {
    final idx = conversations.indexWhere((c) => c.id == convId);
    if (idx == -1) return;
    conversations[idx].unread = 0;
    notifyListeners();
  }

  void deleteConversation(String convId) {
    conversations.removeWhere((c) => c.id == convId);
    notifyListeners();
  }

  void toggleMute(String convId) {
    final idx = conversations.indexWhere((c) => c.id == convId);
    if (idx == -1) return;
    conversations[idx].muted = !conversations[idx].muted;
    notifyListeners();
  }

  List<Conversation> sortedConversations([String query = '']) {
    final items =
        conversations.where((c) {
          if (query.trim().isEmpty) return true;
          return c.title.contains(query.trim());
        }).toList();
    items.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return items;
  }

  Conversation createGroup({required String title}) {
    final id = 'g${DateTime.now().microsecondsSinceEpoch}';
    final conv = Conversation(
      id: id,
      title: title,
      isGroup: true,
      unread: 0,
      memberCodes: {if (me != null) me!},
      messages: [],
    );
    conversations.add(conv);
    _bubbleToTop(id);
    notifyListeners();
    return conv;
  }

  Conversation? findDirectMessageWith(String partnerCode) {
    final meCode = me;
    if (meCode == null) return null;
    final idx = conversations.indexWhere(
      (c) =>
          !c.isGroup &&
          c.memberCodes.contains(meCode) &&
          c.memberCodes.contains(partnerCode),
    );
    return idx == -1 ? null : conversations[idx];
  }

  Conversation createDirectMessage(String partnerCode) {
    final meCode = me;
    if (meCode == null) throw StateError('Current user is null');
    final partner = userByCode(partnerCode);
    final id = 'd${DateTime.now().microsecondsSinceEpoch}';
    final conv = Conversation(
      id: id,
      title: partner?.name.isNotEmpty == true ? partner!.name : partnerCode,
      isGroup: false,
      unread: 0,
      memberCodes: {meCode, partnerCode},
      messages: [],
    );
    conversations.add(conv);
    _bubbleToTop(id);
    notifyListeners();
    return conv;
  }

  Conversation getOrCreateDirectMessage(String partnerCode) {
    final ex = findDirectMessageWith(partnerCode);
    if (ex != null) return ex;
    return createDirectMessage(partnerCode);
  }

  Conversation createGroupWithMembers({
    required String title,
    required Set<String> members,
  }) {
    final all = {...members};
    if (me != null) all.add(me!);
    final id = 'g${DateTime.now().microsecondsSinceEpoch}';
    final conv = Conversation(
      id: id,
      title: title,
      isGroup: true,
      unread: 0,
      memberCodes: all,
      messages: [],
    );
    conversations.add(conv);
    _bubbleToTop(id);
    notifyListeners();
    return conv;
  }

  /// مدیریت وضعیت تایپ
  void setTyping(String convId, String userCode, bool isTyping) {
    final conv = conversations.firstWhere(
      (c) => c.id == convId,
      orElse: () => throw StateError('Conversation not found'),
    );
    if (isTyping) {
      conv.typingUsers.add(userCode);
    } else {
      conv.typingUsers.remove(userCode);
    }
    notifyListeners();
  }

  void _bubbleToTop(String convId) {
    final idx = conversations.indexWhere((c) => c.id == convId);
    if (idx <= 0) return;
    final conv = conversations.removeAt(idx);
    conversations.insert(0, conv);
  }
}
