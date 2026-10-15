import 'package:flutter/material.dart';

import '../../../jobs/presentation/screens/jobs_screen.dart';
import '../../../jobs/presentation/screens/job_details_screen.dart';
import '../../../jobs/domain/job_model.dart';
import '../../../home/presentation/screens/home_dashboard_screen.dart';
import '../../../quotes/presentation/screens/create_quote_screen.dart';
import '../../../documents/presentation/screens/documents_screen.dart';
import '../../../quotes/domain/quote_tracking_home_session.dart';
import '../../../quotes/presentation/screens/signature_request_screen.dart';
import '../../../profile/presentation/screens/profile_settings_screen.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_bottom_navigation_bar.dart';
import '../../../../core/widgets/sign2digital_dashboard_header.dart';
import '../../../../core/widgets/sign2digital_search_field.dart';
import '../../data/client_repository.dart';
import '../../data/demo_client_repository.dart';
import '../../domain/client_profile.dart';
import '../../domain/client_draft.dart';
import 'add_client_screen.dart';
import 'client_details_screen.dart';
import 'import_clients_screen.dart';
import 'more_screen.dart';
import '../widgets/sign2digital_client_card.dart';

/// Authenticated dashboard shell with Home, Jobs, Clients, Documents and More.
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key, this.repository});

  final ClientRepository? repository;

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  int _selectedIndex = 2;
  int _homeRefreshRevision = 0;
  late final ClientRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DemoClientRepository();
  }

  void _showNotReady(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action is not connected yet. This is a UI preview.'),
      ),
    );
  }

  void _goToTab(int index) {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedIndex = index;
      if (index == 0) _homeRefreshRevision++;
    });
  }

  Future<void> _openHomeCreateQuote() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const CreateQuoteScreen()),
    );
    if (mounted) {
      setState(() => _homeRefreshRevision++);
    }
  }

  Future<void> _openHomeQuoteTracking() async {
    final quote = QuoteTrackingHomeSession.currentQuote;
    if (quote == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SignatureRequestScreen(
          quote: quote,
          selectedTab: 0,
          onNavigationSelected: (index) {
            Navigator.of(context).pop();
            _goToTab(index);
          },
        ),
      ),
    );
    if (mounted) {
      setState(() => _homeRefreshRevision++);
    }
  }

  Future<void> _openJobDetails(JobModel job) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JobDetailsScreen(
          job: job,
          onTabSelected: (index) {
            Navigator.of(context).pop();
            if (mounted) {
              setState(() => _selectedIndex = index);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentQuote = QuoteTrackingHomeSession.currentQuote;
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Sign2DigitalDashboardHeader(
              onNotificationTap: () => _showNotReady('Notifications'),
              onProfileTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => ProfileSettingsScreen(
                    onNotificationTap: () => _showNotReady('Notifications'),
                    onNavigationSelected: (index) {
                      if (mounted) setState(() => _selectedIndex = index);
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  HomeDashboardScreen(
                    clientRepository: _repository,
                    selectedQuote: currentQuote,
                    refreshRevision: _homeRefreshRevision,
                    onNavigate: _goToTab,
                    onJobTap: _openJobDetails,
                    onCreateQuote: _openHomeCreateQuote,
                    onOpenQuoteTracking: _openHomeQuoteTracking,
                  ),
                  JobsScreen(
                    onNotReady: _showNotReady,
                    onJobTap: _openJobDetails,
                  ),
                  _ClientsContent(
                    repository: _repository,
                    showNotReady: _showNotReady,
                    onTabSelected: (index) =>
                        setState(() => _selectedIndex = index),
                  ),
                  const DocumentsScreen(),
                  MoreScreen(
                    onTabSelected: (index) {
                      if (mounted) setState(() => _selectedIndex = index);
                    },
                    onNotReady: _showNotReady,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Sign2DigitalBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onSelected: _goToTab,
      ),
    );
  }
}

class _ClientsContent extends StatefulWidget {
  const _ClientsContent({
    required this.repository,
    required this.showNotReady,
    required this.onTabSelected,
  });

  final ClientRepository repository;
  final ValueChanged<String> showNotReady;
  final ValueChanged<int> onTabSelected;

  @override
  State<_ClientsContent> createState() => _ClientsContentState();
}

class _ClientsContentState extends State<_ClientsContent> {
  final _search = TextEditingController();
  List<ClientProfile> _clients = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    try {
      final clients = await widget.repository.listClients();
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load clients';
      });
    }
  }

  Future<void> _openImportClients() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final tabIndex = await Navigator.of(
      context,
    ).push<int>(MaterialPageRoute<int>(builder: (_) => ImportClientsScreen()));
    if (tabIndex != null && mounted) {
      widget.onTabSelected(tabIndex);
    }
  }

  Future<void> _openAddClient() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final draft = await Navigator.of(context).push<ClientDraft>(
      MaterialPageRoute<ClientDraft>(builder: (_) => AddClientScreen()),
    );
    if (draft == null || !mounted) return;
    try {
      await widget.repository.createClient(draft);
      if (!mounted) return;
      _search.clear();
      await _loadClients();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Client added to the local demo list')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to add the client to the demo list')),
      );
    }
  }

  Future<void> _openClientDetails(ClientProfile client) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ClientDetailsScreen(client: client, repository: widget.repository),
      ),
    );
    if (!mounted) {
      return;
    }
    // Reload after editing without discarding the current search query.
    await _loadClients();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _clients
        .where((item) => item.matches(_search.text))
        .toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: CustomScrollView(
          key: const Key('clients-scroll'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Sign2DigitalSearchField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      onTrailingTap: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 330;
                        final importButton = _ClientsActionButton(
                          label: 'Import from Contacts',
                          outlined: true,
                          onTap: _openImportClients,
                        );
                        final addButton = _ClientsActionButton(
                          label: 'Add Client Manually',
                          outlined: false,
                          onTap: _openAddClient,
                        );
                        if (narrow) {
                          return Column(
                            children: [
                              importButton,
                              const SizedBox(height: 12),
                              addButton,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: importButton),
                            const SizedBox(width: 16),
                            Expanded(child: addButton),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() => _loading = true);
                      _loadClients();
                    },
                    child: Text('$_error. Tap to retry.'),
                  ),
                ),
              )
            else if (matches.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _search.text.isEmpty
                          ? 'No clients yet'
                          : 'No clients match your search',
                      style: AppTextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, index) => Padding(
                    key: ValueKey(matches[index].id),
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Sign2DigitalClientCard(
                      client: matches[index],
                      onTap: () => _openClientDetails(matches[index]),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClientsActionButton extends StatelessWidget {
  const _ClientsActionButton({
    required this.label,
    required this.onTap,
    required this.outlined,
  });

  final String label;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 13),
          )
        : FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 13),
          );
    final child = Center(
      child: Text(
        label,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: outlined
          ? OutlinedButton(onPressed: onTap, style: style, child: child)
          : FilledButton(onPressed: onTap, style: style, child: child),
    );
  }
}
