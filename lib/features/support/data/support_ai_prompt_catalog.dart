/// These sample prompts correspond only to screens with real AI Voice input.
/// They are examples to speak, not automatic create/submit actions.
class SupportAiPrompt {
  const SupportAiPrompt(this.title, this.prompt, this.destination);
  final String title;
  final String prompt;
  final String destination;
}

abstract final class SupportAiPromptCatalog {
  static const Map<String, SupportAiPrompt> examples = {
    'jobs': SupportAiPrompt('Create Job',
      'Create a kitchen renovation job for Ahmed Khan. Include plumbing and painting work with a budget of CHF 3,000.',
      'jobs'),
    'quotes': SupportAiPrompt('Create Quote',
      'Create a quotation for installing three wooden doors at CHF 450 each. Add CHF 150 for transport, 8.1% VAT and a 30% deposit.',
      'quotes'),
    'expenses': SupportAiPrompt('Add Expense',
      'Record a CHF 250 building materials expense from Bauhaus for the Kitchen Renovation job, paid in cash today.',
      'expenses'),
    'deposits': SupportAiPrompt('Add Deposit',
      'Record a CHF 400 bank transfer deposit received today from Ahmed Khan for the Kitchen Renovation job.',
      'deposits'),
    'invoices': SupportAiPrompt('Create Invoice',
      'Prepare an invoice for the Kitchen Renovation job with six hours of labour at CHF 40 per hour and CHF 120 materials.',
      'invoices'),
    'labour': SupportAiPrompt('Add Labour',
      'Add six hours of carpentry labour by Ahmed today at CHF 40 per hour for the Kitchen Renovation job.',
      'labour'),
    'equipment': SupportAiPrompt('Add Equipment',
      'Add a Bosch drill with equipment ID DR-101, category Construction, available in the workshop.',
      'equipment'),
    'ai_documents': SupportAiPrompt('AI Document',
      'Generate an AI document about the Kitchen Renovation site meeting covering materials, schedule and next steps.',
      'ai_documents'),
  };

  static SupportAiPrompt? forModule(String module) => examples[module];
}
