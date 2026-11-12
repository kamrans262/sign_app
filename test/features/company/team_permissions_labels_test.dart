import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/company/presentation/screens/company_team_screen.dart';

void main() {
  test('readable labels never change API permission keys', () {
    expect(CompanyTeamScreen.permissionLabel('clients.read'), 'View Clients');
    expect(CompanyTeamScreen.permissionLabel('jobs.write'), 'Manage Jobs');
    expect(CompanyTeamScreen.permissionLabel('labour.read'), 'View Time & Labour');
    expect(CompanyTeamScreen.permissionLabel('equipment.write'), 'Manage Equipment');
  });
  test('member preset manages clients/jobs but views other modules', () {
    final grants = CompanyTeamScreen.defaultPermissions('member').toSet();
    expect(grants, containsAll([
      'clients.read', 'clients.write', 'jobs.read', 'jobs.write',
      'quotes.read', 'documents.read', 'invoices.read', 'reports.read',
      'expenses.read', 'labour.read', 'equipment.read',
    ]));
    expect(grants, isNot(contains('invoices.write')));
    expect(grants, isNot(contains('documents.write')));
    expect(grants.length, 11);
  });

  test('admin preset checks all 18 module read/write permissions', () {
    final grants = CompanyTeamScreen.defaultPermissions('admin').toSet();
    expect(grants.length, 18);
    expect(grants, containsAll(['invoices.write', 'quotes.write',
      'equipment.write', 'labour.write', 'reports.write']));
  });

}
