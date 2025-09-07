import 'package:flutter/material.dart';

class GroupInfoPage extends StatefulWidget {
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
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m =
        widget.members.isEmpty
            ? List<String>.generate(12, (i) => "عضو ${i + 1}")
            : widget.members;

    Widget tile(
      IconData icon,
      String title, {
      Widget? trailing,
      VoidCallback? onTap,
      String? subtitle,
    }) {
      return ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: trailing,
        onTap: onTap,
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("اطلاعات گروه"),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
            PopupMenuButton<int>(
              itemBuilder:
                  (_) => const [
                    PopupMenuItem(value: 1, child: Text("تنظیمات گروه")),
                    PopupMenuItem(value: 2, child: Text("گزارش")),
                  ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 42,
                    child: Icon(Icons.group, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Group • ${m.length} members",
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // اگر Material 3 فعال نیست، زیر را با ElevatedButton جایگزین کن
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.mic),
                        label: const Text("Voice chat"),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.search),
                        label: const Text("Search"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // About (با Read more/less)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "دربارهٔ گروه",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      widget.topic.isEmpty ? "—" : widget.topic,
                      textAlign: TextAlign.justify,
                      maxLines: _expanded ? null : 3,
                      overflow:
                          _expanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.topic.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Text(
                        _expanded ? "Read less" : "Read more…",
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    "Created on 2021-10-29",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Media row (دمو)
            const Text(
              "Media, links, and docs",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder:
                    (_, i) => Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.image),
                    ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),

            // Settings-like
            tile(Icons.notifications, "Notifications", subtitle: "Highlights"),
            tile(Icons.image_outlined, "Media visibility"),
            tile(
              Icons.lock_outline,
              "Encryption",
              subtitle:
                  "Messages and calls are end-to-end encrypted. Tap to learn more.",
            ),
            tile(
              Icons.chat_bubble_outline,
              "Chat lock",
              subtitle: "Lock and hide this chat on this device.",
              trailing: Switch(value: false, onChanged: (_) {}),
            ),
            tile(
              Icons.privacy_tip_outlined,
              "Advanced chat privacy",
              subtitle: "Off",
            ),
            const Divider(),

            // Members
            Row(
              children: [
                const Text(
                  "اعضا",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                Text(
                  "${m.length} members",
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const Spacer(),
                IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
              ],
            ),
            const SizedBox(height: 8),

            ...m.map(
              (name) => ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(name),
                subtitle: const Text("Hey there! I am using WhatsApp."),
                trailing:
                    (name.hashCode % 5 == 0)
                        ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "Group Admin",
                            style: TextStyle(fontSize: 12),
                          ),
                        )
                        : null,
                onTap: () {},
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
