import '../../../core/services/active_company_session.dart';
import '../domain/job_photo_model.dart';

/// In-memory frontend store. Photos survive switching routes during this app
/// session; they are not uploaded or persisted across app restarts.
class JobPhotoLocalStore {
  JobPhotoLocalStore();

  static final JobPhotoLocalStore shared = JobPhotoLocalStore();
  final Map<String, List<JobPhotoModel>> _photos = {};

  String _key(String jobId) {
    final company = ActiveCompanySession.companyId;
    return company != null && int.tryParse(jobId) != null
        ? 'company:$company/job:$jobId' : jobId;
  }

  List<JobPhotoModel> _seed(String jobId) => int.tryParse(jobId) == null
      ? JobPhotoModel.demoFor(jobId) : <JobPhotoModel>[];

  List<JobPhotoModel> photosFor(String jobId) => List.unmodifiable(
    _photos.putIfAbsent(_key(jobId), () => _seed(jobId)),
  );

  void remove(String jobId, String photoId) {
    _photos[_key(jobId)]?.removeWhere((photo) => photo.id == photoId);
  }

  void addAll(String jobId, Iterable<JobPhotoModel> photos) {
    final list = _photos.putIfAbsent(_key(jobId), () => _seed(jobId));
    for (final photo in photos) {
      if (photo.jobId != jobId) continue;
      if (list.any(
        (existing) =>
            existing.id == photo.id ||
            (photo.sourceKey != null && existing.sourceKey == photo.sourceKey),
      )) {
        continue;
      }
      list.add(photo);
    }
  }
}
