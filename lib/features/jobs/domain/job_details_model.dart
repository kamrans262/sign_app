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
    this.financialsAvailable = true,
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
  final bool financialsAvailable;

  /// Live jobs do not inherit any fictitious figures from screenshot demos.
  factory JobDetailsModel.liveUnconnected(JobModel job) => JobDetailsModel(
    job: job,
    quoteAmountChf: 0, expensesChf: 0, labourCostChf: 0,
    depositsChf: 0, invoicedChf: 0, receivedChf: 0,
    remainingBalanceChf: 0, financialsAvailable: false,
    sections: [
      for (final section in JobSection.values)
        JobSectionDetails(section, 'Not connected yet'),
    ],
  );

  /// New local jobs must not inherit fictional financial amounts or files.
  /// Existing screenshot sample records retain their original demo details.
  factory JobDetailsModel.demoFor(JobModel job) {
    if (job.id.startsWith('local-job-')) {
      return JobDetailsModel(
        job: job,
        quoteAmountChf: 0,
        expensesChf: 0,
        labourCostChf: 0,
        depositsChf: 0,
        invoicedChf: 0,
        receivedChf: 0,
        remainingBalanceChf: 0,
        sections: const [
          JobSectionDetails(JobSection.quotes, '0 quotes'),
          JobSectionDetails(JobSection.addenda, '0 addenda'),
          JobSectionDetails(JobSection.documents, '0 files'),
          JobSectionDetails(JobSection.photos, '0 photos'),
          JobSectionDetails(JobSection.notes, '0 notes'),
          JobSectionDetails(JobSection.purchases, '0 items'),
          JobSectionDetails(JobSection.time, '0 hours'),
          JobSectionDetails(JobSection.deposits, '0 deposits'),
          JobSectionDetails(JobSection.siteReports, '0 reports'),
          JobSectionDetails(JobSection.acceptance, 'pending'),
          JobSectionDetails(JobSection.invoices, '0 invoices'),
        ],
      );
    }
    // Screenshot reference amounts are intentionally not an accounting ledger.
    return JobDetailsModel(
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
  }

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
