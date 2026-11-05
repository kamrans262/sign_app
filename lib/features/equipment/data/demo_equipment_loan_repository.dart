import '../domain/equipment_loan_record.dart';

/// Signed-out UI preview only: never merged into authenticated company records.
class DemoEquipmentLoanRepository extends EquipmentLoanRepository {
  const DemoEquipmentLoanRepository();
  static final Map<int,EquipmentLoanRecord> _records={};
  static int _next=1;
  static void resetForTests(){_records.clear();_next=1;}

  @override
  Future<List<EquipmentLoanRecord>> listLoans() async=>
    List.unmodifiable(_records.values);

  @override
  Future<EquipmentLoanRecord> createLoan(EquipmentLoanRecord item) async {
    if(_records.values.any((r)=>r.assetId==item.assetId&&
        r.status!=EquipmentLoanStatus.returned)){
      throw StateError('Equipment already lent.');
    }
    if(item.borrowerName.trim().isEmpty||
        item.expectedReturnDate.isBefore(item.loanDate)){
      throw ArgumentError('Invalid loan details.');
    }
    final id=_next++;
    final saved=EquipmentLoanRecord(
      id:id,assetId:item.assetId,equipmentCode:item.equipmentCode,
      equipmentName:item.equipmentName,borrowerName:item.borrowerName,
      borrowerEmail:item.borrowerEmail,borrowerType:item.borrowerType,
      clientId:item.clientId,jobId:item.jobId,loanDate:item.loanDate,
      expectedReturnDate:item.expectedReturnDate,notes:item.notes,
      requestKey:item.requestKey,
      events:[EquipmentLoanEvent(id:1,type:'created',date:DateTime.now())]);
    _records[id]=saved;
    return saved;
  }

  @override
  Future<EquipmentLoanRecord> detail(int id) async {
    final r=_records[id];
    if(r==null)throw StateError('Equipment loan not found.');
    return r;
  }

  @override
  Future<EquipmentLoanRecord> extend(int id,int version,DateTime date) async {
    final r=await detail(id);
    if(r.lockVersion!=version||r.status==EquipmentLoanStatus.returned
        ||!date.isAfter(r.expectedReturnDate)){
      throw StateError('Loan cannot be extended.');
    }
    final next=r.copyWith(expectedReturnDate:date,lockVersion:version+1,
      events:[...r.events,EquipmentLoanEvent(
        id:r.events.length+1,type:'return_date_extended',date:DateTime.now(),
        oldDate:r.expectedReturnDate.toIso8601String().substring(0,10),
        newDate:date.toIso8601String().substring(0,10))]);
    _records[id]=next;
    return next;
  }

  @override
  Future<EquipmentLoanRecord> markReturned(int id,int version,DateTime date) async{
    final r=await detail(id);
    if(r.lockVersion!=version||r.status==EquipmentLoanStatus.returned
        ||date.isBefore(r.loanDate)||date.isAfter(DateTime.now())){
      throw StateError('Loan cannot be returned.');
    }
    final next=r.copyWith(actualReturnDate:date,status:EquipmentLoanStatus.returned,
      lockVersion:version+1,events:[...r.events,EquipmentLoanEvent(
        id:r.events.length+1,type:'returned',date:DateTime.now())]);
    _records[id]=next;
    return next;
  }
}
