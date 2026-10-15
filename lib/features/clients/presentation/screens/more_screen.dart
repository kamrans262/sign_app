import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../documents/presentation/screens/reports_screen.dart';
import '../../../documents/presentation/screens/ai_documents_screen.dart';
import '../../../documents/presentation/screens/generate_ai_document_screen.dart';
import '../../../expenses/presentation/screens/expenses_screen.dart';
import '../../../deposits/presentation/screens/deposits_screen.dart';
import '../../../equipment/presentation/screens/equipment_screen.dart';
import '../../../global_search/presentation/screens/global_search_screen.dart';
import '../../../invoices/presentation/screens/invoices_screen.dart';
import '../../../labour/presentation/screens/time_labour_screen.dart';
import '../../../quotes/presentation/screens/quote_ui_demo_screen.dart';
import '../../../profile/presentation/screens/profile_settings_screen.dart';
import '../../../subscription/presentation/screens/subscription_overview_screen.dart';
import '../../../subscription/presentation/screens/subscription_management_screen.dart';

/// Entry points for UI-only tools belong to More, not the Clients list.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, this.onTabSelected, this.onNotReady,
    this.documentGenerator});
  final ValueChanged<int>? onTabSelected;
  final ValueChanged<String>? onNotReady;
  final AiDocumentGenerator? documentGenerator;

  Future<void> _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ListView(
        key: const Key('more-menu-scroll'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
        children: [
          _tile(context,
            key: const Key('open-profile-settings'),
            title: 'Profile & Settings',
            icon: Icons.account_circle_outlined,
            onTap: () => _open(context, ProfileSettingsScreen(
              onNavigationSelected: onTabSelected,
              onNotificationTap: () => onNotReady?.call('Notifications'),
            ))),
          const SizedBox(height: 15),
          _tile(context,
            key: const Key('open-global-search'),
            title: 'Search Across the App',
            icon: Icons.search_rounded,
            onTap: () => _open(context, GlobalSearchScreen(
              onNotificationTap: () => onNotReady?.call('Notifications'),
              onProfileTap: () => onNotReady?.call('Profile'),
            ))),
          const SizedBox(height: 15),
          _tile(context,
            key: const Key('open-subscription'),
            title: 'Subscription',
            icon: Icons.workspace_premium_outlined,
            onTap: () => _open(context, SubscriptionOverviewScreen(
              onNavigationSelected: onTabSelected,
              onNotificationTap: () => onNotReady?.call('Notifications'),
              onProfileTap: () => onNotReady?.call('Profile'),
            ))),
          const SizedBox(height: 15),
          _tile(context,
            key: const Key('open-subscription-management'),
            title: 'Subscription Management',
            icon: Icons.manage_accounts_outlined,
            onTap: () => _open(context, SubscriptionManagementScreen(
              onNavigationSelected: onTabSelected,
            ))),
          const SizedBox(height: 15),
          _tile(context,
            key: const Key('open-quote-ui-demo'),
            title: 'Quote UI Demo',
            icon: Icons.description_outlined,
            onTap: () => _open(context, const QuoteUiDemoScreen())),
          const SizedBox(height: 15),
          _tile(context,
            key: const Key('open-ai-documents'),
            title: 'AI Documents',
            icon: Icons.auto_awesome_outlined,
            onTap: () => _open(context, AiDocumentsScreen(
              documentGenerator: documentGenerator,
              onNavigationSelected: onTabSelected,
              onNotificationTap: () => onNotReady?.call('Notifications'),
              onProfileTap: () => onNotReady?.call('Profile'),
            ))),
          const SizedBox(height: 15),
          _tile(context,
            key: const Key('open-reports'),
            title: 'Reports',
            icon: Icons.assessment_outlined,
            onTap: () => _open(context, ReportsScreen(
              onNavigationSelected: onTabSelected,
              onNotificationTap: () => onNotReady?.call('Notifications'),
              onProfileTap: () => onNotReady?.call('Profile'),
            ))),
          const SizedBox(height: 15),
          _tile(context,
            key: const Key('open-time-labour'),
            title: 'Time & Labour',
            icon: Icons.access_time_outlined,
            onTap: () => _open(context, TimeLabourScreen(
              onNavigationSelected: onTabSelected,
              onNotificationTap: () => onNotReady?.call('Notifications'),
              onProfileTap: () => onNotReady?.call('Profile'),
            ))),
          const SizedBox(height: 15),
          _tile(context,
            key: const Key('open-invoices'),
            title: 'Invoices',
            icon: Icons.description_outlined,
            onTap: () => _open(context, InvoicesScreen(
              onNavigationSelected: onTabSelected,
              onNotificationTap: () => onNotReady?.call('Notifications'),
              onProfileTap: () => onNotReady?.call('Profile'),
            ))),
          const SizedBox(height: 15),
          _tile(context,
            key: const Key('open-equipment'),
            title: 'Equipment',
            icon: Icons.construction_outlined,
            onTap: () => _open(context, EquipmentScreen(
              onNavigationSelected: onTabSelected,
              onNotificationTap: () => onNotReady?.call('Notifications'),
              onProfileTap: () => onNotReady?.call('Profile'),
            ))),
          const SizedBox(height: 15),
          _tile(context,
            key: const Key('open-deposits'),
            title: 'Deposits',
            icon: Icons.account_balance_outlined,
            onTap: () => _open(context, DepositsScreen(
              onNavigationSelected: onTabSelected,
              onNotificationTap: () => onNotReady?.call('Notifications'),
              onProfileTap: () => onNotReady?.call('Profile'),
            ))),
          const SizedBox(height: 15),
          _tile(context,
            key: const Key('open-expenses'),
            title: 'Expenses',
            icon: Icons.receipt_long_outlined,
            onTap: () => _open(context, ExpensesScreen(
              onNavigationSelected: onTabSelected,
              onNotificationTap: () => onNotReady?.call('Notifications'),
              onProfileTap: () => onNotReady?.call('Profile'),
            ))),
        ],
      ),
    ),
  );

  Widget _tile(BuildContext context, {required Key key,
    required String title, required IconData icon, required VoidCallback onTap}) =>
      Material(
        color: AppColors.white,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.lightBorder),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(icon, color: AppColors.primary, size: 24),
              const SizedBox(width: 15),
              Expanded(child: Text(title,
                style: const TextStyle(fontFamily: 'Inter',
                  fontSize: 16, fontWeight: FontWeight.w600,
                  color: AppColors.dark))),
              const Icon(Icons.chevron_right_rounded,
                color: AppColors.secondaryText),
            ]),
          ),
        ),
      );
}
