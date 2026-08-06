import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/app_exceptions.dart';
import '../models/interview_model.dart';
import 'interview_repository.dart';

class InterviewRepositoryImpl implements InterviewRepository {
  const InterviewRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _interviewsRef =>
      _firestore.collection('interviews');

  CollectionReference<Map<String, dynamic>> get _applicationsRef =>
      _firestore.collection('applications');

  CollectionReference<Map<String, dynamic>> _timelineRef(String applicationId) =>
      _applicationsRef.doc(applicationId).collection('timeline');

  @override
  Future<String> scheduleInterview(InterviewModel interview) async {
    try {
      final docRef = interview.interviewId.isEmpty
          ? _interviewsRef.doc()
          : _interviewsRef.doc(interview.interviewId);
      final isReschedule = interview.status == 'rescheduled' ||
          interview.interviewId.isNotEmpty;
      final scheduled = interview.copyWith(
        interviewId: docRef.id,
        status: isReschedule ? 'rescheduled' : 'scheduled',
        result: 'pending',
        updatedAt: DateTime.now(),
      );

      final batch = _firestore.batch();
      batch.set(docRef, scheduled.toJson(), SetOptions(merge: true));
      batch.update(_applicationsRef.doc(interview.applicationId), {
        'status': 'interview_scheduled',
        'pipelineStage': 'interview',
        'lifecycleStage': 'interview_scheduled',
        'interviewId': docRef.id,
        'candidateVisibleStatus': 'interview_scheduled',
        'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
      });
      final timelineRef = _timelineRef(interview.applicationId).doc();
      batch.set(timelineRef, {
        'applicationId': interview.applicationId,
        'companyId': interview.companyId,
        'candidateId': interview.candidateId,
        'stage': 'interview_scheduled',
        'title': isReschedule ? 'Interview Updated' : 'Interview Scheduled',
        'description': isReschedule
            ? 'Interview was rescheduled.'
            : 'Company scheduled an interview.',
        'actorId': interview.companyId,
        'actorRole': 'company',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'visibleToCandidate': true,
      });
      await batch.commit();

      return docRef.id;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to schedule interview: ${e.toString()}');
    }
  }

  @override
  Future<void> updateInterview(
    InterviewModel interview, {
    String? applicationStatus,
  }) async {
    try {
      if (interview.interviewId.trim().isEmpty) {
        throw const FirestoreException(
          'Cannot update an interview without an ID.',
        );
      }
      final batch = _firestore.batch();
      batch.set(
        _interviewsRef.doc(interview.interviewId),
        interview.copyWith(updatedAt: DateTime.now()).toJson(),
        SetOptions(merge: true),
      );

      final appUpdate = <String, dynamic>{
        'interviewId': interview.interviewId,
        'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
      };
      if (applicationStatus != null && applicationStatus.trim().isNotEmpty) {
        appUpdate['status'] = applicationStatus;
      }
      if (interview.isCancelled) {
        appUpdate['lifecycleStage'] = 'shortlisted';
        appUpdate['candidateVisibleStatus'] = 'interview_cancelled';
        appUpdate['status'] = applicationStatus ?? 'shortlisted';
        appUpdate['pipelineStage'] = 'shortlisted';
      } else if (interview.isCompleted) {
        appUpdate['lifecycleStage'] = 'interview_completed';
        appUpdate['status'] = applicationStatus ?? 'interview_completed';
        appUpdate['pipelineStage'] = 'interview';
        appUpdate['candidateVisibleStatus'] = 'interview_completed';
      } else if (interview.isScheduled) {
        appUpdate['lifecycleStage'] = 'interview_scheduled';
        appUpdate['status'] = applicationStatus ?? 'interview_scheduled';
        appUpdate['pipelineStage'] = 'interview';
        appUpdate['candidateVisibleStatus'] = 'interview_scheduled';
      }
      batch.update(_applicationsRef.doc(interview.applicationId), appUpdate);

      final stage = interview.isCancelled
          ? 'shortlisted'
          : interview.isCompleted
              ? 'interview_completed'
              : 'interview_scheduled';
      batch.set(_timelineRef(interview.applicationId).doc(), {
        'applicationId': interview.applicationId,
        'companyId': interview.companyId,
        'candidateId': interview.candidateId,
        'stage': stage,
        'title': interview.isCancelled
            ? 'Interview Cancelled'
            : interview.isCompleted
                ? 'Interview Completed'
                : 'Interview Updated',
        'description': interview.isCancelled
            ? 'Interview was cancelled by the company.'
            : interview.isCompleted
                ? 'Interview marked completed.'
                : 'Interview details were updated.',
        'actorId': interview.companyId,
        'actorRole': 'company',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'visibleToCandidate': true,
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to update interview: ${e.toString()}');
    }
  }

  @override
  Future<void> updateInterviewStatus({
    required String interviewId,
    required String status,
    String? result,
    String? applicationStatus,
  }) async {
    try {
      final interview = await getInterview(interviewId);
      if (interview == null) {
        throw const FirestoreException('Interview not found.');
      }
      await updateInterview(
        interview.copyWith(
          status: status,
          result: result ?? interview.result,
          updatedAt: DateTime.now(),
        ),
        applicationStatus: applicationStatus,
      );
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to update interview status: ${e.toString()}',
      );
    }
  }

  @override
  Future<InterviewModel?> getInterview(String interviewId) async {
    try {
      final doc = await _interviewsRef.doc(interviewId).get();
      if (!doc.exists || doc.data() == null) return null;
      return InterviewModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to load interview: ${e.toString()}');
    }
  }

  @override
  Future<InterviewModel?> getInterviewForApplication(
    String applicationId,
  ) async {
    try {
      final snapshot = await _interviewsRef
          .where('applicationId', isEqualTo: applicationId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return InterviewModel.fromFirestore(snapshot.docs.first);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to load interview: ${e.toString()}');
    }
  }

  @override
  Stream<InterviewModel?> streamInterview(String interviewId) {
    return _interviewsRef.doc(interviewId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return InterviewModel.fromFirestore(doc);
    });
  }

  @override
  Stream<List<InterviewModel>> streamInterviewsForCandidate(
    String candidateId,
  ) {
    return _interviewsRef
        .where('candidateId', isEqualTo: candidateId)
        .snapshots()
        .map(_sortInterviews);
  }

  @override
  Stream<List<InterviewModel>> streamInterviewsForCompany(String companyId) {
    return _interviewsRef
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map(_sortInterviews);
  }

  List<InterviewModel> _sortInterviews(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final interviews = snapshot.docs
        .map((doc) => InterviewModel.fromFirestore(doc))
        .toList();
    interviews.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    return interviews;
  }
}
