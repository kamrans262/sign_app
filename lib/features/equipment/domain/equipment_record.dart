import '../../jobs/data/local_job_photo_source.dart';

enum EquipmentStatus {
  inUse('In Use'), available('Available'), maintenance('Maintenance');
  const EquipmentStatus(this.label);
  final String label;
}

class EquipmentUsage {
  const EquipmentUsage({
    required this.id, required this.date, required this.hours,
    this.job = '', this.notes = '',
  });
  final String id, job, notes;
  final DateTime date;
  final double hours;
}

class EquipmentMaintenance {
  const EquipmentMaintenance({
    required this.id, required this.date, required this.description,
    this.completed = false,
  });
  final String id, description;
  final DateTime date;
  final bool completed;
}

class EquipmentEvent {
  const EquipmentEvent({
    required this.id, required this.title, required this.date,
    this.description = '',
  });
  final String id, title, description;
  final DateTime date;
}

/// One record owns its listing, details, photos, usage and maintenance state.
class EquipmentRecord {
  const EquipmentRecord({
    required this.id, required this.name, required this.category,
    required this.brand, required this.model,
    required this.purchaseDate, required this.status,
    this.location = '', this.notes = '', this.photos = const [],
    this.initialHours = 0, this.usage = const [],
    this.maintenance = const [], this.history = const [],
    this.createdAt, this.demoOnly = true,
  });
  final String id, name, category, brand, model, location, notes;
  final DateTime purchaseDate;
  final EquipmentStatus status;
  final List<LocalJobPhotoSelection> photos;
  final double initialHours;
  final List<EquipmentUsage> usage;
  final List<EquipmentMaintenance> maintenance;
  final List<EquipmentEvent> history;
  final DateTime? createdAt;
  final bool demoOnly;

  double get hours => initialHours +
      usage.fold<double>(0, (sum, item) => sum + item.hours);

  bool matches(String text) {
    final q = text.trim().toLowerCase();
    return q.isEmpty || [
      name, id, category, brand, model, status.label,
    ].any((item) => item.toLowerCase().contains(q));
  }

  EquipmentRecord copyWith({
    String? name, String? category, String? brand, String? model,
    String? location, String? notes, DateTime? purchaseDate,
    EquipmentStatus? status, List<LocalJobPhotoSelection>? photos,
    List<EquipmentUsage>? usage, List<EquipmentMaintenance>? maintenance,
    List<EquipmentEvent>? history,
  }) => EquipmentRecord(
    id: id, name: name ?? this.name,
    category: category ?? this.category,
    brand: brand ?? this.brand,
    model: model ?? this.model,
    location: location ?? this.location,
    notes: notes ?? this.notes,
    purchaseDate: purchaseDate ?? this.purchaseDate,
    status: status ?? this.status,
    photos: photos ?? this.photos,
    usage: usage ?? this.usage,
    maintenance: maintenance ?? this.maintenance,
    history: history ?? this.history,
    initialHours: initialHours, createdAt: createdAt,
    demoOnly: demoOnly,
  );
}

abstract class EquipmentRepository {
  const EquipmentRepository();
  Future<List<EquipmentRecord>> listEquipment();
  Future<EquipmentRecord> saveEquipment(EquipmentRecord record);
  Future<EquipmentRecord> updateEquipment(EquipmentRecord record);
  Future<EquipmentRecord> logUsage(String id, EquipmentUsage usage);
  Future<EquipmentRecord> scheduleMaintenance(
      String id, EquipmentMaintenance maintenance);
}
