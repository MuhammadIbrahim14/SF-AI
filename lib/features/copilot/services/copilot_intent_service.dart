import '../../../app/router/route_names.dart';
import '../models/copilot_intent_model.dart';
import 'copilot_route_catalog.dart';

class CopilotIntentService {
  const CopilotIntentService();

  /// Zero-cost local parser. A future backend AI parser can replace this
  /// method without changing provider/UI contracts.
  CopilotIntentModel detectIntent(
    String input, {
    String? role,
    String? accountType,
  }) {
    final text = _normalize(input);
    if (text.isEmpty) return _fallback(input);

    if (_hasAny(text, [
      'split settlement open',
      'split settlement dikhao',
      'split settlement page',
      'release settlement open',
      'release escrow page',
    ])) {
      return _guide(CopilotIntentType.guideOpenDispute, input);
    }

    final sensitive = _sensitiveIntent(text, input);
    if (sensitive != null) return sensitive;

    final guided = _guidedIntent(
      text,
      input,
      role: role,
      accountType: accountType,
    );
    if (guided != null) return guided;

    final help = _helpIntent(text, input);
    if (help != null) return help;

    final data = _dataIntent(text, input, role: role, accountType: accountType);
    if (data != null) return data;

    final ai = _aiIntent(text, input, role: role, accountType: accountType);
    if (ai != null) return ai;

    final catalogMatch = CopilotRouteCatalog.bestMatch(
      query: input,
      role: role,
      accountType: accountType,
    );
    if (catalogMatch != null && catalogMatch.score >= 50) {
      final destination = catalogMatch.destination;
      return CopilotIntentModel(
        type: CopilotIntentType.openDestination,
        rawText: input,
        confidence: (catalogMatch.score / 120).clamp(0.35, 0.98).toDouble(),
        targetRoute: destination.isAvailable ? destination.path : null,
        requiredRole: destination.allowedRoles.isNotEmpty
            ? destination.allowedRoles.first
            : null,
        actionLevel: destination.actionLevel,
        destinationId: destination.id,
        destinationTitle: destination.title,
        matchedKeyword: catalogMatch.matchedKeyword,
        category: destination.category,
        suggestions: CopilotRouteCatalog.suggestionsForRole(
          role: role,
          accountType: accountType,
        ),
      );
    }

    final navigation = _navigationIntent(text, input);
    if (navigation != null) return navigation;

    return _fallback(
      input,
      suggestions: CopilotRouteCatalog.suggestionsForRole(
        role: role,
        accountType: accountType,
      ),
    );
  }

  CopilotIntentModel? _navigationIntent(String text, String rawText) {
    if (_hasAny(text, ['dashboard', 'home screen', 'main screen'])) {
      return _nav(CopilotIntentType.openDashboard, rawText);
    }
    if (_hasAny(text, ['wallet', 'balance', 'my wallet', 'paise'])) {
      return _nav(CopilotIntentType.openWallet, rawText);
    }
    if (_hasAny(text, ['my orders', 'orders', 'order list'])) {
      return _nav(CopilotIntentType.openOrders, rawText);
    }
    if (_hasAny(text, ['customer orders', 'client orders'])) {
      return _nav(CopilotIntentType.openCustomerOrders, rawText);
    }
    if (_hasAny(text, ['freelancer orders', 'seller orders'])) {
      return _nav(CopilotIntentType.openFreelancerOrders, rawText);
    }
    if (_hasAny(text, ['service request', 'project request', 'requests'])) {
      return _nav(CopilotIntentType.openServiceRequests, rawText);
    }
    if (_hasAny(text, ['resolution', 'dispute center', 'case center'])) {
      return _nav(CopilotIntentType.openResolutionCenter, rawText);
    }
    if (_hasAny(text, ['admin resolution', 'resolution desk'])) {
      return _nav(
        CopilotIntentType.openAdminResolutionDesk,
        rawText,
        targetRoute: RoutePaths.adminResolutionDesk,
        requiredRole: 'admin',
      );
    }
    if (_hasAny(text, ['payout', 'withdraw', 'withdrawal'])) {
      return _nav(CopilotIntentType.openPayouts, rawText);
    }
    if (_hasAny(text, ['support', 'contact', 'help center', 'ticket'])) {
      return _nav(
        CopilotIntentType.openSupport,
        rawText,
        targetRoute: RoutePaths.contactUs,
      );
    }
    if (_hasAny(text, ['privacy', 'privacy policy'])) {
      return _nav(
        CopilotIntentType.openPrivacyPolicy,
        rawText,
        targetRoute: RoutePaths.privacyPolicy,
      );
    }
    if (_hasAny(text, ['terms', 'terms of service', 'legal terms'])) {
      return _nav(
        CopilotIntentType.openTerms,
        rawText,
        targetRoute: RoutePaths.termsOfService,
      );
    }
    if (_hasAny(text, ['profile', 'my profile'])) {
      return _nav(CopilotIntentType.openProfile, rawText);
    }
    if (_hasAny(text, ['settings', 'security', 'account settings'])) {
      return _nav(CopilotIntentType.openSettings, rawText);
    }
    return null;
  }

  CopilotIntentModel? _dataIntent(
    String text,
    String rawText, {
    String? role,
    String? accountType,
  }) {
    if (!_looksLikeDataQuestion(text)) return null;

    final normalizedRole = _normalizeRole(role);
    final normalizedAccount = _normalizeRole(accountType);
    final isCustomer = normalizedAccount == 'customer';
    final isFreelancer = normalizedRole == 'freelancer';
    final isTeacher = normalizedRole == 'teacher';
    final isCompany = normalizedRole == 'company';
    final isAdmin = normalizedRole == 'admin' || normalizedRole == 'superadmin';

    if (_hasAny(text, ['my role', 'mera role', 'role kya', 'account type'])) {
      return _data(CopilotIntentType.getMyRole, rawText);
    }
    if (_hasAny(text, [
      'profile summary',
      'profile complete',
      'profile kitna',
    ])) {
      return _data(CopilotIntentType.getProfileSummary, rawText);
    }
    if (_hasAny(text, ['dashboard summary', 'workspace summary'])) {
      return _data(CopilotIntentType.getDashboardSummary, rawText);
    }
    if (_hasAny(text, [
      'backend status',
      'settlement backend',
      'release split status',
    ])) {
      return _data(CopilotIntentType.getSettlementBackendStatus, rawText);
    }
    if (_hasAny(text, ['wallet', 'balance', 'paise', 'amount'])) {
      return _data(CopilotIntentType.getWalletBalance, rawText);
    }
    if (_hasAny(text, ['payout', 'withdraw', 'withdrawal'])) {
      return _data(
        isAdmin
            ? CopilotIntentType.getAdminPayoutSummary
            : CopilotIntentType.getFreelancerPayoutSummary,
        rawText,
      );
    }
    if (_hasAny(text, [
      'resolution',
      'dispute',
      'refund',
      'case',
      'revision',
    ])) {
      return _data(
        isAdmin
            ? CopilotIntentType.getAdminResolutionSummary
            : isFreelancer
            ? CopilotIntentType.getFreelancerResolutionSummary
            : CopilotIntentType.getCustomerResolutionSummary,
        rawText,
      );
    }
    if (_hasAny(text, ['service request', 'project request', 'requests'])) {
      return _data(
        isFreelancer
            ? CopilotIntentType.getFreelancerServiceRequestSummary
            : CopilotIntentType.getCustomerOrderSummary,
        rawText,
      );
    }
    if (_hasAny(text, ['orders', 'order', 'active order', 'pending order'])) {
      return _data(
        isFreelancer
            ? CopilotIntentType.getFreelancerOrderSummary
            : CopilotIntentType.getCustomerOrderSummary,
        rawText,
      );
    }
    if (isTeacher && _hasAny(text, ['course', 'courses', 'my courses'])) {
      return _data(CopilotIntentType.getTeacherCourseSummary, rawText);
    }
    if (isTeacher && _hasAny(text, ['certificate', 'certificates'])) {
      return _data(CopilotIntentType.getTeacherCertificateSummary, rawText);
    }
    if (isTeacher && _hasAny(text, ['student progress', 'at risk'])) {
      return _data(CopilotIntentType.getTeacherStudentProgressSummary, rawText);
    }
    if (isCompany && _hasAny(text, ['jobs', 'job posts', 'manage jobs'])) {
      return _data(CopilotIntentType.getCompanyJobSummary, rawText);
    }
    if (isCompany && _hasAny(text, ['applications', 'candidates'])) {
      return _data(CopilotIntentType.getCompanyApplicationsSummary, rawText);
    }
    if (isCompany && _hasAny(text, ['hiring', 'pipeline', 'interview'])) {
      return _data(CopilotIntentType.getCompanyHiringSummary, rawText);
    }
    if (isCustomer && _hasAny(text, ['client orders', 'my orders'])) {
      return _data(CopilotIntentType.getCustomerOrderSummary, rawText);
    }
    return null;
  }

  CopilotIntentModel? _helpIntent(String text, String rawText) {
    if (_hasAny(text, ['escrow kya', 'escrow explain', 'what is escrow'])) {
      return _info(CopilotIntentType.explainEscrow, rawText);
    }
    if (_hasAny(text, ['refund kya', 'refund explain', 'refund kaise'])) {
      return _info(CopilotIntentType.explainRefund, rawText);
    }
    if (_hasAny(text, ['dispute kya', 'dispute explain', 'case kaise'])) {
      return _info(CopilotIntentType.explainDispute, rawText);
    }
    if (_hasAny(text, ['payout kya', 'withdrawal explain'])) {
      return _info(CopilotIntentType.explainPayout, rawText);
    }
    if (_hasAny(text, ['delivery flow', 'order flow', 'kaam submit'])) {
      return _info(CopilotIntentType.explainDeliveryFlow, rawText);
    }
    if (_hasAny(text, [
      'backend pending',
      'release disabled',
      'split disabled',
    ])) {
      return _info(CopilotIntentType.explainSettlementPaused, rawText);
    }
    if (_hasAny(text, ['skillforge law', 'law engine', 'resolution law'])) {
      return _info(CopilotIntentType.explainSkillForgeLaw, rawText);
    }
    return null;
  }

  CopilotIntentModel? _aiIntent(
    String text,
    String rawText, {
    String? role,
    String? accountType,
  }) {
    final normalizedRole = _normalizeRole(role);
    final normalizedAccount = _normalizeRole(accountType);
    final isTeacher = normalizedRole == 'teacher';
    final isStudent = normalizedRole == 'student';
    final isCompany = normalizedRole == 'company';
    final isAdmin = normalizedRole == 'admin' || normalizedRole == 'superadmin';
    final isFreelancer = normalizedRole == 'freelancer';
    final isCustomer = normalizedAccount == 'customer';

    if (isTeacher &&
        _hasAny(text, [
          'course banao',
          'generate course',
          'course generate',
          'course generate karo',
          'ai se course generate',
          'ai course builder',
          'course ai',
        ])) {
      return null;
    }
    if (isTeacher &&
        _hasAny(text, ['course outline generate', 'course outline'])) {
      return _ai(
        CopilotIntentType.teacherCourseOutline,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }
    if (isTeacher &&
        _hasAny(text, ['lesson plan', 'lesson banao', 'lesson generate'])) {
      return _ai(
        CopilotIntentType.teacherLessonBuilder,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }
    if (isTeacher &&
        _hasAny(text, [
          'quiz generate',
          'quiz banao',
          'mcq banao',
          'mcqs banao',
          'mcq generate',
          'mcqs generate',
        ])) {
      return _ai(
        CopilotIntentType.teacherQuizBuilder,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }
    if (isTeacher &&
        _hasAny(text, ['assignment banao', 'assignment generate'])) {
      return _ai(
        CopilotIntentType.teacherAssignmentBuilder,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }
    if (isTeacher &&
        _hasAny(text, ['grand test banao', 'grand test generate'])) {
      return _ai(
        CopilotIntentType.teacherGrandTestBuilder,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }
    if (isTeacher && _hasAny(text, ['rubric banao', 'rubric generate'])) {
      return _ai(
        CopilotIntentType.teacherRubricGenerator,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }
    if (isTeacher &&
        _hasAny(text, [
          'course improve',
          'improve course text',
          'content improve',
          'improve content',
        ])) {
      return _ai(
        CopilotIntentType.teacherImproveContent,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }

    if ((isStudent || isCustomer) &&
        _hasAny(text, [
          'mujhe samjhao',
          'explain this topic',
          'samjhao easy',
          'easy words',
        ])) {
      return _ai(
        CopilotIntentType.studentTutorExplain,
        rawText,
        CopilotActionLevel.aiExplain,
      );
    }
    if ((isStudent || isCustomer) &&
        _hasAny(text, ['practice questions', 'questions do', 'practice do'])) {
      return _ai(
        CopilotIntentType.studentPracticeQuestions,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }
    if ((isStudent || isCustomer) &&
        _hasAny(text, ['lesson summary', 'summary banao'])) {
      return _ai(
        CopilotIntentType.studentLessonSummary,
        rawText,
        CopilotActionLevel.aiSummarize,
      );
    }
    if ((isStudent || isCustomer) &&
        _hasAny(text, ['hint do', 'hint chahiye'])) {
      return _ai(
        CopilotIntentType.studentHint,
        rawText,
        CopilotActionLevel.aiExplain,
      );
    }
    if ((isStudent || isCustomer) &&
        _hasAny(text, ['code samjhao', 'code explain'])) {
      return _ai(
        CopilotIntentType.studentCodeExplanation,
        rawText,
        CopilotActionLevel.aiExplain,
      );
    }

    if (isCompany &&
        _hasAny(text, [
          'job post banao',
          'job post generate',
          'job description banao',
        ])) {
      return _ai(
        CopilotIntentType.companyJobPostGenerator,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }
    if (isCompany &&
        _hasAny(text, ['interview questions', 'questions banao'])) {
      return _ai(
        CopilotIntentType.companyInterviewQuestions,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }
    if (isCompany && _hasAny(text, ['candidate rubric', 'rubric banao'])) {
      return _ai(
        CopilotIntentType.companyCandidateRubric,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }
    if (isCompany &&
        _hasAny(text, ['application summarize', 'application summary'])) {
      return _ai(
        CopilotIntentType.companyApplicationSummary,
        rawText,
        CopilotActionLevel.aiSummarize,
      );
    }
    if (isCompany &&
        _hasAny(text, ['skill match explain', 'match explanation'])) {
      return _ai(
        CopilotIntentType.companySkillMatchExplanation,
        rawText,
        CopilotActionLevel.aiExplain,
      );
    }

    if (isAdmin && _hasAny(text, ['case summarize', 'resolution summarize'])) {
      return _ai(
        CopilotIntentType.adminResolutionSummary,
        rawText,
        CopilotActionLevel.aiSummarize,
      );
    }
    if (isAdmin && _hasAny(text, ['evidence summarize', 'evidence summary'])) {
      return _ai(
        CopilotIntentType.adminEvidenceSummary,
        rawText,
        CopilotActionLevel.aiSummarize,
      );
    }
    if (isAdmin && _hasAny(text, ['timeline banao', 'timeline summary'])) {
      return _ai(
        CopilotIntentType.adminTimelineSummary,
        rawText,
        CopilotActionLevel.aiSummarize,
      );
    }
    if (isAdmin && _hasAny(text, ['risk flags', 'risk batao'])) {
      return _ai(
        CopilotIntentType.adminRiskFlags,
        rawText,
        CopilotActionLevel.aiRecommend,
      );
    }
    if (isAdmin &&
        _hasAny(text, ['law recommendation', 'law recommendation do'])) {
      return _ai(
        CopilotIntentType.adminLawRecommendation,
        rawText,
        CopilotActionLevel.aiRecommend,
      );
    }

    if (isFreelancer && _hasAny(text, ['proposal banao', 'proposal draft'])) {
      return _ai(
        CopilotIntentType.freelancerProposalDraft,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }
    if (isFreelancer &&
        _hasAny(text, ['delivery message', 'delivery message banao', 'delivery note'])) {
      return _ai(
        CopilotIntentType.freelancerDeliveryNoteBuilder,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }
    if (isFreelancer && _hasAny(text, ['profile improve', 'profile better'])) {
      return _ai(
        CopilotIntentType.freelancerProfileImprover,
        rawText,
        CopilotActionLevel.aiRecommend,
      );
    }
    if (isFreelancer &&
        _hasAny(text, [
          'service package improve',
          'package improve',
          'service listing improve',
          'improve listing',
        ])) {
      return _ai(
        CopilotIntentType.freelancerServiceListingImprover,
        rawText,
        CopilotActionLevel.aiRecommend,
      );
    }

    if (isCustomer &&
        _hasAny(text, ['refund reason banao', 'refund reason draft', 'refund request draft'])) {
      return _ai(
        CopilotIntentType.customerRefundRequestDraft,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }
    if (isCustomer &&
        _hasAny(text, [
          'dispute summary banao',
          'dispute summary draft',
          'dispute explanation',
        ])) {
      return _ai(
        CopilotIntentType.customerDisputeExplanationDraft,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }
    if (isCustomer &&
        _hasAny(text, ['service request draft', 'service request banao'])) {
      return _ai(
        CopilotIntentType.customerServiceRequestDraft,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }
    if (isCustomer &&
        _hasAny(text, [
          'support message banao',
          'support message draft',
          'customer message draft',
        ])) {
      return _ai(
        CopilotIntentType.customerMessageDraft,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }

    if (_hasAny(text, ['rewrite this', 'rewrite karo'])) {
      return _ai(
        CopilotIntentType.rewriteText,
        rawText,
        CopilotActionLevel.aiDraft,
      );
    }
    if (_hasAny(text, ['summarize this', 'summarize karo'])) {
      return _ai(
        CopilotIntentType.summarizeText,
        rawText,
        CopilotActionLevel.aiSummarize,
      );
    }
    if (_hasAny(text, ['feature explain', 'explain feature'])) {
      return _ai(
        CopilotIntentType.explainFeature,
        rawText,
        CopilotActionLevel.aiExplain,
      );
    }
    if (_hasAny(text, ['ai help', 'general help'])) {
      return _ai(
        CopilotIntentType.generalAppHelp,
        rawText,
        CopilotActionLevel.aiExplain,
      );
    }
    return null;
  }

  CopilotIntentModel? _guidedIntent(
    String text,
    String rawText, {
    String? role,
    String? accountType,
  }) {
    final normalizedRole = _normalizeRole(role);
    final normalizedAccount = _normalizeRole(accountType);
    final isAdmin = normalizedRole == 'admin' || normalizedRole == 'superadmin';
    final isTeacher = normalizedRole == 'teacher';
    final isCompany = normalizedRole == 'company';
    final isFreelancer = normalizedRole == 'freelancer';
    final isCustomer = normalizedAccount == 'customer';

    if (_hasAny(text, [
      'request refund',
      'refund request',
      'refund chahiye',
      'refund request create',
      'refund mangni',
      'refund mangna',
      'refund ke liye case',
      'money wapis',
      'paisa refund',
      'paise refund',
      'refund karwana',
    ])) {
      return _guide(CopilotIntentType.guideRefundRequest, rawText);
    }
    if (_hasAny(text, [
      'open dispute',
      'raise dispute',
      'case open',
      'dispute open',
      'case banana',
      'masla report',
      'issue raise',
      'freelancer ke against dispute',
      'client ke against dispute',
    ])) {
      return _guide(CopilotIntentType.guideOpenDispute, rawText);
    }
    if (_hasAny(text, [
      'revision request',
      'request revision',
      'revision chahiye',
      'change chahiye',
      'changes chahiye',
      'work revise',
      'revise karwana',
      'delivery me changes',
    ])) {
      return _guide(CopilotIntentType.guideRequestRevision, rawText);
    }
    if (_hasAny(text, [
      'submit delivery',
      'delivery submit',
      'delivery upload',
      'deliver work',
      'work submit',
      'project deliver',
      'client ko files',
      'files bhejni',
      'submit work',
    ])) {
      return _guide(CopilotIntentType.guideSubmitDelivery, rawText);
    }
    if (_hasAny(text, [
      'add evidence',
      'evidence add',
      'upload proof',
      'proof upload',
      'proof add',
      'proof dena',
      'screenshot add',
      'admin ne evidence',
    ])) {
      return _guide(CopilotIntentType.guideAddEvidence, rawText);
    }
    if (_hasAny(text, [
      'request payout',
      'payout request',
      'payout request create',
      'withdraw request',
      'payout mangni',
      'earning nikalni',
      'paise withdraw karne',
    ])) {
      return _guide(CopilotIntentType.guidePayoutRequest, rawText);
    }
    if (_hasAny(text, ['wallet top up', 'top up', 'balance add'])) {
      return _guide(CopilotIntentType.guideOpenWalletTopUp, rawText);
    }
    if (_hasAny(text, [
      'service request create',
      'freelancer ko request',
      'service order karni',
      'custom request',
      'request bhejni',
    ])) {
      return _guide(CopilotIntentType.guideCreateServiceRequest, rawText);
    }
    if (_hasAny(text, [
      'support ticket',
      'contact support',
      'help chahiye',
      'issue report',
      'complaint',
      'support chahiye',
    ])) {
      return _guide(CopilotIntentType.guideContactSupport, rawText);
    }
    if (isFreelancer &&
        _hasAny(text, [
          'service requests manage',
          'manage service requests',
          'client requests manage',
        ])) {
      return _guide(CopilotIntentType.guideManageServiceRequests, rawText);
    }
    if (isFreelancer &&
        _hasAny(text, [
          'update service package',
          'service packages',
          'edit service',
          'manage services',
        ])) {
      return _guide(CopilotIntentType.guideUpdateServicePackages, rawText);
    }
    if (isTeacher &&
        _hasAny(text, [
          'course create',
          'create course',
          'new course',
          'course banana',
          'course add',
        ])) {
      return _guide(CopilotIntentType.guideCreateCourse, rawText);
    }
    if (isTeacher &&
        _hasAny(text, [
          'course manage',
          'manage course',
          'my courses manage',
        ])) {
      return _guide(CopilotIntentType.guideManageCourse, rawText);
    }
    if (isTeacher &&
        _hasAny(text, [
          'certificate manage',
          'certificate create',
          'issue certificate',
        ])) {
      return _guide(CopilotIntentType.guideCreateCertificate, rawText);
    }
    if (isCompany &&
        _hasAny(text, [
          'job post',
          'post job',
          'create job',
          'new job',
          'job create',
        ])) {
      return _guide(CopilotIntentType.guidePostJob, rawText);
    }
    if (isCompany &&
        _hasAny(text, [
          'review applications',
          'applications review',
          'candidate review',
          'hiring review',
        ])) {
      return _guide(CopilotIntentType.guideReviewApplications, rawText);
    }
    if (isAdmin &&
        _hasAny(text, [
          'case review',
          'review case',
          'resolution review',
          'case dekhna',
        ])) {
      return _guide(CopilotIntentType.guideReviewResolutionCase, rawText);
    }
    if (isAdmin &&
        _hasAny(text, [
          'evidence request',
          'request evidence',
          'evidence mangni',
          'evidence request karni',
        ])) {
      return _guide(CopilotIntentType.guideRequestEvidence, rawText);
    }
    if (isAdmin &&
        _hasAny(text, [
          'payout approve',
          'approve payout',
          'payout review',
          'review payout',
        ])) {
      return _guide(CopilotIntentType.guideReviewPayout, rawText);
    }
    if (isAdmin &&
        _hasAny(text, [
          'law manage',
          'manage law',
          'legal manage',
          'policy manage',
        ])) {
      return _guide(CopilotIntentType.guideManageLaw, rawText);
    }
    if (isCustomer && _hasAny(text, ['order pay karna', 'pay order help'])) {
      return _guide(CopilotIntentType.guidePayOrder, rawText);
    }
    return null;
  }

  CopilotIntentModel? _sensitiveIntent(String text, String rawText) {
    if (_hasAny(text, [
      'pay with wallet',
      'pay order',
      'confirm payment',
      'process payment',
      'escrow fund',
    ])) {
      return _sensitive(CopilotIntentType.payWithWallet, rawText);
    }
    if (_hasAny(text, ['release escrow', 'release to freelancer'])) {
      return _sensitive(CopilotIntentType.releaseEscrow, rawText);
    }
    if (_hasAny(text, ['split settlement', 'split release'])) {
      return _sensitive(CopilotIntentType.splitSettlement, rawText);
    }
    if (_hasAny(text, ['refund client', 'send refund', 'process refund'])) {
      return _sensitive(CopilotIntentType.refundClient, rawText);
    }
    if (_hasAny(text, ['mark payout paid', 'process payout'])) {
      return _sensitive(CopilotIntentType.markPayoutPaid, rawText);
    }
    if (_hasAny(text, ['withdraw funds', 'withdraw now', 'withdraw payout'])) {
      return _sensitive(CopilotIntentType.withdrawPayout, rawText);
    }
    if (_hasAny(text, ['resolve case', 'case resolve', 'settle case'])) {
      return _sensitive(CopilotIntentType.resolveCase, rawText);
    }
    if (_hasAny(text, ['delete user', 'delete account', 'delete data'])) {
      return _sensitive(CopilotIntentType.deleteData, rawText);
    }
    if (_hasAny(text, ['ban user', 'block user', 'suspend user'])) {
      return _sensitive(CopilotIntentType.banUser, rawText);
    }
    return null;
  }

  CopilotIntentModel _nav(
    String type,
    String rawText, {
    String? targetRoute,
    String? requiredRole,
  }) {
    return CopilotIntentModel(
      type: type,
      rawText: rawText,
      confidence: 0.82,
      targetRoute: targetRoute,
      requiredRole: requiredRole,
      actionLevel: CopilotActionLevel.safeNavigation,
    );
  }

  CopilotIntentModel _info(String type, String rawText) {
    return CopilotIntentModel(
      type: type,
      rawText: rawText,
      confidence: 0.78,
      actionLevel: CopilotActionLevel.explanation,
    );
  }

  CopilotIntentModel _guide(String type, String rawText) {
    return CopilotIntentModel(
      type: type,
      rawText: rawText,
      confidence: 0.76,
      actionLevel: CopilotActionLevel.guidedAction,
    );
  }

  CopilotIntentModel _data(String type, String rawText) {
    return CopilotIntentModel(
      type: type,
      rawText: rawText,
      confidence: 0.8,
      actionLevel: CopilotActionLevel.dataRead,
    );
  }

  CopilotIntentModel _ai(String type, String rawText, String actionLevel) {
    return CopilotIntentModel(
      type: type,
      rawText: rawText,
      confidence: 0.72,
      actionLevel: actionLevel,
    );
  }

  CopilotIntentModel _sensitive(String type, String rawText) {
    return CopilotIntentModel(
      type: type,
      rawText: rawText,
      confidence: 0.9,
      actionLevel: CopilotActionLevel.sensitive,
      needsConfirmation: true,
    );
  }

  CopilotIntentModel _fallback(
    String rawText, {
    List<String> suggestions = const <String>[],
  }) {
    return CopilotIntentModel(
      type: CopilotIntentType.unknown,
      rawText: rawText,
      confidence: 0,
      actionLevel: CopilotActionLevel.unsupported,
      suggestions: suggestions,
    );
  }
}

bool _hasAny(String text, List<String> patterns) {
  return patterns.any((pattern) => text.contains(pattern));
}

bool _looksLikeDataQuestion(String text) {
  return _hasAny(text, [
    'kitna',
    'kitni',
    'kya hai',
    'status',
    'summary',
    'total',
    'count',
    'balance',
    'pending',
    'active',
    'open',
    'how many',
    'how much',
    'show me',
    'tell me',
    'batao',
  ]);
}

String _normalizeRole(String? value) {
  return (value ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '')
      .trim();
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
