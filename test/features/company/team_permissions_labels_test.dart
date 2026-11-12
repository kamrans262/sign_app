import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/company/presentation/screens/company_team_screen.dart';

void main() {
  test('readable labels never change API permission keys', () {
    expect(CompanyTeamScreen.permissionLabel('clients.read'), 'Client - Read');
    expect(CompanyTeamScreen.permissionLabel('clients.write'), 'Client - Write');
    expect(CompanyTeamScreen.permissionLabel('jobs.read'), 'Job - Read');
    expect(CompanyTeamScreen.permissionLabel('jobs.write'), 'Job - Write');
    expect(CompanyTeamScreen.permissionLabel('documents.read'), 'Document - Read');
    expect(CompanyTeamScreen.permissionLabel('quotes.read'), 'Quote - Read');
    expect(CompanyTeamScreen.permissionLabel('invoices.read'), 'Invoice - Read');
    expect(CompanyTeamScreen.permissionLabel('reports.read'), 'Report - Read');
    expect(CompanyTeamScreen.permissionLabel('expenses.read'), 'Expense - Read');
    expect(CompanyTeamScreen.permissionLabel('labour.read'), 'Time & Labour - Read');
    expect(CompanyTeamScreen.permissionLabel('equipment.write'), 'Equipment - Write');
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
