import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../data/remote_notification_repository.dart';
import 'reminders_screen.dart';

/// M20 inbox, using the existing Sign2Digital header/card dimensions and colors.
/// No push-permission UI or Firebase tokens are requested in Stage 1.
class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key, this.repository});
  final RemoteNotificationRepository? repository;

  @override
  State<NotificationInboxScreen> createState() => _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  RemoteNotificationRepository get _repository =>
      widget.repository ?? RemoteNotificationRepository.shared;
  NotificationInboxSnapshot? _snapshot;
  bool _loading = true, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _repository.list();
      if (mounted) setState(() { _snapshot = result; _loading = false; });
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'Unable to load notifications. Tap to retry.';
      });
    }
  }

  Future<void> _change(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update notifications.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(InAppNotification item) async {
    if (!item.isRead) {
      await _change(() => _repository.markRead(item.id));
    }
    if (!mounted || item.linkType != 'reminder' || item.linkId == null) return;
    // The reminder destination independently checks the active company and
    // signed-in user's ownership; link metadata never grants authorization.
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const RemindersScreen(),
    ));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _snapshot?.records ?? const <InAppNotification>[];
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(child: Column(children: [
        Sign2DigitalHeader(
          title: 'Notifications',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            Expanded(child: Text(
              (_snapshot?.unreadCount ?? 0).toString() + ' unread',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
                  fontWeight: FontWeight.w600, color: AppColors.dark),
            )),
            TextButton(
              onPressed: _busy || rows.isEmpty ? null :
                () => _change(_repository.markAllRead),
              child: const Text('Mark all read'),
            ),
            IconButton(
              key: const Key('notifications-refresh'),
              tooltip: 'Refresh notifications',
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh, color: AppColors.primary),
            ),
          ]),
        ),
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                ? Center(child: TextButton(
                    onPressed: _load, child: Text(_error!)))
                : rows.isEmpty
                  ? const Center(child: Text('No notifications',
                      style: TextStyle(fontFamily: 'Inter',
                          color: AppColors.placeholder)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = rows[index];
                          return Material(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(10),
                            child: ListTile(
                              key: Key('notification-' + item.id.toString()),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color:
                                  AppColors.lightBorder),
                              ),
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE3ECF0),
                                child: Icon(Icons.notifications_none,
                                  color: AppColors.primary),
                              ),
                              title: Text(item.title,
                                style: TextStyle(
                                  fontFamily: 'Inter', fontSize: 15,
                                  color: AppColors.dark,
                                  fontWeight: item.isRead
                                      ? FontWeight.w500 : FontWeight.w700,
                                )),
                              subtitle: Text(item.body,
                                style: const TextStyle(
                                    fontFamily: 'Inter', fontSize: 13)),
                              onTap: () => _open(item),
                              trailing: IconButton(
                                key: Key('notification-dismiss-' +
                                    item.id.toString()),
                                tooltip: 'Dismiss',
                                onPressed: _busy ? null : () => _change(
                                    () => _repository.dismiss(item.id)),
                                icon: const Icon(Icons.close, size: 18),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ))),
      ])),
    );
  }
}