const allowByRole = {
  teacher: new Set([
    'teacherCourseOutline',
    'teacherCourseBlueprint',
    'teacherLessonBuilder',
    'teacherAssignmentBuilder',
    'teacherProjectAssignmentBuilder',
    'teacherQuizBuilder',
    'teacherGrandTestBuilder',
    'teacherImproveContent',
    'teacherBatchAnnouncementDraft',
    'teacherLessonPlan',
    'teacherQuizGenerator',
    'teacherAssignmentGenerator',
    'teacherRubricGenerator',
    'teacherImproveCourseText',
    'teacherCareerAdvisor',
    'careerSkillGapAnalysis',
    'careerLearningRoadmap',
    'careerResumeReview',
    'careerPortfolioReview',
    'careerMarketInsights',
  ]),
  student: new Set([
    'studentTutorChat',
    'studentTutorMessage',
    'studentTutorExplain',
    'studentLessonExplain',
    'studentPracticeQuestions',
    'studentLessonSummary',
    'studentQuizReview',
    'studentRevisionPlan',
    'studentConceptSimplifier',
    'studentHint',
    'studentCodeExplanation',
    'interviewLabQuestionBank',
    'interviewLabAnswerCritique',
    'interviewLabFollowUp',
    'interviewLabDebrief',
    'studentCareerAdvisor',
    'careerSkillGapAnalysis',
    'careerLearningRoadmap',
    'careerResumeReview',
    'careerPortfolioReview',
    'careerMarketInsights',
  ]),
  company: new Set([
    'companyJobPostBuilder',
    'companyJobPostImprover',
    'companyCandidateSummary',
    'companyCandidateComparison',
    'companyShortlistAssistant',
    'companyInterviewQuestionBuilder',
    'companyInterviewScorecardBuilder',
    'companyInterviewKitBuilder',
    'companyHiringPipelineInsights',
    'companyCandidateMessageDraft',
    'companySkillGapAnalysis',
    'companyJobPostGenerator',
    'companyInterviewQuestions',
    'companyCandidateRubric',
    'companyApplicationSummary',
    'companySkillMatchExplanation',
    'companyJobMatchScore',
    'companyHiringRecommendation',
    'interviewLabQuestionBank',
    'interviewLabAnswerCritique',
    'interviewLabFollowUp',
    'interviewLabDebrief',
    'companyCareerAdvisor',
    'careerSkillGapAnalysis',
    'careerLearningRoadmap',
    'careerResumeReview',
    'careerPortfolioReview',
    'careerMarketInsights',
  ]),
  admin: new Set([
    'adminResolutionAnalysis',
    'adminResolutionSummary',
    'adminResolutionCaseSummary',
    'adminResolutionEvidenceAnalysis',
    'adminResolutionTimelineBuilder',
    'adminResolutionPolicyCheck',
    'adminResolutionRiskAnalysis',
    'adminResolutionDraftDecision',
    'adminSettlementRecommendation',
    'adminRefundRiskReview',
    'adminPayoutRiskReview',
    'interviewLabQuestionBank',
    'interviewLabAnswerCritique',
    'interviewLabFollowUp',
    'interviewLabDebrief',
    'companyJobMatchScore',
    'companyHiringRecommendation',
  ]),
  superadmin: new Set([
    'adminResolutionAnalysis',
    'adminResolutionSummary',
    'adminResolutionCaseSummary',
    'adminResolutionEvidenceAnalysis',
    'adminResolutionTimelineBuilder',
    'adminResolutionPolicyCheck',
    'adminResolutionRiskAnalysis',
    'adminResolutionDraftDecision',
    'adminSettlementRecommendation',
    'adminRefundRiskReview',
    'adminPayoutRiskReview',
    'interviewLabQuestionBank',
    'interviewLabAnswerCritique',
    'interviewLabFollowUp',
    'interviewLabDebrief',
    'companyJobMatchScore',
    'companyHiringRecommendation',
  ]),
  freelancer: new Set([
    'freelancerProposalDraft',
    'freelancerServiceListingBuilder',
    'freelancerServiceListingImprover',
    'freelancerScopeClarifier',
    'freelancerDeliveryNoteBuilder',
    'freelancerClientUpdateDraft',
    'freelancerRevisionResponseDraft',
    'freelancerDisputeEvidenceSummary',
    'freelancerProfileImprover',
    'freelancerTimelineBuilder',
    'interviewLabQuestionBank',
    'interviewLabAnswerCritique',
    'interviewLabFollowUp',
    'interviewLabDebrief',
    'freelancerCareerAdvisor',
    'careerSkillGapAnalysis',
    'careerLearningRoadmap',
    'careerResumeReview',
    'careerPortfolioReview',
    'careerMarketInsights',
  ]),
  customer: new Set([
    'customerServiceRequestDraft',
    'customerProjectBriefBuilder',
    'customerRequirementClarifier',
    'customerFreelancerComparison',
    'customerMessageDraft',
    'customerRevisionRequestDraft',
    'customerRefundRequestDraft',
    'customerDisputeExplanationDraft',
    'customerDeliveryAcceptanceChecklist',
    'customerOrderScopeReview',
    'studentTutorExplain',
    'studentPracticeQuestions',
  ]),
  guest: new Set(['generalAppHelp', 'explainFeature', 'rewriteText', 'summarizeText']),
};

const common = new Set(['generalAppHelp', 'explainFeature', 'rewriteText', 'summarizeText']);

// Roles that may be unioned onto the bound role as a capability. Admin tiers are
// deliberately absent: they must come from primaryRole or the admins collection.
const unionableCapabilities = new Set(['freelancer', 'customer']);

function authRequired() {
  // Production-safe default: auth ON unless explicitly disabled for local debugging.
  return String(process.env.REQUIRE_AUTH ?? 'true').toLowerCase() !== 'false';
}

/**
 * `capabilities` must originate from verified data only (custom claims or the
 * Firestore user document) — never from the request body.
 */
export function authorizeTask(request, capabilities = []) {
  const role = normalizeRole(request.role) || 'guest';
  const accountType = normalizeRole(request.accountType);
  const granted = [allowByRole[role] || allowByRole.guest];
  if (accountType === 'customer') {
    granted.push(allowByRole.customer);
  }
  for (const capability of capabilities) {
    const normalized = normalizeRole(capability);
    if (!unionableCapabilities.has(normalized)) continue;
    granted.push(allowByRole[normalized]);
  }
  if (
    common.has(request.taskType) ||
    granted.some((set) => set.has(request.taskType))
  ) {
    return { allowed: true };
  }
  return {
    allowed: false,
    reason: 'You do not have access to this AI feature with your current role.',
  };
}

export async function verifyFirebaseTokenIfRequired(req) {
  if (!authRequired()) {
    return { allowed: true, userId: null, tokenPayload: null, authRequired: false };
  }

  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!token) {
    return { allowed: false, reason: 'Authorization token required.' };
  }

  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    return {
      allowed: false,
      reason: 'FIREBASE_PROJECT_ID is required when REQUIRE_AUTH=true.',
    };
  }

  try {
    const { verifyFirebaseIdToken } = await import('./firebaseTokenVerifier.js');
    const payload = await verifyFirebaseIdToken(token, projectId);
    return {
      allowed: true,
      userId: payload.sub || payload.user_id || null,
      email: payload.email || null,
      tokenPayload: payload,
      authRequired: true,
    };
  } catch {
    return { allowed: false, reason: 'Invalid or expired authorization token.' };
  }
}

/**
 * Binds AI role to Firebase identity — never trust client-supplied role when auth is on.
 * Order: custom claims → users/{uid} → admins/{uid} → guest.
 */
export async function bindRoleFromAuth(authCheck, request) {
  if (!authCheck?.authRequired || !authCheck.userId) {
    return {
      role: normalizeRole(request.role) || 'guest',
      accountType: normalizeRole(request.accountType) || '',
      capabilities: [],
      source: 'request-body-dev',
    };
  }

  const claims = authCheck.tokenPayload || {};
  const claimRole = normalizeRole(
    claims.role || claims.primaryRole || claims.user_role,
  );
  const claimAccountType = normalizeRole(claims.accountType);
  if (claimRole && (allowByRole[claimRole] || claimRole === 'guest')) {
    return {
      role: claimRole,
      accountType: claimAccountType || claimRole,
      capabilities: capabilitiesFrom(claims),
      source: 'token-claims',
    };
  }

  try {
    const { getFirestore } = await import('../payfast/firebase.js');
    const db = getFirestore();
    const userSnap = await db.collection('users').doc(authCheck.userId).get();
    if (userSnap.exists) {
      const data = userSnap.data() || {};
      let role = normalizeRole(data.primaryRole || data.role);
      if (!role && Array.isArray(data.roles) && data.roles.length) {
        role = normalizeRole(data.roles[0]);
      }
      const accountType = normalizeRole(data.accountType);
      // Customer accounts carry no primaryRole — accountType is their role.
      if (!role && accountType === 'customer') {
        role = 'customer';
      }
      const capabilities = capabilitiesFrom(data);
      if (role || capabilities.length) {
        return {
          role: role || 'guest',
          accountType: accountType || role,
          capabilities,
          source: 'users-collection',
        };
      }
    }

    const adminSnap = await db.collection('admins').doc(authCheck.userId).get();
    if (adminSnap.exists) {
      const data = adminSnap.data() || {};
      const raw =
        data.primaryRole ||
        data.role ||
        data.accessLevel ||
        data.permissionLevel ||
        (data.isSuperAdmin ? 'superadmin' : 'admin');
      const role = normalizeRole(raw);
      if (role) {
        return {
          role: role === 'super_admin' ? 'superadmin' : role,
          accountType: 'admin',
          capabilities: [],
          source: 'admins-collection',
        };
      }
    }
  } catch (error) {
    console.warn(
      '[AI Auth] Unable to resolve role from Firestore:',
      error instanceof Error ? error.message : error,
    );
  }

  // Local/dev only: when Admin SDK credentials are missing, allow the
  // authenticated client's declared role so AI features stay testable.
  // Production must set FIREBASE_SERVICE_ACCOUNT_PATH (or GOOGLE_APPLICATION_CREDENTIALS).
  const clientRole = normalizeRole(request.role);
  const allowDevFallback =
    String(process.env.DEV_ALLOW_LOCALHOST || '').toLowerCase() === 'true' ||
    String(process.env.DEV_ALLOW_ROLE_FALLBACK || '').toLowerCase() === 'true';
  if (allowDevFallback && clientRole && allowByRole[clientRole]) {
    console.warn(
      `[AI Auth] Using verified-token client role fallback="${clientRole}" ` +
        '(configure FIREBASE_SERVICE_ACCOUNT_PATH for production role binding).',
    );
    return {
      role: clientRole,
      accountType: normalizeRole(request.accountType) || clientRole,
      capabilities: [],
      source: 'dev-client-role-fallback',
    };
  }

  return {
    role: 'guest',
    accountType: '',
    capabilities: [],
    source: 'fallback-guest',
  };
}

/**
 * Extra AI capabilities a verified user holds beyond their primary role, e.g. a
 * student who unlocked freelancer mode via the student→freelancer bridge.
 */
function capabilitiesFrom(data) {
  const capabilities = new Set();
  if (isTrue(data.freelancerUnlocked)) {
    capabilities.add('freelancer');
  }
  if (Array.isArray(data.roles)) {
    for (const value of data.roles) {
      const role = normalizeRole(value);
      if (unionableCapabilities.has(role)) capabilities.add(role);
    }
  }
  if (normalizeRole(data.accountType) === 'customer') {
    capabilities.add('customer');
  }
  return [...capabilities];
}

function isTrue(value) {
  return value === true || String(value).toLowerCase() === 'true';
}

function normalizeRole(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
}
