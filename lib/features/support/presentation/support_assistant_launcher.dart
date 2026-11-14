import 'package:flutter/material.dart';
import '../../../core/navigation/sign2digital_navigation.dart';
import '../../../core/services/active_company_session.dart';
import '../../../core/widgets/sign2digital_styled_bottom_sheet.dart';
import '../../auth/data/mobile_auth_repository.dart';
import '../../profile/presentation/screens/help_support_screen.dart';
import '../../profile/presentation/screens/profile_settings_screen.dart';
import '../data/support_assistant_repository.dart';
import 'widgets/support_assistant_sheet.dart';

/// Shared entry point. The dashboard can supply its own existing tab/action
/// navigation. Other module headers still open AI Help and standard Help Center.
abstract final class SupportAssistantLauncher {
  static Future<void> show(BuildContext context, {
    required String screen,
    ValueChanged<String>? onNavigate,
    SupportAssistantRepository? repository,
    String? sampleModule,
  }) async {
    final result = await showSign2DigitalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Support provides its own compact approved drag handle.
      showDragHandle: false,
      builder: (sheetContext) => SupportAssistantSheet(
        screen: screen,
        sampleModule: sampleModule,
        repository: repository ?? RemoteSupportAssistantRepository.shared,
        authenticated: MobileAuthRepository.shared.isSignedIn),
    );
    if (result == null || !context.mounted) return;
    if (onNavigate != null) {
      onNavigate(result);
      return;
    }
    if (result == 'jobs' &&
        Sign2DigitalNavigation.selectDashboardTab(context, 1)) return;
    if (result == 'clients' &&
        Sign2DigitalNavigation.selectDashboardTab(context, 2)) return;
    if ((result == 'quotes' || result == 'documents') &&
        Sign2DigitalNavigation.selectDashboardTab(context, 3)) return;
    if (const {'equipment', 'reports', 'reminders', 'ai_documents'}.contains(result) &&
        Sign2DigitalNavigation.selectDashboardTab(context, 4)) return;
    if (result == 'support') {
      await Sign2DigitalNavigation.open<void>(
          context, const HelpSupportScreen());
    } else if (result == 'settings') {
      await Sign2DigitalNavigation.open<void>(
          context, const ProfileSettingsScreen());
    } else {
      final msg = ActiveCompanySession.companyId == null
          ? 'Select or create a company to open that module.'
          : 'Open this module from the Home or More tab.';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(msg)));
    }
  }
}
