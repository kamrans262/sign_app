/// Borrower follow-up data from the M19 Laravel outbox. These are never
/// proof of inbox receipt; submitted means only transport acceptance.
class EquipmentReminderDelivery {
  const EquipmentReminderDelivery({
    required this.id,required this.kind,required this.dueDate,
    required this.status,required this.attemptCount,
    required this.deliveryNote,required this.createdAt,
  });
  final int id,attemptCount;
  final String kind,dueDate,status,deliveryNote,createdAt;

  factory EquipmentReminderDelivery.fromJson(Map<String,dynamic> data){
    final id=(data['id'] as num?)?.toInt()??0;
    final attempts=(data['attempt_count'] as num?)?.toInt()??0;
    final status=(data['status']??'').toString();
    if(id<1||attempts<0||!const [
      'pending','submitting','submitted','failed','unknown','cancelled'
    ].contains(status)){
      throw const FormatException('Invalid reminder delivery record.');
    }
    return EquipmentReminderDelivery(
      id:id,kind:(data['kind']??'').toString(),status:status,
      attemptCount:attempts,
      dueDate:(data['due_date']??'').toString(),
      createdAt:(data['created_at']??'').toString(),
      deliveryNote:(data['delivery_note']??'').toString(),
    );
  }
}

class EquipmentReminderPreview {
  const EquipmentReminderPreview({
    required this.loanId,required this.loanVersion,
    required this.borrowerName,required this.borrowerEmail,
    required this.equipmentName,required this.expectedReturnDate,
    required this.transportReady,required this.sendAvailable,
    required this.automaticEnabled,required this.recipientConfirmed,
    required this.frequencyDays,required this.automaticGlobalEnabled,
    required this.deliveryHistory,this.notAvailableReason,
  });
  final int loanId,loanVersion,frequencyDays;
  final String borrowerName,borrowerEmail,equipmentName,expectedReturnDate;
  final bool transportReady,sendAvailable,automaticEnabled,
      recipientConfirmed,automaticGlobalEnabled;
  final String? notAvailableReason;
  final List<EquipmentReminderDelivery> deliveryHistory;

  factory EquipmentReminderPreview.fromJson(Map<String,dynamic> data){
    final loanId=(data['loan_id'] as num?)?.toInt()??0;
    final version=(data['loan_version'] as num?)?.toInt()??0;
    final freq=(data['frequency_days'] as num?)?.toInt()??0;
    if(loanId<1||version<1||freq<1||freq>30||
        data['delivery_history'] is! List){
      throw const FormatException('Invalid equipment reminder preview.');
    }
    final history=<EquipmentReminderDelivery>[];
    for(final raw in data['delivery_history'] as List){
      if(raw is! Map)throw const FormatException('Invalid delivery history.');
      history.add(EquipmentReminderDelivery.fromJson(
        Map<String,dynamic>.from(raw)));
    }
    return EquipmentReminderPreview(
      loanId:loanId,loanVersion:version,frequencyDays:freq,
      borrowerName:(data['borrower_name']??'').toString(),
      borrowerEmail:(data['borrower_email']??'').toString(),
      equipmentName:(data['equipment_name']??'').toString(),
      expectedReturnDate:(data['expected_return_date']??'').toString(),
      transportReady:data['transport_ready']==true,
      sendAvailable:data['send_available']==true,
      automaticEnabled:data['automatic_enabled']==true,
      recipientConfirmed:data['recipient_confirmed']==true,
      automaticGlobalEnabled:data['automatic_global_enabled']==true,
      notAvailableReason:data['not_available_reason']?.toString(),
      deliveryHistory:List.unmodifiable(history),
    );
  }
}

class EquipmentReminderReceipt {
  const EquipmentReminderReceipt({
    required this.id,required this.status,required this.attemptCount,
    required this.deliveryNote,
  });
  final int id,attemptCount;
  final String status,deliveryNote;

  factory EquipmentReminderReceipt.fromJson(Map<String,dynamic> data){
    final id=(data['id'] as num?)?.toInt()??0;
    final attempts=(data['attempt_count'] as num?)?.toInt()??-1;
    final status=(data['status']??'').toString();
    if(id<1||attempts<0||!const [
      'submitted','unknown','failed','cancelled','pending'
    ].contains(status)){
      throw const FormatException('Invalid reminder dispatch response.');
    }
    return EquipmentReminderReceipt(
      id:id,status:status,attemptCount:attempts,
      deliveryNote:(data['delivery_note']??'').toString(),
    );
  }
}
