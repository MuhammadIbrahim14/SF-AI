import '../../../../core/notifications/notification_events.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../models/application_model.dart';
import '../../../../models/hiring_lifecycle_models.dart';
import '../../../../models/interview_model.dart';
import '../../../../repositories/application_repository.dart';
import '../../../../services/notification_service.dart';
import 'employment_hr_thread_repository.dart';

/// Phase 5 hiring lifecycle helpers — reuses ApplicationRepository + shared notifications.
class HiringLifecycleService {
  const HiringLifecycleService(
    this._applications,
    this._notifications, {
    EmploymentHrThreadRepository? hrThreads,
  }) : _hrThreads = hrThreads;

  final ApplicationRepository _applications;
  final NotificationService _notifications;
  final EmploymentHrThreadRepository? _hrThreads;

  static const joinReminderCooldown = Duration(days: 2);
  static const docsReminderCooldown = Duration(days: 3);
  static const joinReminderWindowDays = 7;

  Future<void> notifyHiringEvent({
    required String userId,
    required String title,
    required String body,
    required String applicationId,
    String type = 'hiring',
    String event = NotificationEvents.hiringStatusChanged,
    String? actorId,
    String? actorName,
    String? actorRole,
    String? routeName,
    Map<String, String>? routeParams,
  }) async {
    await _notifications.notifyOne(
      recipientId: userId,
      title: title,
      body: body,
      category: NotificationCategories.hiring,
      event: event,
      type: type,
      relatedPath: 'applications/$applicationId',
      applicationId: applicationId,
      actorId: actorId,
      actorName: actorName,
      actorRole: actorRole,
      routeName: routeName,
      routeParams: routeParams,
    );
  }

  Future<bool> markJoined({required String applicationId}) async {
    final app = await _applications.getApplication(applicationId);
    if (app == null) return false;
    final checklist = app.onboardingChecklist.isEmpty
        ? OnboardingChecklistItem.defaultChecklist()
        : app.onboardingChecklist;
    final joinedAt = DateTime.now();
    final profile = app.employmentProfile.isEmpty
        ? EmploymentProfile.fromOffer(
            offerRole: app.offerRole,
            offerDepartment: app.offerDepartment,
            offerLocation: app.offerLocation,
          )
        : app.employmentProfile;
    // Probation is optional — only keep if company already configured one.
    // Do not auto-start a 90-day clock from job/contract duration.
    final welcomePack = app.welcomePack.isPublished
        ? app.welcomePack
        : WelcomePack.defaultForJoin(
            publishedBy: app.companyId,
            publishedAt: joinedAt,
          );
    await _applications.updateApplicationHiringData(
      applicationId: applicationId,
      pipelineStage: 'hired',
      offerStatus: 'accepted',
      lifecycleStage: 'joined',
      employmentStatus: 'active',
      joinedAt: joinedAt,
      candidateVisibleStatus: 'hired',
      onboardingChecklist: checklist,
      employmentProfile: profile,
      welcomePack: welcomePack,
      recommendedNextStep: 'Employee active. Complete onboarding checklist.',
    );
    await notifyHiringEvent(
      userId: app.applicantId,
      title: 'Welcome aboard',
      body: 'You have joined the company. Complete your onboarding checklist.',
      applicationId: applicationId,
      event: NotificationEvents.hiringJoined,
    );
    if (!app.welcomePack.isPublished) {
      await notifyHiringEvent(
        userId: app.applicantId,
        title: 'Welcome pack ready',
        body: 'Your company published an onboarding welcome pack.',
        applicationId: applicationId,
        event: NotificationEvents.hiringWelcomePack,
        routeName: 'my-employment-detail',
        routeParams: {'applicationId': applicationId},
      );
    }
    return true;
  }

  /// Audit stamp when offer letter PDF is first generated (idempotent).
  Future<void> markOfferDocumentGenerated({
    required String applicationId,
  }) async {
    final app = await _applications.getApplication(applicationId);
    if (app == null || app.offerDocumentGeneratedAt != null) return;
    await _applications.updateApplicationHiringData(
      applicationId: applicationId,
      offerDocumentGeneratedAt: DateTime.now(),
    );
  }

  Future<bool> updateOnboardingItem({
    required String applicationId,
    required String itemId,
    required bool completed,
    bool candidateOnly = false,
  }) async {
    final app = await _applications.getApplication(applicationId);
    if (app == null) return false;
    if (candidateOnly) {
      OnboardingChecklistItem? item;
      for (final entry in app.onboardingChecklist) {
        if (entry.id == itemId) {
          item = entry;
          break;
        }
      }
      if (item == null || !item.isCandidateCompletable) return false;
    }
    final updated = app.onboardingChecklist.map((item) {
      if (item.id != itemId) return item;
      return item.copyWith(
        completed: completed,
        completedAt: completed ? DateTime.now() : null,
      );
    }).toList();
    await _applications.updateApplicationHiringData(
      applicationId: applicationId,
      onboardingChecklist: updated,
    );
    return true;
  }

  Future<bool> publishWelcomePack({
    required String applicationId,
    required WelcomePack pack,
    required String publishedBy,
  }) async {
    final app = await _applications.getApplication(applicationId);
    if (app == null) return false;
    final published = pack.copyWith(
      publishedAt: DateTime.now(),
      publishedBy: publishedBy,
    );
    await _applications.updateApplicationHiringData(
      applicationId: applicationId,
      welcomePack: published,
    );
    await notifyHiringEvent(
      userId: app.applicantId,
      title: 'Welcome pack updated',
      body: 'Your company published or updated your employment welcome pack.',
      applicationId: applicationId,
      event: NotificationEvents.hiringWelcomePack,
      actorId: publishedBy,
      actorRole: 'company',
      routeName: 'my-employment-detail',
      routeParams: {'applicationId': applicationId},
    );
    return true;
  }

  Future<bool> updateEmploymentProfile({
    required String applicationId,
    required EmploymentProfile profile,
  }) async {
    final app = await _applications.getApplication(applicationId);
    if (app == null) return false;
    await _applications.updateApplicationHiringData(
      applicationId: applicationId,
      employmentProfile: profile,
    );
    return true;
  }

  Future<bool> addEmploymentDocument({
    required String applicationId,
    required EmploymentDocument document,
    required String actorId,
    required bool asCandidate,
  }) async {
    final app = await _applications.getApplication(applicationId);
    if (app == null) return false;
    final docs = [...app.documents, document];
    var checklist = app.onboardingChecklist;
    if (checklist.isEmpty) {
      checklist = OnboardingChecklistItem.defaultChecklist();
    }
    checklist = checklist.map((item) {
      if (item.id != 'submit_documents') return item;
      if (item.completed) return item;
      return item.copyWith(completed: true, completedAt: DateTime.now());
    }).toList();

    await _applications.updateApplicationHiringData(
      applicationId: applicationId,
      documents: docs,
      onboardingChecklist: checklist,
    );

    final peerId = asCandidate ? app.companyId : app.applicantId;
    await notifyHiringEvent(
      userId: peerId,
      title: 'Employment document uploaded',
      body: '"${document.title}" was added to the employment vault.',
      applicationId: applicationId,
      event: NotificationEvents.hiringDocsReminder,
      actorId: actorId,
      actorRole: asCandidate ? 'candidate' : 'company',
    );
    return true;
  }

  Future<String?> ensureHrThread({required String applicationId}) async {
    final hr = _hrThreads;
    if (hr == null) return null;
    final app = await _applications.getApplication(applicationId);
    if (app == null) return null;
    final threadId = app.hrThreadId.trim().isNotEmpty
        ? app.hrThreadId.trim()
        : app.id;
    await hr.ensureThread(
      threadId: threadId,
      applicationId: app.id,
      companyId: app.companyId,
      applicantId: app.applicantId,
    );
    // Linking hrThreadId on the application is best-effort; chat can work
    // with applicationId as the thread key even if this write is denied.
    if (app.hrThreadId != threadId) {
      try {
        await _applications.updateApplicationHiringData(
          applicationId: applicationId,
          hrThreadId: threadId,
        );
      } catch (error) {
        AppLogger.warn('HR thread link update failed: $error');
      }
    }
    return threadId;
  }

  Stream<List<EmploymentHrMessage>> streamHrMessages(String threadId) {
    final hr = _hrThreads;
    if (hr == null || threadId.trim().isEmpty) {
      return Stream.value(const <EmploymentHrMessage>[]);
    }
    return hr.streamMessages(threadId);
  }

  Future<bool> sendHrMessage({
    required String applicationId,
    required String senderId,
    required String senderRole,
    required String body,
  }) async {
    final hr = _hrThreads;
    if (hr == null) return false;
    final app = await _applications.getApplication(applicationId);
    if (app == null) return false;
    final threadId = await ensureHrThread(applicationId: applicationId);
    if (threadId == null) return false;
    await hr.sendMessage(
      threadId: threadId,
      applicationId: applicationId,
      companyId: app.companyId,
      applicantId: app.applicantId,
      senderId: senderId,
      senderRole: senderRole,
      body: body,
    );
    final peerId = senderId == app.companyId ? app.applicantId : app.companyId;
    await notifyHiringEvent(
      userId: peerId,
      title: 'New HR message',
      body: body.trim().length > 100
          ? '${body.trim().substring(0, 97)}...'
          : body.trim(),
      applicationId: applicationId,
      event: NotificationEvents.hiringHrMessage,
      actorId: senderId,
      actorRole: senderRole,
      routeName: senderRole == 'company'
          ? 'my-employment-detail'
          : 'company-employee-detail',
      routeParams: {'applicationId': applicationId},
    );
    return true;
  }

  Future<bool> startProbation({
    required String applicationId,
    int days = 90,
  }) async {
    final app = await _applications.getApplication(applicationId);
    if (app == null || !app.isActiveEmployee) return false;
    final startsAt = DateTime.now();
    final updated = ProbationInfo.defaultFromJoin(startsAt, days: days);
    await _applications.updateApplicationHiringData(
      applicationId: applicationId,
      probation: updated,
      recommendedNextStep: 'Probation started ($days days).',
    );
    await notifyHiringEvent(
      userId: app.applicantId,
      title: 'Probation started',
      body: 'Your probation period is $days days from today.',
      applicationId: applicationId,
      event: NotificationEvents.hiringProbationUpdated,
    );
    return true;
  }

  Future<bool> completeProbation({
    required String applicationId,
    String notes = '',
  }) async {
    final app = await _applications.getApplication(applicationId);
    if (app == null) return false;
    final updated = app.probation.copyWith(
      status: 'completed',
      notes: notes.trim().isEmpty ? app.probation.notes : notes.trim(),
    );
    await _applications.updateApplicationHiringData(
      applicationId: applicationId,
      probation: updated,
      recommendedNextStep: 'Probation completed.',
    );
    await notifyHiringEvent(
      userId: app.applicantId,
      title: 'Probation completed',
      body: 'Your probation period has been marked complete.',
      applicationId: applicationId,
      event: NotificationEvents.hiringProbationUpdated,
    );
    return true;
  }

  /// Updates the total probation length while keeping its original start date.
  Future<bool> updateProbationDuration({
    required String applicationId,
    required int totalDays,
  }) async {
    final app = await _applications.getApplication(applicationId);
    final probation = app?.probation;
    if (app == null ||
        !app.isActiveEmployee ||
        probation == null ||
        (probation.normalizedStatus != 'active' &&
            probation.normalizedStatus != 'extended') ||
        probation.startsAt == null) {
      return false;
    }
    final days = totalDays.clamp(7, 365);
    final updated = probation.copyWith(
      endsAt: probation.startsAt!.add(Duration(days: days)),
    );
    await _applications.updateApplicationHiringData(
      applicationId: applicationId,
      probation: updated,
      recommendedNextStep: 'Probation duration updated to $days days.',
    );
    await notifyHiringEvent(
      userId: app.applicantId,
      title: 'Probation updated',
      body: 'Your probation period is now $days days from its start date.',
      applicationId: applicationId,
      event: NotificationEvents.hiringProbationUpdated,
    );
    return true;
  }

  /// Starts a new probation window for an active employee.
  ///
  /// This intentionally supports restarting a completed probation, but never
  /// changes an employee who has left the company.
  Future<bool> restartProbation({
    required String applicationId,
    int days = 90,
  }) async {
    final app = await _applications.getApplication(applicationId);
    if (app == null ||
        !app.isActiveEmployee ||
        app.probation.normalizedStatus == 'none') {
      return false;
    }
    final duration = days.clamp(7, 365);
    final startsAt = DateTime.now();
    final updated = ProbationInfo.defaultFromJoin(startsAt, days: duration);
    await _applications.updateApplicationHiringData(
      applicationId: applicationId,
      probation: updated,
      recommendedNextStep: 'Probation restarted ($duration days).',
    );
    await notifyHiringEvent(
      userId: app.applicantId,
      title: 'Probation restarted',
      body:
          'Your company restarted your probation for $duration days from today.',
      applicationId: applicationId,
      event: NotificationEvents.hiringProbationUpdated,
    );
    return true;
  }

  Future<bool> extendProbation({
    required String applicationId,
    required int extraDays,
    String notes = '',
  }) async {
    final app = await _applications.getApplication(applicationId);
    if (app == null) return false;
    final base = app.probation.endsAt ?? DateTime.now();
    final updated = app.probation.copyWith(
      endsAt: base.add(Duration(days: extraDays.clamp(1, 365))),
      status: 'extended',
      notes: notes.trim().isEmpty ? app.probation.notes : notes.trim(),
    );
    await _applications.updateApplicationHiringData(
      applicationId: applicationId,
      probation: updated,
      recommendedNextStep: 'Probation extended by $extraDays days.',
    );
    await notifyHiringEvent(
      userId: app.applicantId,
      title: 'Probation extended',
      body: 'Your probation was extended by $extraDays days.',
      applicationId: applicationId,
      event: NotificationEvents.hiringProbationUpdated,
    );
    return true;
  }

  Future<bool> markLeft({
    required String applicationId,
    required String reason,
    String notes = '',
  }) async {
    final app = await _applications.getApplication(applicationId);
    if (app == null) return false;
    final offboarding = OffboardingInfo(
      leftAt: DateTime.now(),
      reason: reason.trim(),
      notes: notes.trim(),
      checklist: OffboardingInfo.defaultChecklist(),
    );
    await _applications.updateApplicationHiringData(
      applicationId: applicationId,
      employmentStatus: 'left',
      offboarding: offboarding,
      candidateVisibleStatus: 'left',
      recommendedNextStep: 'Employment ended.',
    );
    await notifyHiringEvent(
      userId: app.applicantId,
      title: 'Employment ended',
      body: reason.trim().isEmpty
          ? 'Your employment status was marked as left.'
          : 'Employment ended: ${reason.trim()}',
      applicationId: applicationId,
      event: NotificationEvents.hiringOffboarded,
      routeName: 'my-employment-detail',
      routeParams: {'applicationId': applicationId},
    );
    return true;
  }

  Future<bool> toggleOffboardingItem({
    required String applicationId,
    required String itemId,
    required bool completed,
  }) async {
    final app = await _applications.getApplication(applicationId);
    if (app == null || !app.offboarding.hasData) return false;
    final checklist = app.offboarding.checklist.map((item) {
      if (item.id != itemId) return item;
      return item.copyWith(
        completed: completed,
        completedAt: completed ? DateTime.now() : null,
      );
    }).toList();
    await _applications.updateApplicationHiringData(
      applicationId: applicationId,
      offboarding: app.offboarding.copyWith(checklist: checklist),
    );
    return true;
  }

  /// Client-side join reminders with cooldown (demo-safe, no cron).
  Future<int> maybeSendJoinReminders({
    required List<ApplicationModel> applications,
    required bool notifyCandidate,
  }) async {
    var sent = 0;
    final now = DateTime.now();
    for (final app in applications.where((a) => a.isJoiningSoon)) {
      if (app.lastJoinReminderAt != null &&
          now.difference(app.lastJoinReminderAt!) < joinReminderCooldown) {
        continue;
      }
      final joinDate = _parseJoiningDate(app.offerJoiningDate);
      if (joinDate == null) continue;
      final daysUntil = joinDate.difference(now).inDays;
      if (daysUntil > joinReminderWindowDays || daysUntil < -1) continue;

      final body = daysUntil < 0
          ? 'Joining date has passed — confirm start or update the schedule.'
          : daysUntil == 0
          ? 'Joining day is today.'
          : 'Joining in $daysUntil day${daysUntil == 1 ? '' : 's'}.';

      if (notifyCandidate) {
        await notifyHiringEvent(
          userId: app.applicantId,
          title: 'Joining reminder',
          body: body,
          applicationId: app.id,
          event: NotificationEvents.hiringJoinReminder,
          routeName: 'my-employment-detail',
          routeParams: {'applicationId': app.id},
        );
      } else {
        await notifyHiringEvent(
          userId: app.companyId,
          title: 'Joining reminder',
          body: '${app.displayJobTitle}: $body',
          applicationId: app.id,
          event: NotificationEvents.hiringJoinReminder,
          routeName: 'company-employee-detail',
          routeParams: {'applicationId': app.id},
        );
      }

      await _applications.updateApplicationHiringData(
        applicationId: app.id,
        lastJoinReminderAt: now,
      );
      sent++;
    }
    return sent;
  }

  /// Soft docs reminder when onboarding docs incomplete after join.
  Future<int> maybeSendDocsReminders({
    required List<ApplicationModel> applications,
    required bool notifyCandidate,
  }) async {
    var sent = 0;
    final now = DateTime.now();
    for (final app in applications.where((a) => a.isActiveEmployee)) {
      if (app.lastDocsReminderAt != null &&
          now.difference(app.lastDocsReminderAt!) < docsReminderCooldown) {
        continue;
      }
      OnboardingChecklistItem? submitItem;
      for (final entry in app.onboardingChecklist) {
        if (entry.id == 'submit_documents') {
          submitItem = entry;
          break;
        }
      }
      final docsIncomplete =
          (submitItem != null && !submitItem.completed) ||
          app.documents.isEmpty;
      if (!docsIncomplete) continue;
      if (app.joinedAt != null && now.difference(app.joinedAt!).inDays < 1) {
        continue;
      }

      if (notifyCandidate) {
        await notifyHiringEvent(
          userId: app.applicantId,
          title: 'Documents reminder',
          body: 'Please upload your employment documents to finish onboarding.',
          applicationId: app.id,
          event: NotificationEvents.hiringDocsReminder,
          routeName: 'my-employment-detail',
          routeParams: {'applicationId': app.id},
        );
      } else {
        await notifyHiringEvent(
          userId: app.companyId,
          title: 'Documents reminder',
          body:
              '${app.displayJobTitle}: candidate still needs employment documents.',
          applicationId: app.id,
          event: NotificationEvents.hiringDocsReminder,
          routeName: 'company-employee-detail',
          routeParams: {'applicationId': app.id},
        );
      }

      await _applications.updateApplicationHiringData(
        applicationId: app.id,
        lastDocsReminderAt: now,
      );
      sent++;
    }
    return sent;
  }

  DateTime? _parseJoiningDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso;
    final parts = trimmed.split(RegExp(r'[/-]'));
    if (parts.length == 3) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      if (a != null && b != null && c != null) {
        if (parts[0].length == 4) return DateTime(a, b, c);
        if (parts[2].length == 4) return DateTime(c, b, a);
      }
    }
    return null;
  }

  HiringAnalyticsSnapshot buildAnalytics({
    required List<ApplicationModel> applications,
    required List<InterviewModel> interviews,
  }) {
    int countLifecycle(String stage) =>
        applications.where((a) => a.normalizedLifecycleStage == stage).length;

    final offersAccepted = applications
        .where((a) => a.normalizedOfferStatus == 'accepted')
        .length;
    final offersDeclined = applications
        .where((a) => a.normalizedOfferStatus == 'declined')
        .length;
    final responded = offersAccepted + offersDeclined;

    final interviewsCompleted = interviews.where((i) => i.isCompleted).length;
    final interviewsTotal = interviews.where((i) => !i.isCancelled).length;

    final activeEmployees = applications
        .where((a) => a.isActiveEmployee)
        .length;
    final pendingJoining = applications.where((a) => a.isJoiningSoon).length;
    final hired = applications
        .where(
          (a) => a.normalizedPipelineStage == 'hired' || a.isActiveEmployee,
        )
        .length;

    final hiringDurations = <double>[];
    for (final app in applications.where((a) => a.joinedAt != null)) {
      hiringDurations.add(
        app.joinedAt!.difference(app.appliedAt).inHours / 24.0,
      );
    }
    final avgDays = hiringDurations.isEmpty
        ? 0.0
        : hiringDurations.reduce((a, b) => a + b) / hiringDurations.length;

    final skillCounts = <String, int>{};
    for (final app in applications.where(
      (a) => a.isActiveEmployee || a.normalizedPipelineStage == 'hired',
    )) {
      for (final skill in app.matchedSkills) {
        skillCounts[skill] = (skillCounts[skill] ?? 0) + 1;
      }
    }
    final topSkills = skillCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final funnel = <String, int>{
      for (final stage in hiringLifecycleStages) stage: countLifecycle(stage),
    };

    return HiringAnalyticsSnapshot(
      totalApplications: applications.length,
      funnelCounts: funnel,
      offerAcceptanceRate: responded == 0
          ? 0
          : (offersAccepted / responded) * 100,
      interviewCompletionRate: interviewsTotal == 0
          ? 0
          : (interviewsCompleted / interviewsTotal) * 100,
      employeeConversionRate: applications.isEmpty
          ? 0
          : (hired / applications.length) * 100,
      averageHiringDays: avgDays,
      topSkillsHired: topSkills.take(8).map((e) => e.key).toList(),
      activeEmployees: activeEmployees,
      pendingJoining: pendingJoining,
      offersSent: applications
          .where((a) => a.normalizedOfferStatus == 'sent')
          .length,
      rejected: applications
          .where((a) => a.normalizedPipelineStage == 'rejected')
          .length,
      interviewScheduled: applications
          .where((a) => a.normalizedLifecycleStage == 'interview_scheduled')
          .length,
      newApplications: applications
          .where((a) => a.normalizedLifecycleStage == 'applied')
          .length,
    );
  }
}
