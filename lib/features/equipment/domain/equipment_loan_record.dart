enum EquipmentLoanStatus {
  active('Active'),returned('Returned'),overdue('Overdue');
  const EquipmentLoanStatus(this.label);
  final String label;
}

class EquipmentLoanEvent {
  const EquipmentLoanEvent({
    required this.id,required this.type,required this.date,
    this.actorId,this.oldDate,this.newDate,
  });
  final int id;
  final String type;
  final DateTime date;
  final int? actorId;
  final String? oldDate,newDate;
}

class EquipmentLoanRecord {
  const EquipmentLoanRecord({
    this.id,
    required this.assetId,required this.equipmentCode,
    required this.equipmentName,required this.borrowerName,
    required this.loanDate,required this.expectedReturnDate,
    this.borrowerType='external',this.borrowerEmail='',
    this.clientId,this.jobId,this.actualReturnDate,
    this.notes='',this.status=EquipmentLoanStatus.active,
    this.lockVersion=1,this.events=const [],
    this.companyId,this.requestKey='',
  });
  final int? id,clientId,jobId,companyId;
  final int assetId,lockVersion;
  final String equipmentCode,equipmentName,borrowerName,borrowerEmail,
      borrowerType,notes,requestKey;
  final DateTime loanDate,expectedReturnDate;
  final DateTime? actualReturnDate;
  final EquipmentLoanStatus status;
  final List<EquipmentLoanEvent> events;

  bool matches(String text){
    final q=text.trim().toLowerCase();
    return q.isEmpty||[
      equipmentCode,equipmentName,borrowerName,borrowerEmail,notes
    ].any((v)=>v.toLowerCase().contains(q));
  }

  EquipmentLoanRecord copyWith({
    DateTime? expectedReturnDate,DateTime? actualReturnDate,
    EquipmentLoanStatus? status,int? lockVersion,
    String? notes,List<EquipmentLoanEvent>? events,
  })=>EquipmentLoanRecord(
    id:id,assetId:assetId,equipmentCode:equipmentCode,
    equipmentName:equipmentName,borrowerName:borrowerName,
    borrowerEmail:borrowerEmail,borrowerType:borrowerType,
    clientId:clientId,jobId:jobId,loanDate:loanDate,
    expectedReturnDate:expectedReturnDate??this.expectedReturnDate,
    actualReturnDate:actualReturnDate??this.actualReturnDate,
    notes:notes??this.notes,status:status??this.status,
    lockVersion:lockVersion??this.lockVersion,
    events:events??this.events,companyId:companyId,requestKey:requestKey,
  );
}

abstract class EquipmentLoanRepository {
  const EquipmentLoanRepository();
  Future<List<EquipmentLoanRecord>> listLoans();
  Future<EquipmentLoanRecord> createLoan(EquipmentLoanRecord loan);
  Future<EquipmentLoanRecord> detail(int loanId);
  Future<EquipmentLoanRecord> extend(int loanId,int lockVersion,DateTime date);
  Future<EquipmentLoanRecord> markReturned(
    int loanId,int lockVersion,DateTime date);
}
