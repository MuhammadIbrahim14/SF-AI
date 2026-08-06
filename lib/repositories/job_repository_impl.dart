import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/app_exceptions.dart';
import '../models/job_model.dart';
import 'job_repository.dart';

class JobRepositoryImpl implements JobRepository {
  const JobRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _jobsRef =>
      _firestore.collection('jobs');

  @override
  Future<void> createJob(JobModel job) async {
    try {
      if (job.id.isEmpty) {
        final docRef = _jobsRef.doc();
        await docRef.set(job.copyWith(id: docRef.id).toJson());
      } else {
        await _jobsRef.doc(job.id).set(job.toJson());
      }
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to create job: ${e.toString()}');
    }
  }

  @override
  Future<void> updateJob(JobModel job) async {
    try {
      if (job.id.trim().isEmpty) {
        throw const FirestoreException('Cannot update a job without an ID.');
      }
      await _jobsRef.doc(job.id).set(job.toJson(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to update job: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteJob(String jobId) async {
    try {
      await _jobsRef.doc(jobId).delete();
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to delete job: ${e.toString()}');
    }
  }

  @override
  Future<JobModel?> getJob(String jobId) async {
    try {
      final doc = await _jobsRef.doc(jobId).get();
      if (!doc.exists || doc.data() == null) return null;
      return JobModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to fetch job: ${e.toString()}');
    }
  }

  @override
  Stream<List<JobModel>> streamAllJobs() {
    return _jobsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => JobModel.fromFirestore(doc)).toList(),
        );
  }

  @override
  Stream<List<JobModel>> streamJobsByCompany(String companyId) {
    return _jobsRef.where('companyId', isEqualTo: companyId).snapshots().map((
      snapshot,
    ) {
      final jobs = snapshot.docs
          .map((doc) => JobModel.fromFirestore(doc))
          .toList();
      jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return jobs;
    });
  }
}
