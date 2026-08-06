import '../models/marketplace_ai_draft_models.dart';

/// Client-side sanitizer for marketplace AI Apply paths.
/// Drops invented URLs/certs, ignores hallucinated skillScore,
/// strips payment-execution language, never flips verified badge.
class MarketplaceAiSanitize {
  const MarketplaceAiSanitize._();

  static final _paymentExecutionPattern = RegExp(
    r'\b(auto[- ]?(pay|publish|refund|release|escrow|message|hire|accept)|'
    r'payment (sent|executed)|escrow (released|refunded)|'
    r'i (have|just) (paid|refunded|released|published|sent))\b',
    caseSensitive: false,
  );

  static MarketplaceServiceListingDraft sanitizeServiceListing(
    MarketplaceServiceListingDraft draft, {
    required MarketplaceAiKnownEvidence evidence,
  }) {
    final allowedPortfolio = draft.portfolioLinks
        .where(evidence.isAllowedUrl)
        .toList(growable: false);
    final cover = evidence.isAllowedUrl(draft.coverImageUrl)
        ? draft.coverImageUrl
        : '';
    final gallery = draft.galleryUrls
        .where(evidence.isAllowedUrl)
        .toList(growable: false);
    final skills = draft.linkedSkills
        .where(evidence.isKnownSkill)
        .toList(growable: false);
    final certs = draft.linkedCertificateIds
        .where(evidence.isKnownCertificateId)
        .toList(growable: false);

    double? skillScore;
    final platform = evidence.platformSkillScore;
    if (platform != null && platform > 0) {
      skillScore = platform.clamp(0, 100).toDouble();
    }

    final pricing = draft.pricingType == 'hourly' || draft.pricingType == 'fixed'
        ? draft.pricingType
        : '';

    return draft.copyWith(
      title: stripExecutionClaims(draft.title),
      shortDescription: stripExecutionClaims(draft.shortDescription),
      fullDescription: stripExecutionClaims(draft.fullDescription),
      pricingType: pricing,
      coverImageUrl: cover,
      galleryUrls: gallery,
      portfolioLinks: allowedPortfolio,
      linkedSkills: skills,
      linkedCertificateIds: certs,
      skillScore: skillScore,
      clearSkillScore: skillScore == null,
      currency: draft.currency.trim().isEmpty
          ? 'USD'
          : draft.currency.trim().toUpperCase(),
    );
  }

  static Map<String, dynamic> sanitizeServiceListingMap(
    Map<String, dynamic> listing, {
    required MarketplaceAiKnownEvidence evidence,
  }) {
    return sanitizeServiceListing(
      MarketplaceServiceListingDraft.fromMap(listing),
      evidence: evidence,
    ).toApplyMap();
  }

  static MarketplaceServiceRequestDraft sanitizeServiceRequest(
    MarketplaceServiceRequestDraft draft, {
    required MarketplaceAiKnownEvidence evidence,
  }) {
    final packageId =
        draft.packageId.trim().isNotEmpty &&
            evidence.isKnownPackageId(draft.packageId)
        ? draft.packageId.trim()
        : '';

    // Attachments: placeholders only — drop unknown URLs.
    final attachments = draft.attachments
        .where((item) {
          final lower = item.toLowerCase();
          if (lower.startsWith('http://') || lower.startsWith('https://')) {
            return evidence.isAllowedUrl(item);
          }
          // Allow non-URL placeholders like "wireframe.pdf (to attach)".
          return true;
        })
        .toList(growable: false);

    final clientName = draft.clientName.trim().isNotEmpty
        ? draft.clientName.trim()
        : evidence.clientName.trim();
    final clientEmail = draft.clientEmail.trim().isNotEmpty
        ? draft.clientEmail.trim()
        : evidence.clientEmail.trim();

    final priority = switch (draft.priority.trim().toLowerCase()) {
      'low' || 'normal' || 'high' => draft.priority.trim().toLowerCase(),
      _ => '',
    };

    return draft.copyWith(
      projectTitle: stripExecutionClaims(draft.projectTitle),
      requirements: stripExecutionClaims(draft.requirements),
      attachments: attachments,
      clientName: clientName,
      clientEmail: clientEmail,
      packageId: packageId,
      // Budget only from known package — never invent.
      clearBudget: true,
      currency: '',
      priority: priority,
    );
  }

  static MarketplaceTextDraft sanitizeTextDraft(MarketplaceTextDraft draft) {
    return MarketplaceTextDraft(
      raw: draft.raw,
      kind: draft.kind,
      subject: stripExecutionClaims(draft.subject),
      body: stripExecutionClaims(draft.body),
      scopeSummary: stripExecutionClaims(draft.scopeSummary),
      timeline: stripExecutionClaims(draft.timeline),
      priceSuggestion: stripExecutionClaims(draft.priceSuggestion),
      questions: draft.questions.map(stripExecutionClaims).toList(),
      assumptions: draft.assumptions.map(stripExecutionClaims).toList(),
      missingInputs: draft.missingInputs,
      manualReviewNotes: [
        ...draft.manualReviewNotes,
        'Draft only — human must review and submit manually.',
      ],
      links: const [], // never invent delivery/attachment URLs
    );
  }

  static MarketplaceProfileDraft sanitizeProfile(
    MarketplaceProfileDraft draft, {
    required MarketplaceAiKnownEvidence evidence,
  }) {
    final skills = draft.skills
        .where(evidence.isKnownSkill)
        .toList(growable: false);
    final links = draft.portfolioLinks
        .where(evidence.isAllowedUrl)
        .toList(growable: false);

    return draft.copyWith(
      professionalTitle: stripExecutionClaims(draft.professionalTitle),
      bio: stripExecutionClaims(draft.bio),
      services: stripExecutionClaims(draft.services),
      category: stripExecutionClaims(draft.category),
      skills: skills,
      portfolioLinks: links,
      // Soft rate — keep if positive numeric, still user-confirmed on Apply.
      hourlyRate: draft.hourlyRate != null && draft.hourlyRate! > 0
          ? draft.hourlyRate
          : null,
      clearHourlyRate: draft.hourlyRate == null || draft.hourlyRate! <= 0,
    );
  }

  static MarketplaceComparisonDraft sanitizeComparison(
    MarketplaceComparisonDraft draft,
  ) {
    // Refuse invented ratings — strip rating/portfolio fields that look invented.
    final cleaned = draft.candidates.map((candidate) {
      final map = Map<String, dynamic>.from(candidate);
      map.remove('inventedRating');
      map.remove('guaranteedRating');
      // Keep only evidence-looking keys.
      return map;
    }).toList();

    final notEnough =
        draft.notEnoughEvidence ||
        cleaned.isEmpty ||
        cleaned.every((c) {
          final evidence = c['evidence'] ?? c['skills'] ?? c['summary'];
          return evidence == null || evidence.toString().trim().isEmpty;
        });

    return MarketplaceComparisonDraft(
      raw: draft.raw,
      summary: notEnough
          ? (draft.summary.trim().isNotEmpty
                ? stripExecutionClaims(draft.summary)
                : 'Not enough evidence to compare freelancers fairly.')
          : stripExecutionClaims(draft.summary),
      candidates: notEnough ? const [] : cleaned,
      criteria: draft.criteria,
      notEnoughEvidence: notEnough,
      manualReviewNotes: [
        ...draft.manualReviewNotes,
        'Comparison is advisory only. Use provided evidence only.',
      ],
    );
  }

  static MarketplaceAcceptanceChecklistDraft sanitizeChecklist(
    MarketplaceAcceptanceChecklistDraft draft,
  ) {
    final items = draft.items
        .where((item) => item.label.trim().isNotEmpty)
        .map(
          (item) => MarketplaceChecklistItem(
            label: stripExecutionClaims(item.label),
            checked: false, // never auto-check acceptance
            hint: stripExecutionClaims(item.hint),
          ),
        )
        .toList(growable: false);
    return MarketplaceAcceptanceChecklistDraft(
      raw: draft.raw,
      title: stripExecutionClaims(draft.title),
      items: items,
      summary: stripExecutionClaims(draft.summary),
      manualReviewNotes: [
        ...draft.manualReviewNotes,
        'Advisory checklist only — does not complete or release escrow.',
      ],
    );
  }

  static MarketplaceAiDraftResponse sanitizeResponse(
    MarketplaceAiDraftResponse response, {
    required MarketplaceAiKnownEvidence evidence,
  }) {
    var next = response;
    if (response.serviceListing != null) {
      final sanitized = sanitizeServiceListing(
        response.serviceListing!,
        evidence: evidence,
      );
      next = next.copyWith(
        serviceListing: sanitized,
        structuredData: {
          ...next.structuredData,
          'serviceListing': sanitized.toApplyMap(),
        },
      );
    }
    if (response.serviceRequest != null) {
      final sanitized = sanitizeServiceRequest(
        response.serviceRequest!,
        evidence: evidence,
      );
      next = next.copyWith(
        serviceRequest: sanitized,
        structuredData: {
          ...next.structuredData,
          'serviceRequest': sanitized.toApplyMap(),
        },
      );
    }
    if (response.textDraft != null) {
      final sanitized = sanitizeTextDraft(response.textDraft!);
      next = next.copyWith(
        textDraft: sanitized,
        structuredData: {
          ...next.structuredData,
          sanitized.kind: sanitized.toApplyMap(),
        },
      );
    }
    if (response.profile != null) {
      final sanitized = sanitizeProfile(
        response.profile!,
        evidence: evidence,
      );
      next = next.copyWith(
        profile: sanitized,
        structuredData: {
          ...next.structuredData,
          'profile': sanitized.toApplyMap(),
        },
      );
    }
    if (response.comparison != null) {
      final sanitized = sanitizeComparison(response.comparison!);
      next = next.copyWith(
        comparison: sanitized,
        structuredData: {
          ...next.structuredData,
          'comparison': sanitized.toApplyMap(),
        },
      );
    }
    if (response.acceptanceChecklist != null) {
      final sanitized = sanitizeChecklist(response.acceptanceChecklist!);
      next = next.copyWith(
        acceptanceChecklist: sanitized,
        structuredData: {
          ...next.structuredData,
          'acceptanceChecklist': sanitized.toApplyMap(),
        },
      );
    }
    return next.copyWith(
      requiresManualReview: true,
      safetyNotes: [
        ...next.safetyNotes,
        'Invented URLs and certificate IDs were removed before Apply.',
        'Verified badge is never set by AI.',
        'Apply fills forms only — Publish / Submit / Pay remain user actions.',
      ],
    );
  }

  static String stripExecutionClaims(String input) {
    if (input.trim().isEmpty) return input;
    return input
        .replaceAll(_paymentExecutionPattern, '[review manually]')
        .trim();
  }
}
