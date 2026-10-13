import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sign2digital_header.dart';
import '../../../jobs/presentation/widgets/sign2digital_job_progress_indicator.dart';
import '../../domain/quote_draft_input.dart';
import '../../domain/quote_extraction_models.dart';
import '../../domain/quote_preparation_service.dart';
import '../../domain/quote_review_models.dart';
import '../widgets/sign2digital_extracted_information_card.dart';
import 'review_quote_screen.dart';

/// Dedicated full-page quote preparation UI, distinct from the voice popup.
/// It never invents a percentage or marks AI guesses verified.
class QuoteAiProcessingScreen extends StatefulWidget {
  const QuoteAiProcessingScreen({
    super.key,
    this.input,
    this.service,
    this.initialSnapshot,
    this.demoReviewDraft,
    this.onReview,
    this.onStageChanged,
    this.onReviewStarted,
    this.onQuoteApproved,
  });

  /// The real source gathered on Create Quote.
  final QuoteDraftInput? input;
  final QuotePreparationService? service;

  /// Explicitly supplied state; use figmaPreview for design/testing only.
  final QuotePreparationSnapshot? initialSnapshot;
  /// Keeps the manual UI tour on the same quote; not an AI result.
  final QuoteReviewDraft? demoReviewDraft;
  final ValueChanged<QuotePreparationSnapshot>? onReview;
  /// Optional progress feedback to a source note without changing quote flow.
  final ValueChanged<QuotePreparationStage>? onStageChanged;
  final VoidCallback? onReviewStarted;
  final ValueChanged<QuoteReviewDraft>? onQuoteApproved;

  @override
  State<QuoteAiProcessingScreen> createState() => _QuoteAiProcessingScreenState();
}

class _QuoteAiProcessingScreenState extends State<QuoteAiProcessingScreen> {
  late QuotePreparationSnapshot _snapshot;
  StreamSubscription<QuotePreparationSnapshot>? _subscription;
  bool _showingDemo = false;
  int _generation = 0;
  QuoteReviewDraft? _reviewDraft;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot ??
        ((widget.service != null && widget.input != null)
            ? const QuotePreparationSnapshot(stage: QuotePreparationStage.preparing)
            : QuotePreparationSnapshot.unavailable);
    _showingDemo = _snapshot.isDemo;
    if (widget.service != null && widget.input != null) {
      _runService();
    }
  }

  void _runService() {
    final service = widget.service;
    final input = widget.input;
    if (service == null || input == null) {
      return;
    }
    _subscription?.cancel();
    final generation = ++_generation;
    // The caller marks preparation active before pushing this route.
    // Do not notify the previous route during this widget's initState/build.
    setState(() {
      _showingDemo = false;
      _reviewDraft = null;
      _snapshot = const QuotePreparationSnapshot(
        stage: QuotePreparationStage.preparing,
      );
    });
    try {
      _subscription = service.prepare(input).listen(
        (snapshot) {
          if (!mounted || generation != _generation) {
            return;
          }
          // Explicit demo snapshots cannot be passed off as a service response.
          if (snapshot.isDemo) {
            setState(() => _snapshot = const QuotePreparationSnapshot(
              stage: QuotePreparationStage.failed,
              message: 'The extraction service returned preview data rather than a real result.',
            ));
            _subscription?.cancel();
            return;
          }
          setState(() => _snapshot = snapshot);
          widget.onStageChanged?.call(snapshot.stage);
        },
        onError: (Object error, StackTrace trace) {
          if (!mounted || generation != _generation) {
            return;
          }
          widget.onStageChanged?.call(QuotePreparationStage.failed);
          setState(() => _snapshot = QuotePreparationSnapshot(
            stage: QuotePreparationStage.failed,
            message: 'Quote extraction failed. Please try again. $error',
            fields: _snapshot.fields,
            items: _snapshot.items,
            currency: _snapshot.currency,
            progressPercentage: _snapshot.progressPercentage,
          ));
        },
        onDone: () {
          if (!mounted || generation != _generation) {
            return;
          }
          if (_snapshot.stage == QuotePreparationStage.preparing ||
              _snapshot.stage == QuotePreparationStage.extracting ||
              _snapshot.stage == QuotePreparationStage.partial) {
            setState(() => _snapshot = QuotePreparationSnapshot(
              stage: QuotePreparationStage.failed,
              message: 'Quote extraction ended without a completed result.',
              fields: _snapshot.fields,
              items: _snapshot.items,
              currency: _snapshot.currency,
              progressPercentage: _snapshot.progressPercentage,
            ));
          }
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _snapshot = QuotePreparationSnapshot(
        stage: QuotePreparationStage.failed,
        message: 'Could not start quote extraction. $error',
      ));
    }
  }

  void _previewExample() {
    _generation++;
    _subscription?.cancel();
    setState(() {
      _showingDemo = true;
      _snapshot = QuotePreparationSnapshot.figmaPreview;
    });
  }

  void _back() {
    _generation++;
    _subscription?.cancel();
    Navigator.of(context).maybePop();
  }

  void _openReview() {
    if (!_showingDemo &&
        _snapshot.stage != QuotePreparationStage.completed) {
      return;
    }
    if (!_showingDemo && _snapshot.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No work items were extracted. Please try again.'),
      ));
      return;
    }
    if (!_showingDemo && widget.onReview != null) {
      widget.onReview!(_snapshot);
      return;
    }
    _reviewDraft ??= _showingDemo
        ? (widget.demoReviewDraft?.copy() ?? QuoteReviewDraft.figmaDemo())
        : QuoteReviewDraft.fromExtraction(_snapshot, widget.input);
    if (!mounted) {
      return;
    }
    widget.onReviewStarted?.call();
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => ReviewQuoteScreen(
        initialDraft: _reviewDraft!, onApproved: widget.onQuoteApproved),
    ));
  }

  @override
  void dispose() {
    _generation++;
    _subscription?.cancel();
    super.dispose();
  }

  bool get _working => switch (_snapshot.stage) {
    QuotePreparationStage.preparing ||
    QuotePreparationStage.extracting ||
    QuotePreparationStage.partial => !_showingDemo,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final completed = !_showingDemo &&
        _snapshot.stage == QuotePreparationStage.completed;
    // Completion of the extraction is measurable even when the API provides
    // no intermediate percentage. Do not imply the draft is approved.
    final progress = completed ? 100.0 : _snapshot.safeProgress;
    final showProgress = _working || _showingDemo || progress != null;
    final canReview = !_showingDemo &&
        _snapshot.stage == QuotePreparationStage.completed;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(child: Column(children: [
        Sign2DigitalHeader(title: 'Create Quote', onBack: _back),
        Expanded(child: SingleChildScrollView(
          key: const Key('quote-preparation-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
          child: LayoutBuilder(builder: (context, constraints) {
            return Center(child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth > 1024
                  ? 960 : constraints.maxWidth),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(child: Image.asset(
                    'assets/create_quote.png',
                    key: const Key('create-quote-illustration'),
                    width: 223, height: 168,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(width: 223, height: 168,
                          child: Center(child: Text('Quote illustration unavailable'))),
                  )),
                  const SizedBox(height: 25),
                  Text(_snapshot.stage == QuotePreparationStage.failed
                        ? 'Could Not Prepare Quote'
                        : completed
                            ? 'Quote Draft Ready'
                            : 'Preparing Your Quote...',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading),
                  const SizedBox(height: 10),
                  Text(
                    !_showingDemo && _snapshot.stage == QuotePreparationStage.unavailable
                        ? 'Quote extraction is not available yet. You can preview the design with clearly marked sample information.'
                        : !_showingDemo && _snapshot.stage == QuotePreparationStage.failed
                            ? 'We could not complete quote extraction. Your source input has not been turned into a quote.'
                            : completed
                                ? 'AI extracted ${_snapshot.items.length} work items. Confirm the details and enter missing prices in Review Quote.'
                                : 'Our AI is analysing your input and extracting the key details. This only takes a few seconds',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
                      fontWeight: FontWeight.w500, height: 1.35,
                      color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: 25),
                  if (showProgress) ...[
                    if (progress != null)
                      Sign2DigitalJobProgressIndicator(
                        key: const Key('quote-processing-progress'),
                        percentage: progress,
                        barHeight: 6,
                        labelGap: 16,
                      )
                    else
                      Semantics(
                        label: 'Preparing quote, progress is not measurable',
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          color: AppColors.primary,
                          backgroundColor: Color(0xFFE9EDF0),
                        ),
                      ),
                    const SizedBox(height: 25),
                  ],
                  if (_showingDemo)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _StatusMessage(
                        key: const Key('quote-demo-label'),
                        text: 'UI DEMO — These are example values, not AI-extracted results. 60% is a sample progress value.',
                      ),
                    ),
                  if (!_showingDemo &&
                      (_snapshot.stage == QuotePreparationStage.unavailable ||
                       _snapshot.stage == QuotePreparationStage.failed)) ...[
                    _StatusMessage(
                      key: const Key('quote-service-status'),
                      text: _snapshot.message ?? 'AI quote generation is unavailable.',
                    ),
                    const SizedBox(height: 16),
                    if (widget.service != null && widget.input != null)
                      OutlinedButton.icon(
                        key: const Key('quote-processing-retry'),
                        onPressed: _runService,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      )
                    else
                      OutlinedButton(
                        key: const Key('quote-preview-example'),
                        onPressed: _previewExample,
                        child: const Text('Preview Figma example'),
                      ),
                    const SizedBox(height: 25),
                  ],
                  if (completed) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: Row(children: [
                        Icon(Icons.check_circle_outline, size: 20,
                          color: AppColors.primary),
                        SizedBox(width: 8),
                        Expanded(child: Text(
                          'Extraction complete · AI suggestions need review',
                          key: Key('quote-processing-complete-label'),
                          style: TextStyle(fontFamily: 'Inter', fontSize: 13,
                            fontWeight: FontWeight.w500, color: AppColors.dark),
                        )),
                      ]),
                    ),
                  ],
                  if (_showingDemo ||
                      _snapshot.fields.isNotEmpty ||
                      completed ||
                      _snapshot.stage == QuotePreparationStage.partial)
                    Sign2DigitalExtractedInformationCard(
                      fields: _snapshot.fields,
                    ),
                  if (canReview) ...[
                    const SizedBox(height: 25),
                    FilledButton(
                      key: const Key('quote-processing-review'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _openReview,
                      child: const Text('Review Quote Draft'),
                    ),
                  ],
                  if (_showingDemo) ...[
                    const SizedBox(height: 25),
                    FilledButton(
                      key: const Key('quote-demo-review'),
                      onPressed: _openReview,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Preview Review Quote (demo)'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showingDemo = false;
                          _snapshot = QuotePreparationSnapshot.unavailable;
                        });
                      },
                      child: const Text('Return to service status'),
                    ),
                  ],
                ],
              ),
            ));
          }),
        )),
      ])),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.placeholder.withAlpha(26),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(
        fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500,
        height: 1.3, color: AppColors.dark,
      )),
    );
  }
}
