import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/app_exceptions.dart';
import '../models/application_model.dart';
import '../models/hiring_lifecycle_models.dart';
import 'application_repository.dart';
import 'notification_repository.dart';
import 'notification_repository_impl.dart';

class ApplicationRepositoryImpl implements ApplicationRepository {
  const ApplicationRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _applicationsRef =>
      _firestore.collection('applications');

  CollectionReference<Map<String, dynamic>> get _employmentRef =>
      _firestore.collection('candidate_employment');

  NotificationRepository get _notifications =>
      NotificationRepositoryImpl(_firestore);

  CollectionReference<Map<String, dynamic>> _timelineRef(String applicationId) =>
      _applicationsRef.doc(applicationId).collection('timeline');

  static const _activeEmploymentError =
      'This candidate already has an active hire elsewhere. '
      'They can only hold one joining/active role at a time.';

  Future<Map<String, dynamic>?> _readEmploymentLock(String applicantId) async {
    final snap = await _employmentRef.doc(applicantId).get();
    if (!snap.exists || snap.data() == null) return null;
    return snap.data();
  }

  Future<void> _assertCanClaimEmployment({
    required String applicantId,
    required String applicationId,
  }) async {
    final lock = await _readEmploymentLock(applicantId);
    if (lock == null) return;
    final lockedAppId = (lock['applicationId'] ?? '').toString();
    final status = normalizeEmploymentStatus((lock['status'] ?? '').toString());
    if (lockedAppId.isEmpty) return;
    if (lockedAppId == applicationId) return;
    if (status == 'joining_soon' || status == 'active') {
      throw const FirestoreException(
        _activeEmploymentError,
        'active-employment',
      );
    }
  }

  Future<void> _setEmploymentLock({
    required String applicantId,
    required String applicationId,
    required String companyId,
    required String jobId,
    required String status,
  }) async {
    final normalized = normalizeEmploymentStatus(status);
    if (normalized != 'joining_soon' && normalized != 'active') return;
    await _employmentRef.doc(applicantId).set({
      'applicantId': applicantId,
      'applicationId': applicationId,
      'companyId': companyId,
      'jobId': jobId,
      'status': normalized,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> _clearEmploymentLockIfOwned({
    required String applicantId,
    required String applicationId,
  }) async {
    final lock = await _readEmploymentLock(applicantId);
    if (lock == null) return;
    final lockedAppId = (lock['applicationId'] ?? '').toString();
    if (lockedAppId != applicationId) return;
    await _employmentRef.doc(applicantId).delete();
  }

  /// Declines other pending offers for this applicant (best-effort).
  /// Candidate can update all of their apps; company can only update own apps.
  Future<void> _declineOtherPendingOffers({
    required String applicantId,
    required String acceptedApplicationId,
    String? companyIdOnly,
  }) async {
    Query<Map<String, dynamic>> query = _applicationsRef.where(
      'applicantId',
      isEqualTo: applicantId,
    );
    if (companyIdOnly != null && companyIdOnly.isNotEmpty) {
      query = query.where('companyId', isEqualTo: companyIdOnly);
    }
    final snapshot = await query.get();
    final batch = _firestore.batch();
    var writes = 0;
    for (final doc in snapshot.docs) {
      if (doc.id == acceptedApplicationId) continue;
      final data = doc.data();
      final offer = normalizeOfferStatus((data['offerStatus'] ?? '').toString());
      if (offer != 'sent' && offer != 'clarification') continue;
      final payload = <String, dynamic>{
        'offerStatus': 'declined',
        'candidateVisibleStatus': 'offerDeclined',
        'lifecycleStage': 'offer_declined',
        'employmentStatus': 'none',
        'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
      };
      // Candidate update rules allow these; company hiring update rules do not.
      if (companyIdOnly == null) {
        payload['candidateResponseMessage'] =
            'Auto-declined because another offer was accepted.';
        payload['offerRespondedAt'] = Timestamp.fromDate(DateTime.now());
      }
      batch.update(doc.reference, payload);
      writes++;
      if (writes >= 400) break;
    }
    if (writes > 0) {
      await batch.commit();
    }
  }

  @override
  Future<String> createApplication(ApplicationModel application) async {
    try {
      final existing = await findApplicationForJob(
        applicantId: application.applicantId,
        jobId: application.jobId,
      );
      if (existing != null) {
        throw const FirestoreException(
          'You have already applied to this job.',
          'already-applied',
        );
      }

      late final String applicationId;
      final withLifecycle = application.copyWith(
        lifecycleStage: 'applied',
        employmentStatus: 'none',
        lastUpdatedAt: DateTime.now(),
      );
      if (application.id.isEmpty) {
        final docRef = _applicationsRef.doc();
        applicationId = docRef.id;
        await docRef.set(withLifecycle.copyWith(id: applicationId).toJson());
      } else {
        applicationId = application.id;
        await _applicationsRef
            .doc(applicationId)
            .set(withLifecycle.copyWith(id: applicationId).toJson());
      }

      // Permission bridge so company can read Interview Lab evidence.
      final accessId = '${application.companyId}_${application.applicantId}';
      await _firestore.collection('hiring_candidate_access').doc(accessId).set({
        'accessId': accessId,
        'companyId': application.companyId,
        'candidateId': application.applicantId,
        'applicationId': applicationId,
        'jobId': application.jobId,
        'module': 'company_hiring',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await appendTimelineEvent(
        HiringTimelineEvent(
          id: '',
          applicationId: applicationId,
          companyId: application.companyId,
          candidateId: application.applicantId,
          stage: 'applied',
          title: 'Applied',
          description: 'Candidate submitted an application.',
          actorId: application.applicantId,
          actorRole: application.role,
          createdAt: DateTime.now(),
        ),
      );
      return applicationId;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      if (e is FirestoreException) rethrow;
      throw FirestoreException('Failed to submit application: ${e.toString()}');
    }
  }

  @override
  Future<ApplicationModel?> findApplicationForJob({
    required String applicantId,
    required String jobId,
  }) async {
    try {
      final snap = await _applicationsRef
          .where('applicantId', isEqualTo: applicantId)
          .limit(100)
          .get();
      for (final doc in snap.docs) {
        final app = ApplicationModel.fromFirestore(doc);
        if (app.jobId == jobId) return app;
      }
      return null;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to check existing application: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> updateApplicationStatus(
    String applicationId,
    String status,
  ) async {
    try {
      await updateApplicationPipeline(
        applicationId: applicationId,
        status: status,
      );
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to update status: ${e.toString()}');
    }
  }

  @override
  Future<void> updateApplicationPipeline({
    required String applicationId,
    required String status,
    String? interviewId,
  }) async {
    try {
      final existing = await getApplication(applicationId);
      final pipeline = normalizePipelineStage(status);
      final lifecycle = lifecycleStageFromHiringChange(
        pipelineStage: pipeline,
        offerStatus: existing?.normalizedOfferStatus ?? 'none',
        applicationStatus: status,
      );
      final data = <String, dynamic>{
        'status': status,
        'pipelineStage': pipeline,
        'lifecycleStage': lifecycle,
        'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
      };
      if (interviewId != null && interviewId.trim().isNotEmpty) {
        data['interviewId'] = interviewId;
      }
      await _applicationsRef.doc(applicationId).update(data);
      if (existing != null) {
        await appendTimelineEvent(
          HiringTimelineEvent(
            id: '',
            applicationId: applicationId,
            companyId: existing.companyId,
            candidateId: existing.applicantId,
            stage: lifecycle,
            title: lifecycleStageLabel(lifecycle),
            description: 'Hiring stage updated to ${lifecycleStageLabel(lifecycle)}.',
            actorId: existing.companyId,
            actorRole: 'company',
            createdAt: DateTime.now(),
          ),
        );
      }
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to update pipeline: ${e.toString()}');
    }
  }

  @override
  Future<void> updateApplicationHiringData({
    required String applicationId,
    String? pipelineStage,
    String? applicationStatus,
    double? evaluationScore,
    String? evaluationSummary,
    double? rankingScore,
    String? rankingReason,
    List<String>? matchedSkills,
    List<String>? missingSkills,
    String? recommendedNextStep,
    String? companyNotes,
    String? offerStatus,
    String? offerDetails,
    String? candidateVisibleStatus,
    String? evaluationRequestStatus,
    List<String>? evaluationQuestions,
    String? offerSalary,
    String? offerCurrency,
    String? offerJoiningDate,
    String? offerMessage,
    DateTime? offerSentAt,
    bool? talentPoolSaved,
    DateTime? evaluatedAt,
    String? lifecycleStage,
    String? employmentStatus,
    DateTime? joinedAt,
    String? offerRole,
    String? offerDepartment,
    String? offerEmploymentType,
    String? offerBenefits,
    String? offerContractDuration,
    String? offerWorkingHours,
    String? offerLocation,
    String? offerExpiresAt,
    String? hrInterviewFeedback,
    String? hrHiringComments,
    List<OnboardingChecklistItem>? onboardingChecklist,
    DateTime? offerDocumentGeneratedAt,
    WelcomePack? welcomePack,
    EmploymentProfile? employmentProfile,
    ProbationInfo? probation,
    OffboardingInfo? offboarding,
    List<EmploymentDocument>? documents,
    String? hrThreadId,
    DateTime? lastJoinReminderAt,
    DateTime? lastDocsReminderAt,
  }) async {
    try {
      final existing = await getApplication(applicationId);
      final data = <String, dynamic>{
        'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
      };
      String? resolvedPipeline;
      if (pipelineStage != null) {
        resolvedPipeline = normalizePipelineStage(pipelineStage);
        data['pipelineStage'] = resolvedPipeline;
      }
      // Keep application status independent of pipeline when provided
      // (e.g. pipeline=interview, status=interview_completed / evaluated).
      if (applicationStatus != null && applicationStatus.trim().isNotEmpty) {
        data['status'] = applicationStatus.trim();
      } else if (resolvedPipeline != null) {
        data['status'] = resolvedPipeline;
      }
      if (evaluationScore != null) {
        data['evaluationScore'] = evaluationScore.clamp(0, 100);
      }
      if (evaluationSummary != null) {
        data['evaluationSummary'] = evaluationSummary;
      }
      if (rankingScore != null) {
        data['rankingScore'] = rankingScore.clamp(0, 100);
      }
      if (rankingReason != null) data['rankingReason'] = rankingReason;
      if (matchedSkills != null) data['matchedSkills'] = matchedSkills;
      if (missingSkills != null) data['missingSkills'] = missingSkills;
      if (recommendedNextStep != null) {
        data['recommendedNextStep'] = recommendedNextStep;
      }
      if (companyNotes != null) data['companyNotes'] = companyNotes;
      String? resolvedOffer;
      if (offerStatus != null) {
        resolvedOffer = normalizeOfferStatus(offerStatus);
        data['offerStatus'] = resolvedOffer;
      }
      if (offerDetails != null) data['offerDetails'] = offerDetails;
      if (candidateVisibleStatus != null) {
        data['candidateVisibleStatus'] = candidateVisibleStatus;
      }
      if (evaluationRequestStatus != null) {
        data['evaluationRequestStatus'] = evaluationRequestStatus;
      }
      if (evaluationQuestions != null) {
        data['evaluationQuestions'] = evaluationQuestions;
      }
      if (offerSalary != null) data['offerSalary'] = offerSalary;
      if (offerCurrency != null) data['offerCurrency'] = offerCurrency;
      if (offerJoiningDate != null) data['offerJoiningDate'] = offerJoiningDate;
      if (offerMessage != null) data['offerMessage'] = offerMessage;
      if (offerSentAt != null) {
        data['offerSentAt'] = Timestamp.fromDate(offerSentAt);
      }
      if (talentPoolSaved != null) data['talentPoolSaved'] = talentPoolSaved;
      if (evaluatedAt != null) {
        data['evaluatedAt'] = Timestamp.fromDate(evaluatedAt);
      }
      if (offerRole != null) data['offerRole'] = offerRole;
      if (offerDepartment != null) data['offerDepartment'] = offerDepartment;
      if (offerEmploymentType != null) {
        data['offerEmploymentType'] = offerEmploymentType;
      }
      if (offerBenefits != null) data['offerBenefits'] = offerBenefits;
      if (offerContractDuration != null) {
        data['offerContractDuration'] = offerContractDuration;
      }
      if (offerWorkingHours != null) {
        data['offerWorkingHours'] = offerWorkingHours;
      }
      if (offerLocation != null) data['offerLocation'] = offerLocation;
      if (offerExpiresAt != null) data['offerExpiresAt'] = offerExpiresAt;
      if (hrInterviewFeedback != null) {
        data['hrInterviewFeedback'] = hrInterviewFeedback;
      }
      if (hrHiringComments != null) {
        data['hrHiringComments'] = hrHiringComments;
      }
      if (onboardingChecklist != null) {
        data['onboardingChecklist'] =
            onboardingChecklist.map((item) => item.toMap()).toList();
      }
      if (offerDocumentGeneratedAt != null) {
        data['offerDocumentGeneratedAt'] =
            Timestamp.fromDate(offerDocumentGeneratedAt);
      }
      if (welcomePack != null) data['welcomePack'] = welcomePack.toMap();
      if (employmentProfile != null) {
        data['employmentProfile'] = employmentProfile.toMap();
      }
      if (probation != null) data['probation'] = probation.toMap();
      if (offboarding != null) data['offboarding'] = offboarding.toMap();
      if (documents != null) {
        data['documents'] = documents.map((doc) => doc.toMap()).toList();
      }
      if (hrThreadId != null) data['hrThreadId'] = hrThreadId;
      if (lastJoinReminderAt != null) {
        data['lastJoinReminderAt'] = Timestamp.fromDate(lastJoinReminderAt);
      }
      if (lastDocsReminderAt != null) {
        data['lastDocsReminderAt'] = Timestamp.fromDate(lastDocsReminderAt);
      }
      if (employmentStatus != null) {
        data['employmentStatus'] = normalizeEmploymentStatus(employmentStatus);
      }
      if (joinedAt != null) {
        data['joinedAt'] = Timestamp.fromDate(joinedAt);
      }

      final touchLifecycle = lifecycleStage != null ||
          pipelineStage != null ||
          offerStatus != null ||
          employmentStatus != null ||
          applicationStatus != null;
      final resolvedLifecycle = lifecycleStage != null
          ? normalizeLifecycleStage(lifecycleStage)
          : lifecycleStageFromHiringChange(
              pipelineStage:
                  resolvedPipeline ??
                  existing?.normalizedPipelineStage ??
                  'applied',
              offerStatus:
                  resolvedOffer ?? existing?.normalizedOfferStatus ?? 'none',
              applicationStatus: applicationStatus?.trim().isNotEmpty == true
                  ? applicationStatus!.trim()
                  : (data['status']?.toString() ?? existing?.status),
            );
      if (touchLifecycle) {
        data['lifecycleStage'] = resolvedLifecycle;
      }

      final nextEmployment = employmentStatus != null
          ? normalizeEmploymentStatus(employmentStatus)
          : null;
      final claimingEmployment =
          nextEmployment == 'joining_soon' || nextEmployment == 'active';
      final releasingEmployment =
          nextEmployment == 'none' || nextEmployment == 'left';

      if (claimingEmployment && existing != null) {
        await _assertCanClaimEmployment(
          applicantId: existing.applicantId,
          applicationId: applicationId,
        );
      }

      await _applicationsRef.doc(applicationId).update(data);

      if (claimingEmployment && existing != null) {
        await _setEmploymentLock(
          applicantId: existing.applicantId,
          applicationId: applicationId,
          companyId: existing.companyId,
          jobId: existing.jobId,
          status: nextEmployment!,
        );
        // Company can only decline its own other pending offers.
        try {
          await _declineOtherPendingOffers(
            applicantId: existing.applicantId,
            acceptedApplicationId: applicationId,
            companyIdOnly: existing.companyId,
          );
        } catch (_) {
          // Non-fatal: exclusive lock already claimed.
        }
      } else if (releasingEmployment && existing != null) {
        await _clearEmploymentLockIfOwned(
          applicantId: existing.applicantId,
          applicationId: applicationId,
        );
      }

      if (existing != null &&
          (pipelineStage != null ||
              offerStatus != null ||
              lifecycleStage != null ||
              employmentStatus != null)) {
        await appendTimelineEvent(
          HiringTimelineEvent(
            id: '',
            applicationId: applicationId,
            companyId: existing.companyId,
            candidateId: existing.applicantId,
            stage: resolvedLifecycle,
            title: lifecycleStageLabel(resolvedLifecycle),
            description:
                'Hiring lifecycle updated to ${lifecycleStageLabel(resolvedLifecycle)}.',
            actorId: existing.companyId,
            actorRole: 'company',
            createdAt: DateTime.now(),
            visibleToCandidate: true,
          ),
        );
      }
    } on FirestoreException {
      rethrow;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to update hiring data: ${e.toString()}');
    }
  }

  @override
  Future<void> updateCandidateResponse({
    required String applicationId,
    required String offerStatus,
    String? candidateResponseMessage,
  }) async {
    try {
      final existing = await getApplication(applicationId);
      if (existing == null) {
        throw const FirestoreException(
          'Application not found.',
          'not-found',
        );
      }
      final normalized = normalizeOfferStatus(offerStatus);
      final lifecycle = switch (normalized) {
        'accepted' => 'offer_accepted',
        'declined' => 'offer_declined',
        'clarification' => 'offer_sent',
        _ => 'offer_sent',
      };
      final employment = normalized == 'accepted' ? 'joining_soon' : 'none';
      final visible = switch (normalized) {
        'accepted' => 'offerAccepted',
        'declined' => 'offerDeclined',
        'clarification' => 'offerClarification',
        _ => 'offer_pending',
      };

      if (normalized == 'accepted') {
        await _assertCanClaimEmployment(
          applicantId: existing.applicantId,
          applicationId: applicationId,
        );
      }

      await _applicationsRef.doc(applicationId).update({
        'offerStatus': normalized,
        'candidateVisibleStatus': visible,
        'candidateResponseMessage': candidateResponseMessage?.trim() ?? '',
        'offerRespondedAt': Timestamp.fromDate(DateTime.now()),
        'lifecycleStage': lifecycle,
        'employmentStatus': employment,
        if (normalized == 'accepted')
          'onboardingChecklist': OnboardingChecklistItem.defaultChecklist()
              .map((item) => item.toMap())
              .toList(),
        'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
      });

      if (normalized == 'accepted') {
        await _setEmploymentLock(
          applicantId: existing.applicantId,
          applicationId: applicationId,
          companyId: existing.companyId,
          jobId: existing.jobId,
          status: 'joining_soon',
        );
        try {
          await _declineOtherPendingOffers(
            applicantId: existing.applicantId,
            acceptedApplicationId: applicationId,
          );
        } catch (_) {
          // Non-fatal: accepted offer + lock already saved.
        }
      } else if (normalized == 'declined') {
        await _clearEmploymentLockIfOwned(
          applicantId: existing.applicantId,
          applicationId: applicationId,
        );
      }

      await appendTimelineEvent(
        HiringTimelineEvent(
          id: '',
          applicationId: applicationId,
          companyId: existing.companyId,
          candidateId: existing.applicantId,
          stage: lifecycle,
          title: lifecycleStageLabel(lifecycle),
          description: normalized == 'clarification'
              ? 'Candidate requested clarification on the offer.'
              : 'Candidate ${normalized == 'accepted' ? 'accepted' : 'declined'} the offer.',
          actorId: existing.applicantId,
          actorRole: existing.role,
          createdAt: DateTime.now(),
        ),
      );
    } on FirestoreException {
      rethrow;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to update candidate response: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> submitEvaluationAnswers({
    required String applicationId,
    required List<String> answers,
  }) async {
    try {
      await _applicationsRef.doc(applicationId).update({
        'evaluationAnswers': answers.map((item) => item.trim()).toList(),
        'evaluationRequestStatus': 'submitted',
        'evaluationSubmittedAt': Timestamp.fromDate(DateTime.now()),
        'candidateVisibleStatus': 'evaluationSubmitted',
        'lifecycleStage': 'portfolio_reviewed',
        'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to submit evaluation answers: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> appendTimelineEvent(HiringTimelineEvent event) async {
    try {
      final ref = _timelineRef(event.applicationId).doc();
      await ref.set(event.toJson());
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to append timeline: ${e.toString()}');
    }
  }

  @override
  Stream<List<HiringTimelineEvent>> streamTimeline(String applicationId) {
    return _timelineRef(applicationId).snapshots().map((snapshot) {
      final events =
          snapshot.docs.map(HiringTimelineEvent.fromFirestore).toList();
      events.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return events;
    });
  }

  @override
  @Deprecated('Use NotificationRepository / NotificationService')
  Future<void> createUserNotification(
    UserNotificationModel notification,
  ) {
    return _notifications.createNotification(notification);
  }

  @override
  @Deprecated('Use NotificationRepository')
  Stream<List<UserNotificationModel>> streamUserNotifications(String userId) {
    return _notifications.streamUserNotifications(userId);
  }

  @override
  @Deprecated('Use NotificationRepository')
  Future<void> markNotificationRead(String notificationId) {
    return _notifications.markNotificationRead(notificationId);
  }

  @override
  Future<ApplicationModel?> getApplication(String applicationId) async {
    try {
      final doc = await _applicationsRef.doc(applicationId).get();
      if (!doc.exists || doc.data() == null) return null;
      return ApplicationModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to load application: ${e.toString()}');
    }
  }

  @override
  Stream<ApplicationModel?> streamApplication(String applicationId) {
    return _applicationsRef.doc(applicationId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ApplicationModel.fromFirestore(doc);
    });
  }

  @override
  Stream<List<ApplicationModel>> streamApplicationsByUser(String applicantId) {
    return _applicationsRef
        .where('applicantId', isEqualTo: applicantId)
        .snapshots()
        .map((snapshot) {
          final applications = snapshot.docs
              .map((doc) => ApplicationModel.fromFirestore(doc))
              .toList();
          applications.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
          return applications;
        });
  }

  @override
  Stream<List<ApplicationModel>> streamApplicationsForJob(String jobId) {
    return _applicationsRef.where('jobId', isEqualTo: jobId).snapshots().map((
      snapshot,
    ) {
      final applications = snapshot.docs
          .map((doc) => ApplicationModel.fromFirestore(doc))
          .toList();
      applications.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
      return applications;
    });
  }

  @override
  Stream<List<ApplicationModel>> streamApplicationsForCompany(
    String companyId,
  ) {
    return _applicationsRef
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) {
          final applications = snapshot.docs
              .map((doc) => ApplicationModel.fromFirestore(doc))
              .toList();
          applications.sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
          return applications;
        });
  }
}
