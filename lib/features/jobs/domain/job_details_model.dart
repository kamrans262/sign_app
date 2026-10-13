import 'job_model.dart';

/// Frontend-only details supplied independently of the Jobs-list model.
/// An API may replace this data without changing the presentation widgets.
class JobDetailsModel {
  const JobDetailsModel({
    required this.job,
    required this.quoteAmountChf,
    required this.expensesChf,
    required this.labourCostChf,
    required this.depositsChf,
    required this.invoicedChf,
    required this.receivedChf,
    required this.remainingBalanceChf,
    required this.sections,
  });

  final JobModel job;
  final int quoteAmountChf;
  final int expensesChf;
  final int labourCostChf;
  final int depositsChf;
  final int invoicedChf;
  final int receivedChf;
  final int remainingBalanceChf;
  final List<JobSectionDetails> sections;

  /// Screenshot reference amounts are intentionally independent, not a ledger.
  factory JobDetailsModel.demoFor(JobModel job) => JobDetailsModel(
    job: job,
    quoteAmountChf: 24500,
    expensesChf: 24500,
    labourCostChf: 24500,
    depositsChf: 24500,
    invoicedChf: 24500,
    receivedChf: 24500,
    remainingBalanceChf: 4500,
    sections: const [
      JobSectionDetails(JobSection.quotes, '5 quotes'),
      JobSectionDetails(JobSection.addenda, '5 addenda'),
      JobSectionDetails(JobSection.documents, '12 files'),
      JobSectionDetails(JobSection.photos, '28 photos'),
      JobSectionDetails(JobSection.notes, '6 notes'),
      JobSectionDetails(JobSection.purchases, '8 items'),
      JobSectionDetails(JobSection.time, '42 hours'),
      JobSectionDetails(JobSection.deposits, '2 deposits'),
      JobSectionDetails(JobSection.siteReports, '4 reports'),
      JobSectionDetails(JobSection.acceptance, 'pending'),
      JobSectionDetails(JobSection.invoices, '5 invoices'),
    ],
  );

  static String formatChf(int amount) {
    final negative = amount < 0 ? '-' : '';
    final grouped = amount.abs().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '${negative}CHF $grouped';
  }
}

enum JobSection {
  quotes,
  addenda,
  documents,
  photos,
  notes,
  purchases,
  time,
  deposits,
  siteReports,
  acceptance,
  invoices;

  String get label => switch (this) {
    JobSection.quotes => 'Quotes',
    JobSection.addenda => 'Addenda',
    JobSection.documents => 'Documents',
    JobSection.photos => 'Photos',
    JobSection.notes => 'Notes',
    JobSection.purchases => 'Purchases',
    JobSection.time => 'Time',
    JobSection.deposits => 'Deposits',
    JobSection.siteReports => 'Site reports',
    JobSection.acceptance => 'Acceptance',
    JobSection.invoices => 'Invoices',
  };
}

class JobSectionDetails {
  const JobSectionDetails(this.section, this.subtitle);

  final JobSection section;
  final String subtitle;
}
