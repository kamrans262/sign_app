import 'document_record.dart';

class GeneralTextBlock {
  const GeneralTextBlock({required this.type,required this.text,
    this.bold=false,this.italic=false});
  final String type,text;
  final bool bold,italic;
  static const kinds=['paragraph','heading','bullet','numbered'];

  Map<String,dynamic> toJson()=>{'type':type,'text':text,
    'bold':bold,'italic':italic};

  factory GeneralTextBlock.fromJson(Map<String,dynamic> map) {
    final type=(map['type']??'').toString();
    final text=map['text'];
    if(!kinds.contains(type)||text is! String||text.length>4000||
      map['bold'] is! bool||map['italic'] is! bool) {
      throw const FormatException('Invalid document paragraph.');
    }
    return GeneralTextBlock(type:type,text:text,
      bold:map['bold'] as bool,italic:map['italic'] as bool);
  }
}

class GeneralDocumentDraft {
  const GeneralDocumentDraft({
    this.id,this.companyId,this.number='',this.type='letter',
    this.title='',this.locale='en',this.clientId,this.jobId,
    this.status='draft',this.revision=0,this.lockVersion=0,
    this.blocks=const [],this.source='manual',
    this.clientName='',this.jobTitle='',this.createdAt,
  });

  final int? id,companyId,clientId,jobId;
  final String number,type,title,locale,status,source;
  final String clientName,jobTitle;
  final int revision,lockVersion;
  final List<GeneralTextBlock> blocks;
  final DateTime? createdAt;

  bool get editable=>status=='draft'||status=='reviewed';

  DocumentRecord toDocumentRecord()=>DocumentRecord(
    id:'general-$id',category:DocumentCategory.other,
    number:number,title:title,
    project:jobTitle.trim().isEmpty?'Not linked to a job':jobTitle,
    customer:clientName,timestamp:createdAt??DateTime.now(),
    status:status,version:revision,jobId:jobId?.toString(),demoOnly:false);
}
