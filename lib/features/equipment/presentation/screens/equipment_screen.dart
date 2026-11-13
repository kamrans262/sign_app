import '../../../../core/navigation/sign2digital_navigation.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/sign2digital_styled_bottom_sheet.dart';

import '../../../../core/services/active_company_session.dart';
import '../../../auth/data/mobile_auth_repository.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_primary_button.dart';
import '../../../../core/widgets/sign2digital_list_sort_control.dart';
import '../../../../core/widgets/sign2digital_entry_list_card.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../../clients/presentation/widgets/sign2digital_details_tabs.dart';
import '../../data/demo_equipment_repository.dart';
import '../../data/remote_equipment_repository.dart';
import '../../domain/equipment_record.dart';
import 'add_equipment_screen.dart';
import 'equipment_details_screen.dart';
import 'equipment_loans_screen.dart';

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
  int _loadGeneration=0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
      (MobileAuthRepository.shared.isSignedIn
        ?RemoteEquipmentRepository.shared:const DemoEquipmentRepository());
    ActiveCompanySession.selected.addListener(_companyChanged);
    _load();
  }

  void _companyChanged(){if(mounted)_load();}

  @override
  void dispose() {
    ActiveCompanySession.selected.removeListener(_companyChanged);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final generation=++_loadGeneration;
    setState(() { _loading = true; _error = null; _records=[]; });
    try {
      final all = await _repository.listEquipment();
      if (mounted&&generation==_loadGeneration) setState(() { _records = all; _loading = false; });
    } catch (_) {
      if (mounted&&generation==_loadGeneration) {
        setState(() {
          _loading = false;
          _error = 'Unable to load equipment';
        });
      }
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
    final chosen = await showSign2DigitalBottomSheet<EquipmentSort>(
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
    EquipmentRecord current=record;
    if(_repository is RemoteEquipmentRepository){
      try{
        current=await (_repository as RemoteEquipmentRepository).detail(record);
      }catch(_){
        _notice('Unable to load verified equipment details.');
        return;
      }
    }
    if(!mounted)return;
    await Sign2DigitalNavigation.push<void>(context,
      MaterialPageRoute<void>(builder: (_) => EquipmentDetailsScreen(
        equipment: current, repository: _repository)),
    );
    if (mounted) await _load();
  }

  Future<void> _create() async {
    if (widget.onCreateEquipment != null) {
      widget.onCreateEquipment!();
      return;
    }
    final result = await Sign2DigitalNavigation.push<EquipmentRecord>(context,
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
      _notice(_repository is RemoteEquipmentRepository
        ?'Equipment saved to company records.':'Equipment saved in demo preview.');
    } catch (_) {
      _notice('Unable to save equipment. Check for an existing Equipment ID.');
    }
  }

  Widget _photo(EquipmentRecord record) => CircleAvatar(
    key: Key('equipment-leading-${record.id}'),
    radius: 20,
    backgroundColor: const Color(0xFFE3ECF0),
    child: record.photos.isEmpty
        ? const Icon(Icons.construction_outlined,
            size: 24, color: AppColors.primary)
        : ClipOval(
            child: Image.memory(record.photos.first.bytes,
              width: 40, height: 40, fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image_outlined,
                size: 24, color: AppColors.primary))),
  );

  // Exactly the same rounded card, typography, status and chevron as
  // Expenses, Deposits and Invoices; Equipment has no monetary amount.
  Widget _card(EquipmentRecord record) => Sign2DigitalEntryListCard(
    key: Key('equipment-card-${record.id}'),
    shadow: true,
    leading: _photo(record),
    title: record.name,
    titleKey: Key('equipment-title-${record.id}'),
    subtitle: record.id,
    dateText: record.category,
    trailingValue: '',
    showTrailingValue: false,
    status: record.status.label,
    onTap: () => _open(record),
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
                      const SizedBox(height: 12),
                      Sign2DigitalPrimaryButton(
                        key: const Key('equipment-open-loans'),
                        label: 'Equipment Loans',
                        height: 48,
                        onPressed: () => Sign2DigitalNavigation.push(context,
                          MaterialPageRoute<void>(
                            builder: (_) => const EquipmentLoansScreen())),
                      ),
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
            if (ActiveCompanySession.canWrite('equipment'))
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
