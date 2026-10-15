import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_list_sort_control.dart';
import '../../../../core/widgets/sign2digital_outlined_container.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../../clients/presentation/widgets/sign2digital_status_badge.dart';
import '../../data/demo_equipment_repository.dart';
import '../../domain/equipment_record.dart';
import 'add_equipment_screen.dart';
import 'equipment_details_screen.dart';

enum EquipmentSort {
  newest('Date (newest)'), oldest('Date (oldest)'),
  name('Name (A–Z)'), id('Equipment ID');
  const EquipmentSort(this.label);
  final String label;
}

/// Equipment listing follows Deposits/Expenses layout and navigation.
class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({
    super.key, this.repository, this.onEquipmentTap,
    this.onCreateEquipment, this.onNavigationSelected,
    this.onNotificationTap, this.onProfileTap,
  });

  final EquipmentRepository? repository;
  final ValueChanged<EquipmentRecord>? onEquipmentTap;
  final VoidCallback? onCreateEquipment;
  final ValueChanged<int>? onNavigationSelected;
  final VoidCallback? onNotificationTap, onProfileTap;

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  late final EquipmentRepository _repository;
  final _search = TextEditingController();
  List<EquipmentRecord> _records = [];
  EquipmentSort _sort = EquipmentSort.newest;
  int _tab = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const DemoEquipmentRepository();
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
      final all = await _repository.listEquipment();
      if (mounted) setState(() { _records = all; _loading = false; });
    } catch (_) {
      if (mounted) setState(() {
        _loading = false; _error = 'Unable to load equipment';
      });
    }
  }

  List<EquipmentRecord> get _visible {
    final result = _records.where((item) =>
      (_tab == 0 || item.status == EquipmentStatus.values[_tab - 1]) &&
      item.matches(_search.text)).toList();
    result.sort((a, b) {
      final order = switch (_sort) {
        EquipmentSort.newest => b.purchaseDate.compareTo(a.purchaseDate),
        EquipmentSort.oldest => a.purchaseDate.compareTo(b.purchaseDate),
        EquipmentSort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        EquipmentSort.id => a.id.compareTo(b.id),
      };
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
    return result;
  }

  Future<void> _sortMenu() async {
    final chosen = await showModalBottomSheet<EquipmentSort>(
      context: context,
      builder: (sheet) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Sort By')),
          for (final option in EquipmentSort.values)
            ListTile(
              key: Key('equipment-sort-${option.name}'),
              title: Text(option.label),
              trailing: _sort == option
                  ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () => Navigator.of(sheet).pop(option),
            ),
        ],
      )),
    );
    if (chosen != null && mounted) setState(() => _sort = chosen);
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _open(EquipmentRecord record) async {
    if (widget.onEquipmentTap != null) {
      widget.onEquipmentTap!(record);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => EquipmentDetailsScreen(
        equipment: record, repository: _repository)),
    );
    if (mounted) await _load();
  }

  Future<void> _create() async {
    if (widget.onCreateEquipment != null) {
      widget.onCreateEquipment!();
      return;
    }
    final result = await Navigator.of(context).push<EquipmentRecord>(
      MaterialPageRoute<EquipmentRecord>(
        builder: (_) => AddEquipmentScreen(
          availableNames: _records.map((r) => r.name).toSet().toList(),
        )),
    );
    if (result == null || !mounted) return;
    try {
      await _repository.saveEquipment(result);
      if (!mounted) return;
      _search.clear();
      setState(() => _tab = 0);
      await _load();
      _notice('Equipment saved locally.');
    } catch (_) {
      _notice('Unable to save equipment. Check for an existing Equipment ID.');
    }
  }

  Widget _photo(EquipmentRecord record) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(
      width: 50, height: 50,
      child: record.photos.isEmpty
          ? const ColoredBox(
              color: Color(0xFFE3ECF0),
              child: Icon(Icons.construction_outlined,
                size: 28, color: AppColors.primary))
          : Image.memory(record.photos.first.bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined)),
    ),
  );

  Widget _card(EquipmentRecord record) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: Key('equipment-card-${record.id}'),
      onTap: () => _open(record),
      borderRadius: BorderRadius.circular(10),
      child: Sign2DigitalOutlinedContainer(
        padding: const EdgeInsets.all(15),
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 310;
          return Row(children: [
            _photo(record),
            SizedBox(width: compact ? 10 : 15),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.name,
                  key: Key('equipment-title-${record.id}'),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 16,
                    fontWeight: FontWeight.w600, color: AppColors.dark)),
                const SizedBox(height: 5),
                Text(record.id, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13,
                    color: AppColors.placeholder)),
                Text(record.category, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13,
                    color: AppColors.placeholder)),
              ],
            )),
            const SizedBox(width: 6),
            Sign2DigitalStatusBadge(status: record.status.label),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, size: 24,
              color: AppColors.secondaryText),
          ]);
        }),
      ),
    ),
  );

  void _navigation(int index) {
    if (index == 4) return;
    Navigator.of(context).maybePop();
    widget.onNavigationSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(bottom: false, child: Column(children: [
        Sign2DigitalDashboardHeader(
          onNotificationTap: widget.onNotificationTap,
          onProfileTap: widget.onProfileTap),
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Stack(children: [
            CustomScrollView(
              key: const Key('equipment-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  sliver: SliverToBoxAdapter(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Sign2DigitalSearchField(
                        controller: _search, hintText: 'Search Equipment',
                        onChanged: (_) => setState(() {}),
                        onTrailingTap: () =>
                          FocusManager.instance.primaryFocus?.unfocus()),
                      const SizedBox(height: 20),
                      Stack(children: [
                        const Positioned(left: 0, right: 0, bottom: 0,
                          child: Divider(height: 1, thickness: 1,
                            color: AppColors.lightBorder)),
                        Sign2DigitalDetailsTabs(
                          labels: const ['All', 'In Use', 'Available', 'Maintenance'],
                          horizontalPadding: 15,
                          selectedIndex: _tab,
                          onSelected: (i) => setState(() => _tab = i)),
                      ]),
                      const SizedBox(height: 20),
                      Sign2DigitalListSortControl(
                        key: const Key('equipment-sort'),
                        value: _sort.label, onTap: _sortMenu),
                    ],
                  )),
                ),
                if (_loading)
                  const SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()))
                else if (_error != null)
                  SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: TextButton(
                      key: const Key('equipment-retry'),
                      onPressed: _load, child: Text('$_error. Tap to retry.'))))
                else if (visible.isEmpty)
                  const SliverFillRemaining(hasScrollBody: false,
                    child: Center(child: Text('No matching equipment',
                      key: Key('equipment-empty'),
                      style: TextStyle(color: AppColors.placeholder))))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 95),
                    sliver: SliverList.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, i) => Padding(
                        padding: EdgeInsets.only(
                          bottom: i == visible.length - 1 ? 0 : 20),
                        child: _card(visible[i]),
                      ),
                    ),
                  ),
              ],
            ),
            Positioned(right: 20, bottom: 20,
              child: SizedBox(width: 50, height: 50,
                child: FloatingActionButton(
                  key: const Key('equipment-create'),
                  heroTag: 'equipment-create',
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 3, onPressed: _create,
                  child: const Icon(Icons.add, size: 30)))),
          ]),
        ))),
      ])),
      bottomNavigationBar: Sign2DigitalBottomNavigationBar(
        selectedIndex: 4, onSelected: _navigation),
    );
  }
}
