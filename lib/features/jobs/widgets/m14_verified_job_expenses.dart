import 'package:flutter/material.dart';

import '../../../core/services/active_company_session.dart';
import '../../expenses/data/remote_expense_repository.dart';
import '../presentation/widgets/sign2digital_job_financial_card.dart';

/// Reuses the existing M5 financial card style without fictitious amounts.
class M14VerifiedJobExpensesCard extends StatefulWidget {
  const M14VerifiedJobExpensesCard({
    super.key,required this.jobId,this.budgetRemaining=false,
  });
  final int jobId;
  final bool budgetRemaining;

  @override
  State<M14VerifiedJobExpensesCard> createState() =>
      _M14VerifiedJobExpensesCardState();
}

class _M14VerifiedJobExpensesCardState extends State<M14VerifiedJobExpensesCard> {
  Future<Map<String,dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant M14VerifiedJobExpensesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jobId != widget.jobId) _load();
  }

  void _load() {
    if (ActiveCompanySession.companyId == null) {
      _future = null;
      return;
    }
    _future = RemoteExpenseRepository.shared.jobTotals(widget.jobId);
  }

  static int? _amount(Object? value) {
    if (value is int) return value;
    return int.tryParse('$value');
  }

  static String _chf(int cents) {
    final negative=cents<0?'-':'';
    final abs=cents.abs();
    return '${negative}CHF ${abs ~/ 100}.${(abs % 100).toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final future=_future;
    if (future == null) {
      return widget.budgetRemaining ? const SizedBox.shrink()
          : const Sign2DigitalJobFinancialCard(
              label:'Expenses',amountChf:0,showAmount:false,
              icon:Icons.shopping_cart_outlined);
    }
    return FutureBuilder<Map<String,dynamic>>(
      future:future,builder:(context,snapshot) {
        final data=snapshot.data;
        final key=widget.budgetRemaining
            ?'remaining_budget_minor':'total_expenses_minor';
        final cents=_amount(data?[key]);
        if (widget.budgetRemaining && cents == null) {
          return const SizedBox.shrink();
        }
        return Sign2DigitalJobFinancialCard(
          label:widget.budgetRemaining?'Remaining expense budget':'Expenses',
          amountChf:0,
          amountLabel:cents==null?null:_chf(cents),
          showAmount:snapshot.hasData && cents!=null && !snapshot.hasError,
          icon:widget.budgetRemaining
              ?Icons.account_balance_wallet_outlined
              :Icons.shopping_cart_outlined,
        );
      },
    );
  }
}
