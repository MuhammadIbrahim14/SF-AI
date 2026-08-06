/// Stable notification category + event catalog for SkillForge.
///
/// Writers should use these constants with [NotificationService].
/// Wave 0 migrates hiring; Waves 1–5 hook the remaining domains.
abstract final class NotificationCategories {
  static const String batch = 'batch';
  static const String learning = 'learning';
  static const String hiring = 'hiring';
  static const String commerce = 'commerce';
  static const String support = 'support';
  static const String admin = 'admin';
  static const String system = 'system';
  static const String marketing = 'marketing';

  static const List<String> all = [
    batch,
    learning,
    hiring,
    commerce,
    support,
    admin,
    system,
    marketing,
  ];

  /// Categories exposed in user preference toggles.
  ///
  /// [system] is intentionally omitted — [NotificationService] always
  /// delivers system alerts (payments, subscription). [marketing] is
  /// listed for future use; no writers ship yet.
  static const List<String> preferenceKeys = [
    batch,
    learning,
    hiring,
    commerce,
    support,
    admin,
    marketing,
  ];
}

abstract final class NotificationEvents {
  // Learning / batches — Teacher ↔ Student
  static const String batchJoinRequested = 'batch.join_requested';
  static const String batchJoinApproved = 'batch.join_approved';
  static const String batchJoinDenied = 'batch.join_denied';
  static const String batchAnnouncementPosted = 'batch.announcement_posted';
  static const String batchSessionScheduled = 'batch.session_scheduled';
  static const String batchSessionUpdated = 'batch.session_updated';
  static const String batchSessionCancelled = 'batch.session_cancelled';

  static const String learningCoursePublished = 'learning.course_published';
  static const String learningAssignmentPublished =
      'learning.assignment_published';
  static const String learningProjectPublished = 'learning.project_published';
  static const String learningGrandTestPublished =
      'learning.grand_test_published';
  static const String learningSubmissionReceived =
      'learning.submission_received';
  static const String learningSubmissionGraded = 'learning.submission_graded';
  static const String learningCertificateIssued = 'learning.certificate_issued';
  static const String learningCertificateRevoked =
      'learning.certificate_revoked';

  // Hiring — Company ↔ Student/Freelancer
  static const String hiringApplicationReceived =
      'hiring.application_received';
  static const String hiringStatusChanged = 'hiring.status_changed';
  static const String hiringOfferSent = 'hiring.offer_sent';
  static const String hiringOfferAccepted = 'hiring.offer_accepted';
  static const String hiringOfferDeclined = 'hiring.offer_declined';
  static const String hiringInterviewScheduled = 'hiring.interview_scheduled';
  static const String hiringInterviewUpdated = 'hiring.interview_updated';
  static const String hiringInterviewCompleted = 'hiring.interview_completed';
  static const String hiringHired = 'hiring.hired';
  static const String hiringJoined = 'hiring.joined';
  static const String hiringWelcomePack = 'hiring.welcome_pack';
  static const String hiringHrMessage = 'hiring.hr_message';
  static const String hiringProbationUpdated = 'hiring.probation_updated';
  static const String hiringOffboarded = 'hiring.offboarded';
  static const String hiringJoinReminder = 'hiring.join_reminder';
  static const String hiringDocsReminder = 'hiring.docs_reminder';

  // Commerce — Client ↔ Freelancer
  static const String commerceServiceRequestCreated =
      'commerce.service_request_created';
  static const String commerceServiceRequestStatus =
      'commerce.service_request_status';
  static const String commerceOrderStatus = 'commerce.order_status';

  // Support / Admin
  static const String supportTicketCreated = 'support.ticket_created';
  static const String supportTicketReplied = 'support.ticket_replied';
  static const String supportDisputeOpened = 'support.dispute_opened';
  static const String supportResolutionPeer = 'support.resolution_peer';
  static const String adminVerificationDecided = 'admin.verification_decided';
  static const String adminPayoutDecided = 'admin.payout_decided';
  static const String adminPayoutRequested = 'admin.payout_requested';
  static const String adminResolutionUpdated = 'admin.resolution_updated';
  static const String adminAiCreditDecided = 'admin.ai_credit_decided';
  static const String adminAccountStatusChanged = 'admin.account_status_changed';

  // System
  static const String systemSubscriptionExpiring =
      'system.subscription_expiring';
  static const String systemPaymentSucceeded = 'system.payment_succeeded';
  static const String systemPaymentFailed = 'system.payment_failed';

  // Learning — free / paid enrollment receipts
  static const String learningStudentEnrolled = 'learning.student_enrolled';
}

/// Optional helpers for default copy / deep links (used by later waves).
abstract final class NotificationEventDefaults {
  static String categoryForEvent(String event) {
    if (event.startsWith('batch.')) return NotificationCategories.batch;
    if (event.startsWith('learning.')) return NotificationCategories.learning;
    if (event.startsWith('hiring.')) return NotificationCategories.hiring;
    if (event.startsWith('commerce.')) return NotificationCategories.commerce;
    if (event.startsWith('support.')) return NotificationCategories.support;
    if (event.startsWith('admin.')) return NotificationCategories.admin;
    return NotificationCategories.system;
  }
}
