import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/company/presentation/screens/company_team_screen.dart';

void main() {
  test('readable labels never change API permission keys', () {
    expect(CompanyTeamScreen.permissionLabel('clients.read'), 'View Clients');
    expect(CompanyTeamScreen.permissionLabel('jobs.write'), 'Manage Jobs');
    expect(CompanyTeamScreen.permissionLabel('labour.read'), 'View Time & Labour');
    expect(CompanyTeamScreen.permissionLabel('equipment.write'), 'Manage Equipment');
  });
}
