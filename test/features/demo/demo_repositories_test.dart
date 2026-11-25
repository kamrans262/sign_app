import 'package:flutter_test/flutter_test.dart';
import 'package:sign2digital/features/auth/data/demo_account_repository.dart';
import 'package:sign2digital/features/auth/domain/account_profile.dart';
import 'package:sign2digital/features/company/data/demo_company_repository.dart';
import 'package:sign2digital/features/company/domain/company_profile.dart';

void main() {
  test(
    'demo account repository stores only the non-secret account model',
    () async {
      final repository = DemoAccountRepository();
      expect(await repository.currentAccount(), isNull);
      final profile = AccountProfile(
        id: 'demo-a',
        fullName: 'Marc Example',
        email: 'marc@example.ch',
        countryIsoCode: 'CH',
        dialingCode: '+41',
        phoneNumber: '791234567',
      );
      await repository.saveDraft(profile);
      final stored = await repository.currentAccount();
      expect(stored?.fullName, 'Marc Example');
      expect(stored?.dialingCode, '+41');
    },
  );

  test(
    'demo company repository supplies sample and accepts local edits',
    () async {
      final repository = DemoCompanyRepository();
      expect((await repository.list()).single.companyName, 'Alpine Studio');
      final profile = CompanyProfile(
        id: 'demo-current-company',
        companyName: 'New Demo Company',
        address: '',
        countryIsoCode: 'CH',
        dialingCode: '+41',
        phoneNumber: '',
        email: 'office@example.ch',
        swissCompanyId: '',
        vatNumber: '',
        iban: '',
        qrIban: '',
        documentNumbering: '',
        logoFileName: 'brand.svg',
      );
      await repository.save(profile);
      expect((await repository.byId(profile.id))?.logoFileName, 'brand.svg');
      expect((await repository.list()).length, 2);
    },
  );
}
