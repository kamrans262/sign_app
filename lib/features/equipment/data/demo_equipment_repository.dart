import '../domain/equipment_record.dart';

/// In-memory UI demo storage, not a synchronized Laravel backend.
/// Static state retains saved records while navigating between screens.
class DemoEquipmentRepository extends EquipmentRepository {
  const DemoEquipmentRepository();

  static final Map<String, EquipmentRecord> _changes = {};

  static void resetForTests() => _changes.clear();

  static EquipmentRecord get _sample => EquipmentRecord(
    id: 'EQP-0001',
    name: 'Mini Excavator',
    category: 'Excavation',
    brand: 'Kubota',
    model: 'U-27-4',
    purchaseDate: DateTime(2026, 8, 28),
    status: EquipmentStatus.inUse,
    location: 'London',
    initialHours: 245,
    createdAt: DateTime(2026, 8, 28),
  );

  @override
  Future<List<EquipmentRecord>> listEquipment() async =>
      List<EquipmentRecord>.unmodifiable([
        _changes['EQP-0001'] ?? _sample,
        for (final record in _changes.values)
          if (record.id != 'EQP-0001') record,
      ]);

  static void _validate(EquipmentRecord item) {
    if (item.id.trim().isEmpty || item.name.trim().isEmpty ||
        item.category.trim().isEmpty || item.brand.trim().isEmpty ||
        item.model.trim().isEmpty ||
        item.purchaseDate.year < 2000 || item.purchaseDate.year > 2100 ||
        !item.hours.isFinite || item.hours < 0) {
      throw ArgumentError('Equipment is missing required fields.');
    }
  }

  Future<EquipmentRecord> _find(String id) async {
    for (final record in await listEquipment()) {
      if (record.id == id) return record;
    }
    throw StateError('Equipment not found.');
  }

  EquipmentEvent _event(String title, {String description = ''}) {
    final now = DateTime.now();
    return EquipmentEvent(
      id: '$title-${now.microsecondsSinceEpoch}',
      title: title, date: now, description: description);
  }

  @override
  Future<EquipmentRecord> saveEquipment(EquipmentRecord record) async {
    _validate(record);
    if ((await listEquipment()).any((e) => e.id == record.id)) {
      throw StateError('Equipment ID already exists.');
    }
    final saved = record.copyWith(history: [
      ...record.history,
      _event('Equipment created'),
    ]);
    _changes[saved.id] = saved;
    return saved;
  }

  @override
  Future<EquipmentRecord> updateEquipment(EquipmentRecord record) async {
    _validate(record);
    final original = await _find(record.id);
    final saved = record.copyWith(history: [
      ...original.history,
      _event('Equipment updated',
        description: record.status == original.status
            ? '' : 'Status: ${original.status.label} → ${record.status.label}'),
    ]);
    _changes[saved.id] = saved;
    return saved;
  }

  @override
  Future<EquipmentRecord> logUsage(String id, EquipmentUsage usage) async {
    if (!usage.hours.isFinite || usage.hours <= 0 || usage.hours > 100000 ||
        usage.date.year < 2000 || usage.date.year > 2100) {
      throw ArgumentError('Enter positive hours and a valid date.');
    }
    final original = await _find(id);
    final saved = original.copyWith(
      usage: [...original.usage, usage],
      history: [...original.history,
        _event('Usage recorded',
          description: '${usage.hours.toStringAsFixed(1)} hours')],
    );
    _changes[id] = saved;
    return saved;
  }

  @override
  Future<EquipmentRecord> scheduleMaintenance(
      String id, EquipmentMaintenance maintenance) async {
    if (maintenance.description.trim().isEmpty ||
        maintenance.date.year < 2000 || maintenance.date.year > 2100) {
      throw ArgumentError('Maintenance needs a date and description.');
    }
    final original = await _find(id);
    final saved = original.copyWith(
      maintenance: [...original.maintenance, maintenance],
      history: [...original.history,
        _event('Maintenance scheduled',
          description: maintenance.description)],
    );
    _changes[id] = saved;
    return saved;
  }
}
