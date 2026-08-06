import '../../copilot/models/copilot_ai_response_model.dart';

class MarketplaceAiTaskType {
  const MarketplaceAiTaskType._();

  static const freelancerServiceListingBuilder =
      'freelancerServiceListingBuilder';
  static const freelancerServiceListingImprover =
      'freelancerServiceListingImprover';
  static const freelancerProposalDraft = 'freelancerProposalDraft';
  static const freelancerScopeClarifier = 'freelancerScopeClarifier';
  static const freelancerDeliveryNoteBuilder = 'freelancerDeliveryNoteBuilder';
  static const freelancerClientUpdateDraft = 'freelancerClientUpdateDraft';
  static const freelancerRevisionResponseDraft =
      'freelancerRevisionResponseDraft';
  static const freelancerDisputeEvidenceSummary =
      'freelancerDisputeEvidenceSummary';
  static const freelancerProfileImprover = 'freelancerProfileImprover';
  static const freelancerTimelineBuilder = 'freelancerTimelineBuilder';

  static const customerServiceRequestDraft = 'customerServiceRequestDraft';
  static const customerProjectBriefBuilder = 'customerProjectBriefBuilder';
  static const customerRequirementClarifier = 'customerRequirementClarifier';
  static const customerFreelancerComparison = 'customerFreelancerComparison';
  static const customerMessageDraft = 'customerMessageDraft';
  static const customerRevisionRequestDraft = 'customerRevisionRequestDraft';
  static const customerRefundRequestDraft = 'customerRefundRequestDraft';
  static const customerDisputeExplanationDraft =
      'customerDisputeExplanationDraft';
  static const customerDeliveryAcceptanceChecklist =
      'customerDeliveryAcceptanceChecklist';
  static const customerOrderScopeReview = 'customerOrderScopeReview';

  static bool isServiceListingTask(String taskType) {
    return taskType == freelancerServiceListingBuilder ||
        taskType == freelancerServiceListingImprover;
  }

  static bool isServiceRequestTask(String taskType) {
    return taskType == customerServiceRequestDraft ||
        taskType == customerProjectBriefBuilder ||
        taskType == customerRequirementClarifier;
  }

  static bool isProposalTask(String taskType) =>
      taskType == freelancerProposalDraft;

  static bool isDeliveryNoteTask(String taskType) =>
      taskType == freelancerDeliveryNoteBuilder;

  static bool isMessageDraftTask(String taskType) {
    return taskType == customerMessageDraft ||
        taskType == freelancerClientUpdateDraft;
  }

  static bool isResolutionNotesTask(String taskType) {
    return taskType == customerRevisionRequestDraft ||
        taskType == customerRefundRequestDraft ||
        taskType == customerDisputeExplanationDraft ||
        taskType == freelancerRevisionResponseDraft ||
        taskType == freelancerDisputeEvidenceSummary;
  }

  static bool isChecklistTask(String taskType) =>
      taskType == customerDeliveryAcceptanceChecklist;

  static bool isComparisonTask(String taskType) =>
      taskType == customerFreelancerComparison;

  static bool isScopeTask(String taskType) {
    return taskType == freelancerScopeClarifier ||
        taskType == customerOrderScopeReview;
  }

  static bool isProfileTask(String taskType) =>
      taskType == freelancerProfileImprover;

  static String label(String taskType) {
    return switch (taskType) {
      freelancerServiceListingBuilder => 'Service Listing Builder',
      freelancerServiceListingImprover => 'Service Listing Improver',
      freelancerProposalDraft => 'Proposal Draft',
      freelancerScopeClarifier => 'Scope Clarifier',
      freelancerDeliveryNoteBuilder => 'Delivery Note',
      freelancerClientUpdateDraft => 'Client Update',
      freelancerRevisionResponseDraft => 'Revision Response',
      freelancerDisputeEvidenceSummary => 'Evidence Summary',
      freelancerProfileImprover => 'Profile Improver',
      freelancerTimelineBuilder => 'Timeline Builder',
      customerServiceRequestDraft => 'Service Request Draft',
      customerProjectBriefBuilder => 'Project Brief',
      customerRequirementClarifier => 'Requirements Clarifier',
      customerFreelancerComparison => 'Compare Talent',
      customerMessageDraft => 'Message Draft',
      customerRevisionRequestDraft => 'Revision Request',
      customerRefundRequestDraft => 'Refund Request',
      customerDisputeExplanationDraft => 'Dispute Explanation',
      customerDeliveryAcceptanceChecklist => 'Acceptance Checklist',
      customerOrderScopeReview => 'Order Scope Review',
      _ => taskType,
    };
  }

  static String defaultPrompt({required bool improve}) {
    if (improve) {
      return 'Improve this service listing. Make title, descriptions, tags, '
          'pricing, packages, and delivery clearer and more client-ready. '
          'Do not invent portfolio URLs, certificates, or verified badges.';
    }
    return 'Build a complete marketplace service listing with title, short and '
        'full description, category, tags, pricing type, starting price, '
        'estimated delivery, currency, and packages. Do not invent portfolio '
        'URLs, certificates, or verified badges.';
  }

  static String structuredDataKeyHint(String taskType) {
    if (isServiceListingTask(taskType)) return 'serviceListing';
    if (isServiceRequestTask(taskType)) return 'serviceRequest';
    if (isProposalTask(taskType)) return 'proposal';
    if (isDeliveryNoteTask(taskType)) return 'deliveryNote';
    if (isMessageDraftTask(taskType)) return 'messageDraft';
    if (isChecklistTask(taskType)) return 'acceptanceChecklist';
    if (isComparisonTask(taskType)) return 'comparison';
    if (isScopeTask(taskType)) return 'scopeReview';
    if (isProfileTask(taskType)) return 'profile';
    if (taskType == customerRevisionRequestDraft) return 'revisionRequest';
    if (taskType == customerRefundRequestDraft) return 'refundRequest';
    if (taskType == customerDisputeExplanationDraft) return 'disputeExplanation';
    if (taskType == freelancerRevisionResponseDraft) return 'revisionResponse';
    if (taskType == freelancerDisputeEvidenceSummary) return 'evidenceSummary';
    if (taskType == freelancerTimelineBuilder) return 'timeline';
    return 'draft';
  }
}

/// Known evidence used to sanitize AI drafts before Apply.
class MarketplaceAiKnownEvidence {
  const MarketplaceAiKnownEvidence({
    this.knownSkills = const <String>[],
    this.knownCertificateIds = const <String>[],
    this.allowedUrls = const <String>[],
    this.knownPackageIds = const <String>[],
    this.platformSkillScore,
    this.clientName = '',
    this.clientEmail = '',
  });

  final List<String> knownSkills;
  final List<String> knownCertificateIds;
  final List<String> allowedUrls;
  final List<String> knownPackageIds;
  final double? platformSkillScore;
  final String clientName;
  final String clientEmail;

  Set<String> get _skillSet =>
      knownSkills.map((item) => item.trim().toLowerCase()).toSet();

  Set<String> get _certSet =>
      knownCertificateIds.map((item) => item.trim().toLowerCase()).toSet();

  Set<String> get _urlSet =>
      allowedUrls.map((item) => item.trim().toLowerCase()).toSet();

  Set<String> get _packageSet =>
      knownPackageIds.map((item) => item.trim().toLowerCase()).toSet();

  bool isKnownSkill(String value) =>
      _skillSet.contains(value.trim().toLowerCase());

  bool isKnownCertificateId(String value) =>
      _certSet.contains(value.trim().toLowerCase());

  bool isAllowedUrl(String value) =>
      _urlSet.contains(value.trim().toLowerCase());

  bool isKnownPackageId(String value) =>
      _packageSet.contains(value.trim().toLowerCase());
}

class MarketplaceServiceListingDraft {
  const MarketplaceServiceListingDraft({
    required this.raw,
    this.title = '',
    this.shortDescription = '',
    this.fullDescription = '',
    this.category = '',
    this.tags = const <String>[],
    this.pricingType = '',
    this.startingPrice,
    this.estimatedDelivery = '',
    this.currency = 'USD',
    this.packages = const <Map<String, dynamic>>[],
    this.coverImageUrl = '',
    this.galleryUrls = const <String>[],
    this.portfolioLinks = const <String>[],
    this.linkedSkills = const <String>[],
    this.linkedCertificateIds = const <String>[],
    this.skillScore,
    this.assumptions = const <String>[],
    this.missingInputs = const <String>[],
    this.manualReviewNotes = const <String>[],
  });

  final Map<String, dynamic> raw;
  final String title;
  final String shortDescription;
  final String fullDescription;
  final String category;
  final List<String> tags;
  final String pricingType;
  final double? startingPrice;
  final String estimatedDelivery;
  final String currency;
  final List<Map<String, dynamic>> packages;
  final String coverImageUrl;
  final List<String> galleryUrls;
  final List<String> portfolioLinks;
  final List<String> linkedSkills;
  final List<String> linkedCertificateIds;
  final double? skillScore;
  final List<String> assumptions;
  final List<String> missingInputs;
  final List<String> manualReviewNotes;

  bool get hasFillableContent =>
      title.trim().isNotEmpty ||
      shortDescription.trim().isNotEmpty ||
      fullDescription.trim().isNotEmpty ||
      category.trim().isNotEmpty ||
      tags.isNotEmpty ||
      packages.isNotEmpty ||
      (startingPrice != null && startingPrice! > 0);

  List<MapEntry<String, bool>> get fieldChecklist => [
    MapEntry('title', title.trim().isNotEmpty),
    MapEntry('shortDescription', shortDescription.trim().isNotEmpty),
    MapEntry('fullDescription', fullDescription.trim().isNotEmpty),
    MapEntry('category', category.trim().isNotEmpty),
    MapEntry('tags', tags.isNotEmpty),
    MapEntry('pricingType', pricingType.trim().isNotEmpty),
    MapEntry('startingPrice', startingPrice != null && startingPrice! > 0),
    MapEntry('estimatedDelivery', estimatedDelivery.trim().isNotEmpty),
    MapEntry('currency', currency.trim().isNotEmpty),
    MapEntry('packages', packages.isNotEmpty),
    MapEntry('coverImageUrl', coverImageUrl.trim().isNotEmpty),
    MapEntry('galleryUrls', galleryUrls.isNotEmpty),
    MapEntry('portfolioLinks', portfolioLinks.isNotEmpty),
    MapEntry('linkedSkills', linkedSkills.isNotEmpty),
    MapEntry('linkedCertificateIds', linkedCertificateIds.isNotEmpty),
    MapEntry('skillScore', skillScore != null && skillScore! > 0),
  ];

  String get packagesPipeText => packagesToPipeText(packages);

  Map<String, dynamic> toApplyMap() {
    return {
      'title': title,
      'shortDescription': shortDescription,
      'fullDescription': fullDescription,
      'category': category,
      'tags': tags,
      'pricingType': pricingType,
      'startingPrice': startingPrice,
      'estimatedDelivery': estimatedDelivery,
      'currency': currency,
      'packages': packages,
      'coverImageUrl': coverImageUrl,
      'galleryUrls': galleryUrls,
      'portfolioLinks': portfolioLinks,
      'linkedSkills': linkedSkills,
      'linkedCertificateIds': linkedCertificateIds,
      if (skillScore != null) 'skillScore': skillScore,
      'assumptions': assumptions,
      'missingInputs': missingInputs,
      'manualReviewNotes': manualReviewNotes,
    };
  }

  static MarketplaceServiceListingDraft? fromStructuredData(
    Map<String, dynamic>? structuredData,
  ) {
    if (structuredData == null || structuredData.isEmpty) return null;
    final raw = structuredData['serviceListing'];
    if (raw is! Map) return null;
    return fromMap(Map<String, dynamic>.from(raw));
  }

  static MarketplaceServiceListingDraft fromMap(Map<String, dynamic> map) {
    return MarketplaceServiceListingDraft(
      raw: map,
      title: marketplaceAiString(map['title']),
      shortDescription: marketplaceAiString(map['shortDescription']),
      fullDescription: marketplaceAiString(map['fullDescription']),
      category: marketplaceAiString(map['category']),
      tags: marketplaceAiStringList(map['tags']),
      pricingType: marketplaceAiString(map['pricingType']).toLowerCase(),
      startingPrice: marketplaceAiDouble(map['startingPrice']),
      estimatedDelivery: marketplaceAiString(map['estimatedDelivery']),
      currency: marketplaceAiString(map['currency'], 'USD').toUpperCase(),
      packages: marketplaceAiPackageMaps(map['packages']),
      coverImageUrl: marketplaceAiString(map['coverImageUrl']),
      galleryUrls: marketplaceAiStringList(map['galleryUrls']),
      portfolioLinks: marketplaceAiStringList(map['portfolioLinks']),
      linkedSkills: marketplaceAiStringList(map['linkedSkills']),
      linkedCertificateIds: marketplaceAiStringList(map['linkedCertificateIds']),
      skillScore: marketplaceAiDouble(map['skillScore']),
      assumptions: marketplaceAiStringList(map['assumptions']),
      missingInputs: marketplaceAiStringList(map['missingInputs']),
      manualReviewNotes: marketplaceAiStringList(map['manualReviewNotes']),
    );
  }

  MarketplaceServiceListingDraft copyWith({
    Map<String, dynamic>? raw,
    String? title,
    String? shortDescription,
    String? fullDescription,
    String? category,
    List<String>? tags,
    String? pricingType,
    double? startingPrice,
    bool clearStartingPrice = false,
    String? estimatedDelivery,
    String? currency,
    List<Map<String, dynamic>>? packages,
    String? coverImageUrl,
    List<String>? galleryUrls,
    List<String>? portfolioLinks,
    List<String>? linkedSkills,
    List<String>? linkedCertificateIds,
    double? skillScore,
    bool clearSkillScore = false,
    List<String>? assumptions,
    List<String>? missingInputs,
    List<String>? manualReviewNotes,
  }) {
    return MarketplaceServiceListingDraft(
      raw: raw ?? this.raw,
      title: title ?? this.title,
      shortDescription: shortDescription ?? this.shortDescription,
      fullDescription: fullDescription ?? this.fullDescription,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      pricingType: pricingType ?? this.pricingType,
      startingPrice: clearStartingPrice
          ? null
          : (startingPrice ?? this.startingPrice),
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      currency: currency ?? this.currency,
      packages: packages ?? this.packages,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      galleryUrls: galleryUrls ?? this.galleryUrls,
      portfolioLinks: portfolioLinks ?? this.portfolioLinks,
      linkedSkills: linkedSkills ?? this.linkedSkills,
      linkedCertificateIds: linkedCertificateIds ?? this.linkedCertificateIds,
      skillScore: clearSkillScore ? null : (skillScore ?? this.skillScore),
      assumptions: assumptions ?? this.assumptions,
      missingInputs: missingInputs ?? this.missingInputs,
      manualReviewNotes: manualReviewNotes ?? this.manualReviewNotes,
    );
  }
}

class MarketplaceServiceRequestDraft {
  const MarketplaceServiceRequestDraft({
    required this.raw,
    this.projectTitle = '',
    this.requirements = '',
    this.attachments = const <String>[],
    this.clientName = '',
    this.clientEmail = '',
    this.packageId = '',
    this.budget,
    this.currency = '',
    this.priority = '',
    this.deadlineHint = '',
    this.assumptions = const <String>[],
    this.missingInputs = const <String>[],
    this.manualReviewNotes = const <String>[],
  });

  final Map<String, dynamic> raw;
  final String projectTitle;
  final String requirements;
  final List<String> attachments;
  final String clientName;
  final String clientEmail;
  final String packageId;
  final double? budget;
  final String currency;
  final String priority;
  final String deadlineHint;
  final List<String> assumptions;
  final List<String> missingInputs;
  final List<String> manualReviewNotes;

  bool get hasFillableContent =>
      projectTitle.trim().isNotEmpty || requirements.trim().isNotEmpty;

  List<MapEntry<String, bool>> get fieldChecklist => [
    MapEntry('projectTitle', projectTitle.trim().isNotEmpty),
    MapEntry('requirements', requirements.trim().isNotEmpty),
    MapEntry('packageId', packageId.trim().isNotEmpty),
    MapEntry('priority', priority.trim().isNotEmpty),
    MapEntry('deadlineHint', deadlineHint.trim().isNotEmpty),
    MapEntry('clientName', clientName.trim().isNotEmpty),
    MapEntry('clientEmail', clientEmail.trim().isNotEmpty),
  ];

  Map<String, dynamic> toApplyMap() => {
    'projectTitle': projectTitle,
    'requirements': requirements,
    'attachments': attachments,
    'clientName': clientName,
    'clientEmail': clientEmail,
    'packageId': packageId,
    if (budget != null) 'budget': budget,
    'currency': currency,
    'priority': priority,
    'deadlineHint': deadlineHint,
    'assumptions': assumptions,
    'missingInputs': missingInputs,
    'manualReviewNotes': manualReviewNotes,
  };

  static MarketplaceServiceRequestDraft? fromStructuredData(
    Map<String, dynamic>? structuredData,
  ) {
    if (structuredData == null) return null;
    final raw =
        structuredData['serviceRequest'] ??
        structuredData['projectBrief'] ??
        structuredData['requirements'];
    if (raw is Map) return fromMap(Map<String, dynamic>.from(raw));
    // Flat fallback from brief builders.
    if (structuredData.containsKey('projectTitle') ||
        structuredData.containsKey('requirements') ||
        structuredData.containsKey('projectBrief')) {
      return fromMap({
        'projectTitle': structuredData['projectTitle'],
        'requirements':
            structuredData['requirements'] ??
            structuredData['projectBrief'] ??
            structuredData['draftBody'],
        'packageId': structuredData['packageId'],
        'priority': structuredData['priority'],
        'deadlineHint': structuredData['deadlineHint'],
        'clientName': structuredData['clientName'],
        'clientEmail': structuredData['clientEmail'],
        'attachments': structuredData['attachments'],
        'budget': structuredData['budget'],
        'currency': structuredData['currency'],
        'assumptions': structuredData['assumptions'],
        'missingInputs': structuredData['missingInputs'],
        'manualReviewNotes': structuredData['manualReviewNotes'],
      });
    }
    return null;
  }

  static MarketplaceServiceRequestDraft fromMap(Map<String, dynamic> map) {
    return MarketplaceServiceRequestDraft(
      raw: map,
      projectTitle: marketplaceAiString(
        map['projectTitle'] ?? map['title'],
      ),
      requirements: marketplaceAiString(
        map['requirements'] ?? map['body'] ?? map['projectBrief'],
      ),
      attachments: marketplaceAiStringList(map['attachments']),
      clientName: marketplaceAiString(map['clientName']),
      clientEmail: marketplaceAiString(map['clientEmail']),
      packageId: marketplaceAiString(map['packageId'] ?? map['recommendedPackageId']),
      budget: marketplaceAiDouble(map['budget']),
      currency: marketplaceAiString(map['currency']),
      priority: marketplaceAiString(map['priority']).toLowerCase(),
      deadlineHint: marketplaceAiString(map['deadlineHint'] ?? map['deadline']),
      assumptions: marketplaceAiStringList(map['assumptions']),
      missingInputs: marketplaceAiStringList(map['missingInputs']),
      manualReviewNotes: marketplaceAiStringList(map['manualReviewNotes']),
    );
  }

  MarketplaceServiceRequestDraft copyWith({
    String? projectTitle,
    String? requirements,
    List<String>? attachments,
    String? clientName,
    String? clientEmail,
    String? packageId,
    double? budget,
    bool clearBudget = false,
    String? currency,
    String? priority,
    String? deadlineHint,
    List<String>? assumptions,
    List<String>? missingInputs,
    List<String>? manualReviewNotes,
  }) {
    return MarketplaceServiceRequestDraft(
      raw: raw,
      projectTitle: projectTitle ?? this.projectTitle,
      requirements: requirements ?? this.requirements,
      attachments: attachments ?? this.attachments,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      packageId: packageId ?? this.packageId,
      budget: clearBudget ? null : (budget ?? this.budget),
      currency: currency ?? this.currency,
      priority: priority ?? this.priority,
      deadlineHint: deadlineHint ?? this.deadlineHint,
      assumptions: assumptions ?? this.assumptions,
      missingInputs: missingInputs ?? this.missingInputs,
      manualReviewNotes: manualReviewNotes ?? this.manualReviewNotes,
    );
  }
}

/// Generic text draft used for proposal / delivery / message / resolution notes.
class MarketplaceTextDraft {
  const MarketplaceTextDraft({
    required this.raw,
    required this.kind,
    this.subject = '',
    this.body = '',
    this.scopeSummary = '',
    this.timeline = '',
    this.priceSuggestion = '',
    this.questions = const <String>[],
    this.assumptions = const <String>[],
    this.missingInputs = const <String>[],
    this.manualReviewNotes = const <String>[],
    this.links = const <String>[],
  });

  final Map<String, dynamic> raw;
  final String kind;
  final String subject;
  final String body;
  final String scopeSummary;
  final String timeline;
  final String priceSuggestion;
  final List<String> questions;
  final List<String> assumptions;
  final List<String> missingInputs;
  final List<String> manualReviewNotes;
  final List<String> links;

  bool get hasFillableContent =>
      body.trim().isNotEmpty ||
      subject.trim().isNotEmpty ||
      scopeSummary.trim().isNotEmpty;

  /// Combined note body for form Apply (never auto-submits).
  String get composedNoteBody {
    final parts = <String>[
      if (subject.trim().isNotEmpty) subject.trim(),
      if (body.trim().isNotEmpty) body.trim(),
      if (scopeSummary.trim().isNotEmpty) 'Scope: ${scopeSummary.trim()}',
      if (timeline.trim().isNotEmpty) 'Timeline: ${timeline.trim()}',
      if (priceSuggestion.trim().isNotEmpty)
        'Price suggestion: ${priceSuggestion.trim()}',
      if (questions.isNotEmpty)
        'Questions:\n${questions.map((q) => '- $q').join('\n')}',
      if (assumptions.isNotEmpty)
        'Assumptions:\n${assumptions.map((a) => '- $a').join('\n')}',
    ];
    return parts.join('\n\n').trim();
  }

  List<MapEntry<String, bool>> get fieldChecklist => [
    MapEntry('subject', subject.trim().isNotEmpty),
    MapEntry('body', body.trim().isNotEmpty),
    MapEntry('scopeSummary', scopeSummary.trim().isNotEmpty),
    MapEntry('timeline', timeline.trim().isNotEmpty),
    MapEntry('questions', questions.isNotEmpty),
  ];

  Map<String, dynamic> toApplyMap() => {
    'kind': kind,
    'subject': subject,
    'body': body,
    'scopeSummary': scopeSummary,
    'timeline': timeline,
    'priceSuggestion': priceSuggestion,
    'questions': questions,
    'assumptions': assumptions,
    'missingInputs': missingInputs,
    'manualReviewNotes': manualReviewNotes,
    'links': links,
    'composedNoteBody': composedNoteBody,
  };

  static MarketplaceTextDraft? fromStructuredData(
    Map<String, dynamic>? structuredData, {
    required String taskType,
  }) {
    if (structuredData == null) return null;
    final key = MarketplaceAiTaskType.structuredDataKeyHint(taskType);
    final nested = structuredData[key];
    if (nested is Map) {
      return fromMap(Map<String, dynamic>.from(nested), kind: key);
    }
    // Fallback: draftTitle/draftBody style.
    final body = marketplaceAiString(
      structuredData['draftBody'] ??
          structuredData['body'] ??
          structuredData['message'] ??
          structuredData['notes'],
    );
    final subject = marketplaceAiString(
      structuredData['draftTitle'] ?? structuredData['subject'],
    );
    if (body.isEmpty && subject.isEmpty) return null;
    return MarketplaceTextDraft(
      raw: structuredData,
      kind: key,
      subject: subject,
      body: body,
      scopeSummary: marketplaceAiString(structuredData['scopeSummary']),
      timeline: marketplaceAiString(structuredData['timeline']),
      priceSuggestion: marketplaceAiString(structuredData['priceSuggestion']),
      questions: marketplaceAiStringList(
        structuredData['questions'] ?? structuredData['clientQuestions'],
      ),
      assumptions: marketplaceAiStringList(structuredData['assumptions']),
      missingInputs: marketplaceAiStringList(structuredData['missingInputs']),
      manualReviewNotes: marketplaceAiStringList(
        structuredData['manualReviewNotes'],
      ),
      links: marketplaceAiStringList(structuredData['links']),
    );
  }

  static MarketplaceTextDraft fromMap(
    Map<String, dynamic> map, {
    required String kind,
  }) {
    return MarketplaceTextDraft(
      raw: map,
      kind: kind,
      subject: marketplaceAiString(map['subject'] ?? map['draftTitle']),
      body: marketplaceAiString(
        map['body'] ?? map['draftBody'] ?? map['message'] ?? map['notes'],
      ),
      scopeSummary: marketplaceAiString(map['scopeSummary']),
      timeline: marketplaceAiString(map['timeline']),
      priceSuggestion: marketplaceAiString(
        map['priceSuggestion'] ?? map['price'],
      ),
      questions: marketplaceAiStringList(
        map['questions'] ?? map['clientQuestions'] ?? map['gaps'],
      ),
      assumptions: marketplaceAiStringList(map['assumptions']),
      missingInputs: marketplaceAiStringList(map['missingInputs']),
      manualReviewNotes: marketplaceAiStringList(map['manualReviewNotes']),
      links: marketplaceAiStringList(map['links'] ?? map['attachmentUrls']),
    );
  }
}

class MarketplaceAcceptanceChecklistDraft {
  const MarketplaceAcceptanceChecklistDraft({
    required this.raw,
    this.title = '',
    this.items = const <MarketplaceChecklistItem>[],
    this.summary = '',
    this.manualReviewNotes = const <String>[],
  });

  final Map<String, dynamic> raw;
  final String title;
  final List<MarketplaceChecklistItem> items;
  final String summary;
  final List<String> manualReviewNotes;

  bool get hasFillableContent => items.isNotEmpty;

  Map<String, dynamic> toApplyMap() => {
    'title': title,
    'summary': summary,
    'items': items.map((e) => e.toMap()).toList(),
    'manualReviewNotes': manualReviewNotes,
  };

  static MarketplaceAcceptanceChecklistDraft? fromStructuredData(
    Map<String, dynamic>? structuredData,
  ) {
    if (structuredData == null) return null;
    final raw =
        structuredData['acceptanceChecklist'] ?? structuredData['checklist'];
    if (raw is Map) {
      return fromMap(Map<String, dynamic>.from(raw));
    }
    if (raw is Iterable) {
      return fromMap({'items': raw});
    }
    return null;
  }

  static MarketplaceAcceptanceChecklistDraft fromMap(Map<String, dynamic> map) {
    final itemsRaw = map['items'] ?? map['checklist'];
    final items = <MarketplaceChecklistItem>[];
    if (itemsRaw is Iterable) {
      for (final item in itemsRaw) {
        if (item is Map) {
          items.add(
            MarketplaceChecklistItem.fromMap(Map<String, dynamic>.from(item)),
          );
        } else if (item != null && item.toString().trim().isNotEmpty) {
          items.add(MarketplaceChecklistItem(label: item.toString().trim()));
        }
      }
    }
    return MarketplaceAcceptanceChecklistDraft(
      raw: map,
      title: marketplaceAiString(map['title'], 'Delivery acceptance checklist'),
      items: items,
      summary: marketplaceAiString(map['summary']),
      manualReviewNotes: marketplaceAiStringList(map['manualReviewNotes']),
    );
  }
}

class MarketplaceChecklistItem {
  const MarketplaceChecklistItem({
    required this.label,
    this.checked = false,
    this.hint = '',
  });

  final String label;
  final bool checked;
  final String hint;

  MarketplaceChecklistItem copyWith({bool? checked}) =>
      MarketplaceChecklistItem(
        label: label,
        checked: checked ?? this.checked,
        hint: hint,
      );

  Map<String, dynamic> toMap() => {
    'label': label,
    'checked': checked,
    'hint': hint,
  };

  factory MarketplaceChecklistItem.fromMap(Map<String, dynamic> map) {
    return MarketplaceChecklistItem(
      label: marketplaceAiString(map['label'] ?? map['text'] ?? map['item']),
      checked: map['checked'] == true,
      hint: marketplaceAiString(map['hint'] ?? map['detail']),
    );
  }
}

class MarketplaceComparisonDraft {
  const MarketplaceComparisonDraft({
    required this.raw,
    this.summary = '',
    this.candidates = const <Map<String, dynamic>>[],
    this.criteria = const <String>[],
    this.notEnoughEvidence = false,
    this.manualReviewNotes = const <String>[],
  });

  final Map<String, dynamic> raw;
  final String summary;
  final List<Map<String, dynamic>> candidates;
  final List<String> criteria;
  final bool notEnoughEvidence;
  final List<String> manualReviewNotes;

  bool get hasFillableContent =>
      summary.trim().isNotEmpty || candidates.isNotEmpty || notEnoughEvidence;

  Map<String, dynamic> toApplyMap() => {
    'summary': summary,
    'candidates': candidates,
    'criteria': criteria,
    'notEnoughEvidence': notEnoughEvidence,
    'manualReviewNotes': manualReviewNotes,
  };

  static MarketplaceComparisonDraft? fromStructuredData(
    Map<String, dynamic>? structuredData,
  ) {
    if (structuredData == null) return null;
    final raw = structuredData['comparison'];
    if (raw is! Map) {
      if (structuredData['notEnoughEvidence'] == true ||
          marketplaceAiString(structuredData['summary']).isNotEmpty) {
        return fromMap(structuredData);
      }
      return null;
    }
    return fromMap(Map<String, dynamic>.from(raw));
  }

  static MarketplaceComparisonDraft fromMap(Map<String, dynamic> map) {
    final candidates = <Map<String, dynamic>>[];
    final rawCandidates = map['candidates'] ?? map['freelancers'];
    if (rawCandidates is Iterable) {
      for (final item in rawCandidates) {
        if (item is Map) candidates.add(Map<String, dynamic>.from(item));
      }
    }
    return MarketplaceComparisonDraft(
      raw: map,
      summary: marketplaceAiString(map['summary']),
      candidates: candidates,
      criteria: marketplaceAiStringList(map['criteria']),
      notEnoughEvidence:
          map['notEnoughEvidence'] == true || candidates.isEmpty,
      manualReviewNotes: marketplaceAiStringList(map['manualReviewNotes']),
    );
  }
}

class MarketplaceProfileDraft {
  const MarketplaceProfileDraft({
    required this.raw,
    this.professionalTitle = '',
    this.bio = '',
    this.services = '',
    this.category = '',
    this.skills = const <String>[],
    this.hourlyRate,
    this.portfolioLinks = const <String>[],
    this.assumptions = const <String>[],
    this.missingInputs = const <String>[],
    this.manualReviewNotes = const <String>[],
  });

  final Map<String, dynamic> raw;
  final String professionalTitle;
  final String bio;
  final String services;
  final String category;
  final List<String> skills;
  final double? hourlyRate;
  final List<String> portfolioLinks;
  final List<String> assumptions;
  final List<String> missingInputs;
  final List<String> manualReviewNotes;

  bool get hasFillableContent =>
      professionalTitle.trim().isNotEmpty ||
      bio.trim().isNotEmpty ||
      services.trim().isNotEmpty ||
      category.trim().isNotEmpty ||
      skills.isNotEmpty;

  List<MapEntry<String, bool>> get fieldChecklist => [
    MapEntry('professionalTitle', professionalTitle.trim().isNotEmpty),
    MapEntry('bio', bio.trim().isNotEmpty),
    MapEntry('services', services.trim().isNotEmpty),
    MapEntry('category', category.trim().isNotEmpty),
    MapEntry('skills', skills.isNotEmpty),
    MapEntry('hourlyRate', hourlyRate != null && hourlyRate! > 0),
    MapEntry('portfolioLinks', portfolioLinks.isNotEmpty),
  ];

  Map<String, dynamic> toApplyMap() => {
    'professionalTitle': professionalTitle,
    'bio': bio,
    'services': services,
    'category': category,
    'skills': skills,
    if (hourlyRate != null) 'hourlyRate': hourlyRate,
    'portfolioLinks': portfolioLinks,
    'assumptions': assumptions,
    'missingInputs': missingInputs,
    'manualReviewNotes': manualReviewNotes,
  };

  static MarketplaceProfileDraft? fromStructuredData(
    Map<String, dynamic>? structuredData,
  ) {
    if (structuredData == null) return null;
    final raw = structuredData['profile'];
    if (raw is Map) return fromMap(Map<String, dynamic>.from(raw));
    return null;
  }

  static MarketplaceProfileDraft fromMap(Map<String, dynamic> map) {
    return MarketplaceProfileDraft(
      raw: map,
      professionalTitle: marketplaceAiString(
        map['professionalTitle'] ?? map['title'],
      ),
      bio: marketplaceAiString(map['bio']),
      services: marketplaceAiString(map['services']),
      category: marketplaceAiString(map['category']),
      skills: marketplaceAiStringList(map['skills']),
      hourlyRate: marketplaceAiDouble(map['hourlyRate']),
      portfolioLinks: marketplaceAiStringList(map['portfolioLinks']),
      assumptions: marketplaceAiStringList(map['assumptions']),
      missingInputs: marketplaceAiStringList(map['missingInputs']),
      manualReviewNotes: marketplaceAiStringList(map['manualReviewNotes']),
    );
  }

  MarketplaceProfileDraft copyWith({
    String? professionalTitle,
    String? bio,
    String? services,
    String? category,
    List<String>? skills,
    double? hourlyRate,
    bool clearHourlyRate = false,
    List<String>? portfolioLinks,
  }) {
    return MarketplaceProfileDraft(
      raw: raw,
      professionalTitle: professionalTitle ?? this.professionalTitle,
      bio: bio ?? this.bio,
      services: services ?? this.services,
      category: category ?? this.category,
      skills: skills ?? this.skills,
      hourlyRate: clearHourlyRate ? null : (hourlyRate ?? this.hourlyRate),
      portfolioLinks: portfolioLinks ?? this.portfolioLinks,
      assumptions: assumptions,
      missingInputs: missingInputs,
      manualReviewNotes: manualReviewNotes,
    );
  }
}

class MarketplaceAiDraftResponse {
  const MarketplaceAiDraftResponse({
    required this.taskType,
    required this.title,
    required this.summary,
    required this.structuredData,
    required this.suggestions,
    required this.safetyNotes,
    required this.provider,
    required this.requiresManualReview,
    this.serviceListing,
    this.serviceRequest,
    this.textDraft,
    this.acceptanceChecklist,
    this.comparison,
    this.profile,
    this.isUnavailable = false,
    this.blockedReason,
  });

  final String taskType;
  final String title;
  final String summary;
  final Map<String, dynamic> structuredData;
  final List<String> suggestions;
  final List<String> safetyNotes;
  final String provider;
  final bool requiresManualReview;
  final MarketplaceServiceListingDraft? serviceListing;
  final MarketplaceServiceRequestDraft? serviceRequest;
  final MarketplaceTextDraft? textDraft;
  final MarketplaceAcceptanceChecklistDraft? acceptanceChecklist;
  final MarketplaceComparisonDraft? comparison;
  final MarketplaceProfileDraft? profile;
  final bool isUnavailable;
  final String? blockedReason;

  bool get hasServiceListing => serviceListing?.hasFillableContent == true;
  bool get hasServiceRequest => serviceRequest?.hasFillableContent == true;
  bool get hasTextDraft => textDraft?.hasFillableContent == true;
  bool get hasChecklist => acceptanceChecklist?.hasFillableContent == true;
  bool get hasComparison => comparison?.hasFillableContent == true;
  bool get hasProfile => profile?.hasFillableContent == true;

  bool get hasAnyApplyTarget =>
      hasServiceListing ||
      hasServiceRequest ||
      hasTextDraft ||
      hasChecklist ||
      hasComparison ||
      hasProfile;

  List<MapEntry<String, bool>> get fieldChecklist {
    if (serviceListing != null) return serviceListing!.fieldChecklist;
    if (serviceRequest != null) return serviceRequest!.fieldChecklist;
    if (profile != null) return profile!.fieldChecklist;
    if (textDraft != null) return textDraft!.fieldChecklist;
    return const [];
  }

  Map<String, dynamic>? get primaryApplyMap {
    if (serviceListing != null) return serviceListing!.toApplyMap();
    if (serviceRequest != null) return serviceRequest!.toApplyMap();
    if (profile != null) return profile!.toApplyMap();
    if (textDraft != null) return textDraft!.toApplyMap();
    if (acceptanceChecklist != null) return acceptanceChecklist!.toApplyMap();
    if (comparison != null) return comparison!.toApplyMap();
    return null;
  }

  factory MarketplaceAiDraftResponse.fromCopilot(
    CopilotAiResponseModel response, {
    required String taskType,
  }) {
    final listing = MarketplaceServiceListingDraft.fromStructuredData(
      response.structuredData,
    );
    final request = MarketplaceServiceRequestDraft.fromStructuredData(
      response.structuredData,
    );
    final text = MarketplaceTextDraft.fromStructuredData(
      response.structuredData,
      taskType: taskType,
    );
    final checklist = MarketplaceAcceptanceChecklistDraft.fromStructuredData(
      response.structuredData,
    );
    final comparison = MarketplaceComparisonDraft.fromStructuredData(
      response.structuredData,
    );
    final profile = MarketplaceProfileDraft.fromStructuredData(
      response.structuredData,
    );
    final unavailable =
        !response.isSuccess ||
        response.isAiUnavailable ||
        response.provider == 'aiUnavailable' ||
        response.source == 'gatewayUnreachable';
    return MarketplaceAiDraftResponse(
      taskType: taskType,
      title: response.title,
      summary: response.message,
      structuredData: response.structuredData,
      suggestions: response.suggestions,
      safetyNotes: response.safetyNotes,
      provider: response.source ?? response.provider,
      requiresManualReview: response.requiresManualReview,
      serviceListing: listing,
      serviceRequest: request,
      textDraft: text,
      acceptanceChecklist: checklist,
      comparison: comparison,
      profile: profile,
      isUnavailable: unavailable,
      blockedReason: response.blockedReason,
    );
  }

  MarketplaceAiDraftResponse copyWith({
    MarketplaceServiceListingDraft? serviceListing,
    MarketplaceServiceRequestDraft? serviceRequest,
    MarketplaceTextDraft? textDraft,
    MarketplaceAcceptanceChecklistDraft? acceptanceChecklist,
    MarketplaceComparisonDraft? comparison,
    MarketplaceProfileDraft? profile,
    Map<String, dynamic>? structuredData,
    List<String>? safetyNotes,
    bool? requiresManualReview,
  }) {
    return MarketplaceAiDraftResponse(
      taskType: taskType,
      title: title,
      summary: summary,
      structuredData: structuredData ?? this.structuredData,
      suggestions: suggestions,
      safetyNotes: safetyNotes ?? this.safetyNotes,
      provider: provider,
      requiresManualReview: requiresManualReview ?? this.requiresManualReview,
      serviceListing: serviceListing ?? this.serviceListing,
      serviceRequest: serviceRequest ?? this.serviceRequest,
      textDraft: textDraft ?? this.textDraft,
      acceptanceChecklist: acceptanceChecklist ?? this.acceptanceChecklist,
      comparison: comparison ?? this.comparison,
      profile: profile ?? this.profile,
      isUnavailable: isUnavailable,
      blockedReason: blockedReason,
    );
  }
}

/// In-session pending Apply payloads (forms consume then clear).
class MarketplaceAiPendingApply {
  MarketplaceAiPendingApply._();

  static Map<String, dynamic>? serviceListing;
  static Map<String, dynamic>? serviceRequest;
  static String? noteBody;
  static String? noteKind;
  static List<String>? deliveryLinks;
  static Map<String, dynamic>? profile;
  static Map<String, dynamic>? acceptanceChecklist;
  static String? careerListingHint;

  static void clear() {
    serviceListing = null;
    serviceRequest = null;
    noteBody = null;
    noteKind = null;
    deliveryLinks = null;
    profile = null;
    acceptanceChecklist = null;
    careerListingHint = null;
  }

  static void setNote({required String kind, required String body}) {
    noteKind = kind;
    noteBody = body;
  }

  static String? takeNoteBodyFor(String kind) {
    if (noteKind != kind) return null;
    final body = noteBody;
    noteBody = null;
    noteKind = null;
    return body;
  }
}

String packagesToPipeText(List<Map<String, dynamic>> packages) {
  return packages
      .map((package) {
        final title = marketplaceAiString(package['title']);
        final price = marketplaceAiDouble(package['price']) ?? 0;
        final days = marketplaceAiInt(package['deliveryDays']) ?? 0;
        final revisions = marketplaceAiInt(package['revisionsIncluded']) ?? 1;
        final description = marketplaceAiString(package['description']);
        return '$title | ${price == price.roundToDouble() ? price.toStringAsFixed(0) : price} | $days | $revisions | $description';
      })
      .where((line) => line.trim().isNotEmpty)
      .join('\n');
}

List<Map<String, dynamic>> marketplaceAiPackageMaps(Object? value) {
  if (value is! Iterable) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

String marketplaceAiString(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

List<String> marketplaceAiStringList(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(RegExp(r'[\n,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

double? marketplaceAiDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

int? marketplaceAiInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
