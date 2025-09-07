import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import '../services/chat_api.dart';
import '../services/session_manager.dart';

enum MsgStatus { pending, sent, delivered, read }

class Message {
  final String id;
  final String text;
  final String senderId;
  final bool isMe;
  final DateTime time;
  MsgStatus status;
  final String? replyToText;
  final Map<String, Set<String>> reactionsByEmoji;

  Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.isMe,
    required this.time,
    this.status = MsgStatus.sent,
    this.replyToText,
    Map<String, Set<String>>? reactionsByEmoji,
  }) : reactionsByEmoji = reactionsByEmoji ?? {};
}

class ChatPage extends StatefulWidget {
  final int conversationId; // 👈 جایگزین peerId
  final String title;
  final bool isGroup;
  final String? groupTopic;
  final List<String>? groupMembers;

  const ChatPage({
    super.key,
    required this.conversationId, // 👈 الزامی
    required this.title,
    this.isGroup = false,
    this.groupTopic,
    this.groupMembers,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  List<Message> _messages = [];

  String? _replyToId;
  String? _replyToPreview;

  bool _isOnline = false;
  DateTime? _lastSeen;
  Timer? _presenceTick;

  // --- برای اتصال واقعی
  String? _myCode;
  int? _lastId;
  Timer? _poll;

  // --- Search state
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();
  final List<int> _searchHits = [];
  int _hitIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadInitial(); // 👈 پیام‌های واقعی
    _startPresenceSimulation(); // فقط برای UI
  }

  @override
  void dispose() {
    _poll?.cancel();
    _presenceTick?.cancel();
    _controller.dispose();
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------- API wiring ----------
  Future<void> _loadInitial() async {
    final me = await SessionManager.getUser();
    _myCode = me?.code;

    final items = await ChatApi.listMessages(widget.conversationId);
    _messages = items.map<Message>(_mapServerMsg).toList();
    if (_messages.isNotEmpty) {
      _lastId = int.tryParse(_messages.last.id);
    }
    setState(() {});
    _startPolling();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final items = await ChatApi.listMessages(
          widget.conversationId,
          afterId: _lastId,
        );
        if (items.isEmpty) return;
        final newOnes = items.map<Message>(_mapServerMsg).toList();
        setState(() {
          _messages.addAll(newOnes);
          if (_messages.isNotEmpty) {
            _lastId = int.tryParse(_messages.last.id);
          }
        });
        _scrollToBottom();
      } catch (_) {
        /* ignore */
      }
    });
  }

  Message _mapServerMsg(dynamic m) {
    final id = (m['id'] ?? '').toString();
    final text = (m['text'] ?? '').toString();
    final created =
        DateTime.tryParse((m['created_at'] ?? '').toString()) ?? DateTime.now();
    final senderUser = (m['sender_detail']?['username'] ?? '').toString();
    final isMe = (senderUser == _myCode);

    return Message(
      id: id,
      text: text,
      senderId: senderUser,
      isMe: isMe,
      time: created,
      status: isMe ? MsgStatus.read : MsgStatus.sent,
    );
  }

  Future<void> _sendTextToApi(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    try {
      final m = await ChatApi.sendMessage(
        conversationId: widget.conversationId,
        text: t,
      );
      final msg = _mapServerMsg(m);
      setState(() {
        _messages.add(msg);
        _lastId = int.tryParse(msg.id) ?? _lastId;
        _replyToId = null;
        _replyToPreview = null;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ارسال ناموفق: $e')));
    }
  }

  // ---------- Presence mock (برای UI) ----------
  void _startPresenceSimulation() {
    _presenceTick = Timer.periodic(const Duration(seconds: 5), (_) {
      setState(() {
        _isOnline = !_isOnline;
        if (!_isOnline) _lastSeen = DateTime.now();
      });
    });
  }

  String _presenceSubtitle() {
    if (widget.isGroup) {
      final count = widget.groupMembers?.length ?? 0;
      final topic =
          (widget.groupTopic?.trim().isNotEmpty ?? false)
              ? widget.groupTopic!.trim()
              : "بدون موضوع";
      return "$topic • $count عضو";
    }
    if (_isOnline) return "آنلاین";
    if (_lastSeen == null) return "آخرین بازدید نامشخص";
    final dt = _lastSeen!;
    return "آخرین بازدید • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  // ---------- Search ----------
  void _runSearch(String q) {
    _searchHits..clear();
    _hitIndex = -1;
    if (q.trim().isEmpty) {
      setState(() {});
      return;
    }
    for (int i = 0; i < _messages.length; i++) {
      final t = _messages[i].text.toLowerCase();
      if (t.contains(q.toLowerCase())) _searchHits.add(i);
    }
    if (_searchHits.isNotEmpty) {
      _hitIndex = 0;
      _jumpToHit();
    }
    setState(() {});
  }

  void _jumpToHit() {
    if (_hitIndex < 0 || _hitIndex >= _searchHits.length) return;
    final i = _searchHits[_hitIndex];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        80.0 * i,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _nextHit() {
    if (_searchHits.isEmpty) return;
    _hitIndex = (_hitIndex + 1) % _searchHits.length;
    _jumpToHit();
    setState(() {});
  }

  void _prevHit() {
    if (_searchHits.isEmpty) return;
    _hitIndex = (_hitIndex - 1 + _searchHits.length) % _searchHits.length;
    _jumpToHit();
    setState(() {});
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _searchHits.clear();
    _hitIndex = -1;
    setState(() => _showSearch = false);
  }

  // ---------- UI helpers ----------
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _showReactionPicker(Message m) {
    showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) {
        const emojis = ["😍", "👍", "😂", "😡", "😮", "❤️"];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children:
                  emojis.map((e) {
                    return InkWell(
                      onTap: () => Navigator.pop(context, e),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    );
                  }).toList(),
            ),
          ),
        );
      },
    ).then((picked) {
      if (picked == null) return;
      setState(() {
        final set = m.reactionsByEmoji.putIfAbsent(picked, () => <String>{});
        final me = _myCode ?? 'me';
        if (set.contains(me)) {
          set.remove(me);
          if (set.isEmpty) m.reactionsByEmoji.remove(picked);
        } else {
          set.add(me);
        }
      });
    });
  }

  void _showMessageActions(Message m) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text("پاسخ"),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _replyToId = m.id;
                    _replyToPreview = m.text;
                  });
                  HapticFeedback.lightImpact();
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text("کپی متن"),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Clipboard.setData(ClipboardData(text: m.text));
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("متن کپی شد")));
                },
              ),
              if (m.isMe)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text("حذف برای من"),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _messages.removeWhere((e) => e.id == m.id);
                    });
                  },
                ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.emoji_emotions_outlined),
                title: const Text("ری‌اکشن"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReactionPicker(m);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  bool _sending = false;

  Future<void> _openAttachmentSheet() async {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('انتخاب از گالری'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _sendFromGallery();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('گرفتن عکس با دوربین'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _sendFromCamera();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: const Text('انتخاب فایل (PDF/Word/…)'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _sendFromFiles();
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _sendFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    await _sendMultipart(
      files: picked.map((x) => File(x.path)).toList(),
      asMultiple: true,
    );
  }

  Future<void> _sendFromCamera() async {
    final picker = ImagePicker();
    final shot = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (shot == null) return;
    await _sendMultipart(files: [File(shot.path)], asMultiple: false);
  }

  Future<void> _sendFromFiles() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null) return;
    final files = <File>[];
    for (final f in res.files) {
      if (f.path != null) files.add(File(f.path!));
    }
    if (files.isEmpty) return;
    await _sendMultipart(files: files, asMultiple: files.length > 1);
  }

  Future<void> _sendMultipart({
    required List<File> files,
    required bool asMultiple,
  }) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      // --- ۱) آدرس سرور
      // اگر ChatApi.baseUrl() داری، از خودش بخوان:
      final String baseUrl = /* await ChatApi.baseUrl() ?? */
          'http://10.0.2.2:8000';
      // نکته: اگر روی Android Emulator هستی و سرور روی لپ‌تاپت است، به‌جای 127.0.0.1 از 10.0.2.2 استفاده کن.
      // اگر روی دستگاه فیزیکی تست می‌کنی، IP شبکه‌ی لپ‌تاپ را بگذار (مثلاً 192.168.1.10:8000).

      // --- ۲) هدر احراز هویت را از SessionManager بخوان (نه هاردکُد)
      final String? authHeader = await SessionManager.getAuthHeader();
      if (authHeader == null) {
        _showSnack('توکن یافت نشد؛ لطفاً دوباره وارد شوید.');
        if (mounted) setState(() => _sending = false);
        return;
      }

      // --- ۳) ساخت درخواست مولتی‌پارت
      final uri = Uri.parse('$baseUrl/api/chat/messages/send/');
      final req =
          http.MultipartRequest('POST', uri)
            ..headers['Authorization'] =
                authHeader // ← به‌جای متغیرِ تعریف‌نشده‌ی token
            ..fields['conversation_id'] = '${widget.conversationId}';

      // کپشن همزمان با فایل‌ها (اختیاری)
      final caption = _controller.text.trim();
      if (caption.isNotEmpty) req.fields['text'] = caption;

      // --- ۴) افزودن فایل‌ها
      final fieldKey = asMultiple ? 'files' : 'file';
      for (final f in files) {
        final mime = lookupMimeType(f.path) ?? 'application/octet-stream';
        req.files.add(
          await http.MultipartFile.fromPath(
            fieldKey,
            f.path,
            filename: f.path.split('/').last,
            contentType: MediaType.parse(mime), // از package:http_parser
          ),
        );
      }

      // --- ۵) ارسال و پردازش پاسخ
      final resp = await req.send();
      final body = await resp.stream.bytesToString();

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final items = await ChatApi.listMessages(
          widget.conversationId,
          afterId: _lastId,
        );
        if (items.isNotEmpty) {
          setState(() {
            _messages.addAll(items.map<Message>(_mapServerMsg));
            if (_messages.isNotEmpty) _lastId = int.tryParse(_messages.last.id);
            _controller.clear(); // کپشن را هم خالی کن
          });
          _scrollToBottom();
        }
      } else {
        _showSnack('آپلود ناموفق: ${resp.statusCode}\n$body');
      }
    } catch (e) {
      _showSnack('خطا در آپلود: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: InkWell(
            onTap:
                widget.isGroup
                    ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => GroupInfoPage(
                                title: widget.title,
                                topic: widget.groupTopic ?? "بدون موضوع",
                                members: widget.groupMembers ?? const [],
                              ),
                        ),
                      );
                    }
                    : null,
            child: Row(
              children: [
                CircleAvatar(child: Text(widget.title.characters.first)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _presenceSubtitle(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: _showSearch ? 'بستن جست‌وجو' : 'جست‌وجو',
              icon: Icon(_showSearch ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) _clearSearch();
                });
              },
            ),
          ],
          bottom:
              _showSearch
                  ? PreferredSize(
                    preferredSize: const Size.fromHeight(56),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              autofocus: true,
                              decoration: const InputDecoration(
                                hintText: 'جست‌وجو در این گفتگو…',
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: _runSearch,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _searchHits.isEmpty
                                ? '0/0'
                                : '${_hitIndex + 1}/${_searchHits.length}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          IconButton(
                            tooltip: 'قبلی',
                            icon: const Icon(Icons.keyboard_arrow_up),
                            onPressed: _searchHits.isEmpty ? null : _prevHit,
                          ),
                          IconButton(
                            tooltip: 'بعدی',
                            icon: const Icon(Icons.keyboard_arrow_down),
                            onPressed: _searchHits.isEmpty ? null : _nextHit,
                          ),
                        ],
                      ),
                    ),
                  )
                  : null,
        ),

        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  final prevIsSameSender =
                      i > 0 && _messages[i - 1].senderId == m.senderId;
                  return _MessageBubble(
                    key: ValueKey(m.id),
                    message: m,
                    compact: prevIsSameSender,
                    onSwipeReply: () {
                      setState(() {
                        _replyToId = m.id;
                        _replyToPreview = m.text;
                      });
                      HapticFeedback.lightImpact();
                    },
                    onLongPress: () => _showMessageActions(m),
                    onToggleReaction: (emoji) {
                      setState(() {
                        final set = m.reactionsByEmoji.putIfAbsent(
                          emoji,
                          () => <String>{},
                        );
                        final me = _myCode ?? 'me';
                        set.contains(me) ? set.remove(me) : set.add(me);
                      });
                    },
                  );
                },
              ),
            ),

            if (_replyToId != null)
              _ReplyBar(
                text: _replyToPreview ?? "",
                onClose: () {
                  setState(() {
                    _replyToId = null;
                    _replyToPreview = null;
                  });
                },
              ),

            _InputBar(
              controller: _controller,
              onSend: (t) {
                _controller.clear();
                _sendTextToApi(t); // 👈 ارسال واقعی
              },
              onAttach: _openAttachmentSheet,
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------- Group Info --------------------
class GroupInfoPage extends StatelessWidget {
  final String title;
  final String topic;
  final List<String> members;

  const GroupInfoPage({
    super.key,
    required this.title,
    required this.topic,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final m =
        members.isEmpty
            ? List<String>.generate(8, (i) => "عضو ${i + 1}")
            : members;

    return Scaffold(
      appBar: AppBar(title: const Text("اطلاعات گروه")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(radius: 28, child: Text(title.characters.first)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text("موضوع: $topic"),
          const SizedBox(height: 8),
          Text("تعداد اعضا: ${m.length}"),
        ],
      ),
    );
  }
}

// -------------------- Bubble + Reply/Input (بدون تغییر ظاهری) --------------------
class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool compact;
  final VoidCallback onSwipeReply;
  final VoidCallback onLongPress;
  final void Function(String emoji) onToggleReaction;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.compact,
    required this.onSwipeReply,
    required this.onLongPress,
    required this.onToggleReaction,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey("swipe-${message.id}"),
      direction: DismissDirection.endToStart,
      resizeDuration: null,
      secondaryBackground: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: CircleAvatar(
            radius: 14,
            child: const Icon(Icons.reply, size: 16),
          ),
        ),
      ),
      background: const SizedBox(),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.endToStart) onSwipeReply();
        return false;
      },
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            message.isMe ? 60 : 12,
            compact ? 2 : 8,
            message.isMe ? 12 : 60,
            2,
          ),
          child: Align(
            alignment:
                message.isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isMe ? Colors.blue[50] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment:
                    message.isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                children: [
                  if (message.replyToText != null) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          right: BorderSide(color: Colors.blue[300]!, width: 3),
                        ),
                      ),
                      child: Text(
                        message.replyToText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                  Text(message.text),
                  const SizedBox(height: 6),
                  if (message.reactionsByEmoji.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _ReactionsStrip(
                      reactionsByEmoji: message.reactionsByEmoji,
                      onTapEmoji: onToggleReaction,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        "${message.time.hour.toString().padLeft(2, '0')}:${message.time.minute.toString().padLeft(2, '0')}",
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 6),
                      if (message.isMe) _StatusTicks(status: message.status),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  final String text;
  final VoidCallback onClose;

  const _ReplyBar({required this.text, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.06),
        border: Border(right: BorderSide(color: Colors.blue[300]!, width: 3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            tooltip: "لغو پاسخ",
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onSend;
  final VoidCallback? onAttach;

  const _InputBar({
    required this.controller,
    required this.onSend,
    this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              child: IconButton(
                tooltip: 'ضمیمه',
                icon: const Icon(Icons.attach_file),
                onPressed: onAttach,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: "پیام بنویس…",
                    border: InputBorder.none,
                  ),
                  onSubmitted: onSend,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  final t = controller.text.trim();
                  if (t.isEmpty) return;
                  controller.clear();
                  onSend(t);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTicks extends StatelessWidget {
  final MsgStatus status;
  const _StatusTicks({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MsgStatus.pending:
        return const Icon(Icons.access_time, size: 14, color: Colors.grey);
      case MsgStatus.sent:
        return const Icon(Icons.check, size: 14, color: Colors.grey);
      case MsgStatus.delivered:
        return Stack(
          alignment: Alignment.centerRight,
          children: const [
            Icon(Icons.check, size: 14, color: Colors.grey),
            Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.check, size: 14, color: Colors.grey),
            ),
          ],
        );
      case MsgStatus.read:
        return Stack(
          alignment: Alignment.centerRight,
          children: [
            Icon(Icons.check, size: 14, color: Colors.blue[600]),
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.check, size: 14, color: Colors.blue),
            ),
          ],
        );
    }
  }
}

class _ReactionsStrip extends StatelessWidget {
  final Map<String, Set<String>> reactionsByEmoji;
  final void Function(String emoji) onTapEmoji;

  const _ReactionsStrip({
    required this.reactionsByEmoji,
    required this.onTapEmoji,
  });

  @override
  Widget build(BuildContext context) {
    if (reactionsByEmoji.isEmpty) return const SizedBox.shrink();

    final entries =
        reactionsByEmoji.entries.toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Wrap(
      spacing: 6,
      children:
          entries.map((e) {
            final emoji = e.key;
            final count = e.value.length;
            return InkWell(
              onTap: () => onTapEmoji(emoji),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      "$count",
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }
}
