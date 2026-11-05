import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_entry_list_card.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../data/demo_reminder_repository.dart';
import '../../data/remote_reminder_repository.dart';
import '../../../auth/data/mobile_auth_repository.dart';
import '../../domain/reminder_record.dart';
import 'add_reminder_screen.dart';
import 'notification_inbox_screen.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({
    super.key, this.repository, this.referenceSource,
    this.onNavigationSelected, this.onNotificationTap,
    this.onProfileTap, this.now, this.selectedNavigationIndex = 4,
  });

  final ReminderRepository? repository;
  final ReminderReferenceSource? referenceSource;
  final ValueChanged<int>? onNavigationSelected;
  final VoidCallback? onNotificationTap, onProfileTap;
  final DateTime Function()? now;
  final int selectedNavigationIndex;

  // Injected repositories remain authoritative for previews/tests. Production
  // signed-in sessions must never silently fall back to session-local demo data.
  static ReminderRepository repositoryForSession(bool signedIn,
      [ReminderRepository? provided]) =>
      provided ?? (signedIn
          ? RemoteReminderRepository.shared
          : const DemoReminderRepository());

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  late final ReminderRepository _repository;
  final _search = TextEditingController();
  List<ReminderRecord> _all = [];
  ReminderFilter _tab = ReminderFilter.all;
  bool _loading = true;
  String? _error;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _repository = RemindersScreen.repositoryForSession(
        MobileAuthRepository.shared.isSignedIn, widget.repository);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final reminders = await _repository.listReminders();
      if (!mounted) return;
      setState(() { _all = reminders; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load reminders';
          _loading = false;
        });
      }
    }
  }

  List<ReminderRecord> get _visible {
    final now = _now;
    final items = _all.where((item) =>
      (_tab == ReminderFilter.all || item.filterAt(now) == _tab) &&
      item.matches(_search.text)).toList();
    items.sort((a, b) {
      // Upcoming deadlines first, then overdue and completed history.
      final aRank = a.completed ? 2 : a.remindAt.isBefore(now) ? 1 : 0;
      final bRank = b.completed ? 2 : b.remindAt.isBefore(now) ? 1 : 0;
      if (aRank != bRank) return aRank.compareTo(bRank);
      final order = aRank == 0
        ? a.remindAt.compareTo(b.remindAt)
        : b.remindAt.compareTo(a.remindAt);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return items;
  }

  String _badge(ReminderRecord record) {
    if (record.completed) return 'Completed';
    final now = _now;
    final day = DateTime(now.year, now.month, now.day);
    final date = record.remindAt;
    if (date.year == day.year && date.month == day.month &&
        date.day == day.day && !date.isBefore(now)) {
      return 'Today';
    }
    if (date.isBefore(now)) return 'Overdue';
    return 'Upcoming';
  }

  static String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final min = value.minute == 0 ? '' : ':${value.minute.toString().padLeft(2, '0')}';
    return '$hour$min ${value.hour < 12 ? 'AM' : 'PM'}';
  }

  String _date(ReminderRecord record) {
    final date = record.remindAt;
    final now = _now;
    if (date.year == now.year && date.month == now.month &&
        date.day == now.day) {
      return 'Today at ${_time(date)}';
    }
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug',
      'Sep','Oct','Nov','Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year} at ${_time(date)}';
  }

  void _notice(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _edit(ReminderRecord? original) async {
    final result = await Navigator.of(context).push<ReminderRecord>(
      MaterialPageRoute<ReminderRecord>(
        builder: (_) => AddReminderScreen(
          initialReminder: original,
          referenceSource: widget.referenceSource,
        ),
      ),
    );
    if (result == null || !mounted) return;
    try {
      if (original == null) {
        await _repository.saveReminder(result);
      } else {
        await _repository.updateReminder(result);
      }
      if (!mounted) return;
      _search.clear();
      setState(() => _tab = ReminderFilter.all);
      await _load();
      _notice(_repository is DemoReminderRepository
          ? 'Reminder saved locally (demo only).'
          : 'Reminder saved.');
    } catch (_) {
      _notice('Unable to save reminder. Please try again.');
    }
  }

  Widget _card(ReminderRecord item) => Sign2DigitalEntryListCard(
    key: Key('reminder-card-${item.id}'),
    shadow: true,
    leading: const CircleAvatar(
      radius: 20, backgroundColor: Color(0xFFE3ECF0),
      child: Icon(Icons.language_outlined, size: 24, color: AppColors.primary),
    ),
    title: item.title,
    titleKey: Key('reminder-title-${item.id}'),
    subtitle: item.relatedItem?.project.isNotEmpty == true
        ? item.relatedItem!.project
        : item.relatedItem?.title ?? item.type.label,
    dateText: _date(item),
    trailingValue: '', showTrailingValue: false,
    status: _badge(item),
    onTap: () => _edit(item),
  );

  void _navigation(int index) {
    if (index == widget.selectedNavigationIndex) return;
    if (widget.onNavigationSelected == null) {
      Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).pop();
    widget.onNavigationSelected!(index);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(bottom: false, child: Column(children: [
        Sign2DigitalDashboardHeader(
          onNotificationTap: widget.onNotificationTap ?? () {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const NotificationInboxScreen()));
          },
          onProfileTap: widget.onProfileTap),
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Stack(children: [
            CustomScrollView(
              key: const Key('reminders-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverToBoxAdapter(child: Column(children: [
                    Sign2DigitalSearchField(
                      controller: _search,
                      hintText: 'Search Reminders',
                      onChanged: (_) => setState(() {}),
                      onTrailingTap: () =>
                          FocusManager.instance.primaryFocus?.unfocus()),
                    const SizedBox(height: 20),
                    Stack(children: [
                      const Positioned(left: 0, right: 0, bottom: 0,
                        child: Divider(height: 1, thickness: 1,
                          color: AppColors.lightBorder)),
                      Sign2DigitalDetailsTabs(
                        labels: const ['All', 'Upcoming', 'Overdue', 'Completed'],
                        horizontalPadding: 15,
                        selectedIndex: _tab.index,
                        onSelected: (index) =>
                          setState(() => _tab = ReminderFilter.values[index])),
                    ]),
                  ])),
                ),
                if (_loading)
                  const SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()))
                else if (_error != null)
                  SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: TextButton(
                      key: const Key('reminders-retry'), onPressed: _load,
                      child: Text('$_error. Tap to retry.'))))
                else if (visible.isEmpty)
                  const SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: Text('No reminders found',
                      key: Key('reminders-empty'),
                      style: TextStyle(fontFamily: 'Inter',
                        color: AppColors.placeholder))))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 95),
                    sliver: SliverList.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: index < visible.length - 1 ? 20 : 0),
                        child: _card(visible[index]),
                      ),
                    ),
                  ),
              ],
            ),
            Positioned(right: 20, bottom: 20,
              child: SizedBox(width: 50, height: 50,
                child: FloatingActionButton(
                  key: const Key('reminders-add'),
                  heroTag: 'reminders-add',
                  tooltip: 'Add Reminder',
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 3, onPressed: () => _edit(null),
                  child: const Icon(Icons.add, size: 30)))),
          ]),
        ))),
      ])),
      bottomNavigationBar: Sign2DigitalBottomNavigationBar(
        selectedIndex: widget.selectedNavigationIndex,
        onSelected: _navigation),
    );
  }
}
