import '../domain/job_photo_model.dart';

/// In-memory frontend store. Photos survive switching routes during this app
/// session; they are not uploaded or persisted across app restarts.
class JobPhotoLocalStore {
  JobPhotoLocalStore();

  static final JobPhotoLocalStore shared = JobPhotoLocalStore();
  final Map<String, List<JobPhotoModel>> _photos = {};

  List<JobPhotoModel> photosFor(String jobId) => List.unmodifiable(
    _photos.putIfAbsent(jobId, () => JobPhotoModel.demoFor(jobId)),
  );

  void addAll(String jobId, Iterable<JobPhotoModel> photos) {
    final list = _photos.putIfAbsent(jobId, () => JobPhotoModel.demoFor(jobId));
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
