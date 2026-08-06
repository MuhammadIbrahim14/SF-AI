import { safeResponse } from '../schemas/responseSchema.js';

const SERVICE_LISTING_TASKS = new Set([
  'freelancerServiceListingBuilder',
  'freelancerServiceListingImprover',
]);

export const mockProvider = {
  async generate(request) {
    const topic = request.userMessage.replace(/\s+/g, ' ').trim() || 'requested topic';
    const taskType = String(request.taskType || '');
    const structuredData = buildStructuredData(request, topic, taskType);

    return safeResponse(request, {
      provider: 'mock',
      title: titleFor(taskType),
      message: messageFor(taskType, topic),
      structuredData,
      suggestions: ['Review', 'Edit', 'Apply manually'],
      requiresManualReview: true,
      proposedAction: null,
      safetyNotes: [
        'Review before applying. AI can make mistakes.',
        'No data was changed by the gateway.',
        'Apply fills forms only — never auto-publish, pay, message, or settle escrow.',
        'Do not invent cover/gallery/portfolio URLs, certificate IDs, or verified badges.',
      ],
    });
  },
};

function buildStructuredData(request, topic, taskType) {
  if (SERVICE_LISTING_TASKS.has(taskType)) {
    return mockServiceListingStructuredData(request, topic);
  }
  if (
    taskType === 'customerServiceRequestDraft' ||
    taskType === 'customerProjectBriefBuilder' ||
    taskType === 'customerRequirementClarifier'
  ) {
    return mockServiceRequest(request, topic);
  }
  if (taskType === 'freelancerProposalDraft') {
    return mockProposal(topic);
  }
  if (taskType === 'freelancerDeliveryNoteBuilder') {
    return mockDeliveryNote(topic);
  }
  if (taskType === 'freelancerClientUpdateDraft' || taskType === 'customerMessageDraft') {
    return {
      messageDraft: {
        subject: `Update: ${topic.slice(0, 48)}`,
        body: `Hello,\n\nQuick update regarding ${topic}. Please review and reply when convenient.\n\nThanks`,
        tone: 'professional',
        purpose: 'client_update',
        assumptions: ['Human must send manually.'],
        missingInputs: [],
        manualReviewNotes: ['requiresManualReview=true; never auto-send.'],
      },
    };
  }
  if (taskType === 'teacherBatchAnnouncementDraft') {
    return {
      announcement: {
        title: 'Batch check-in this week',
        body:
          `Quick note for ${topic}. Review pending work and support students flagged in the risk digest. ` +
          'This draft is teacher-private until you Save. Not emailed or sent.',
        tone: 'supportive',
        assumptions: ['Grounded only in provided batch risk summary.'],
        missingInputs: [],
        manualReviewNotes: [
          'requiresManualReview=true; never auto-create or send.',
          'Apply fills title/body only — teacher must Save.',
        ],
      },
    };
  }
  if (taskType === 'customerRevisionRequestDraft') {
    return mockNotesBlock('revisionRequest', topic, 'Please revise the following items based on the agreed scope.');
  }
  if (taskType === 'customerRefundRequestDraft') {
    return mockNotesBlock('refundRequest', topic, 'I am requesting a sandbox refund for the reasons below. Manual review required.');
  }
  if (taskType === 'customerDisputeExplanationDraft') {
    return mockNotesBlock('disputeExplanation', topic, 'Dispute explanation for manual review. No settlement was executed.');
  }
  if (taskType === 'freelancerRevisionResponseDraft') {
    return mockNotesBlock('revisionResponse', topic, 'Revision response draft for Notes. Human submits revision.');
  }
  if (taskType === 'freelancerDisputeEvidenceSummary') {
    return {
      evidenceSummary: {
        subject: 'Evidence summary',
        body: `Neutral summary for ${topic}. Facts and claims need human verification.`,
        timeline: ['Context received', 'Delivery recorded', 'Issue raised'],
        evidenceStrengths: ['Delivery note present in context'],
        evidenceGaps: ['Missing third-party verification'],
        claimsToVerify: ['Scope match', 'Timeline commitments'],
        recommendedAdminReviewFocus: ['Compare delivery vs agreed package'],
        assumptions: [],
        missingInputs: [],
        manualReviewNotes: ['requiresManualReview=true; advisory only.'],
      },
    };
  }
  if (taskType === 'freelancerScopeClarifier' || taskType === 'customerOrderScopeReview') {
    return {
      scopeReview: {
        subject: 'Scope review',
        body: `Scope clarification draft for ${topic}.`,
        questions: [
          'What is in scope vs out of scope?',
          'What deliverable format is expected?',
          'Is there a hard deadline?',
        ],
        gaps: ['Acceptance criteria not fully specified'],
        risks: ['Ambiguous revision count'],
        assumptions: ['Advisory only — no accept/pay/status change.'],
        missingInputs: [],
        manualReviewNotes: ['requiresManualReview=true'],
      },
    };
  }
  if (taskType === 'freelancerProfileImprover') {
    return mockProfile(request, topic);
  }
  if (taskType === 'freelancerTimelineBuilder') {
    return {
      timeline: {
        subject: 'Suggested timeline',
        body: `Proposed timeline for ${topic}. Review before sharing with the client.`,
        milestones: [
          { title: 'Kickoff', day: 1 },
          { title: 'First draft', day: 3 },
          { title: 'Revisions', day: 5 },
          { title: 'Final delivery', day: 7 },
        ],
        assumptions: [],
        missingInputs: [],
        manualReviewNotes: ['requiresManualReview=true'],
      },
    };
  }
  if (taskType === 'customerDeliveryAcceptanceChecklist') {
    return {
      acceptanceChecklist: {
        title: 'Delivery acceptance checklist',
        summary: `Advisory checklist for ${topic}. Does not complete or release escrow.`,
        items: [
          { label: 'Deliverables match the selected package', checked: false, hint: '' },
          { label: 'Files/links open and are reviewable', checked: false, hint: '' },
          { label: 'Quality meets the agreed requirements', checked: false, hint: '' },
          { label: 'Outstanding questions are resolved', checked: false, hint: '' },
        ],
        manualReviewNotes: [
          'requiresManualReview=true; proposedAction=null',
          'Checklist is advisory only — Complete/Release remain user actions.',
        ],
      },
    };
  }
  if (taskType === 'customerFreelancerComparison') {
    return mockComparison(request, topic);
  }

  return {
    topic,
    sections: [
      { title: 'Goal', items: [`Prepare safe ${taskType} content`] },
      { title: 'Manual Review', items: ['Review', 'Edit', 'Apply manually'] },
    ],
    draftTitle: titleFor(taskType),
    draftBody: `Mock draft for ${topic}. Review and apply manually.`,
    assumptions: ['Gateway mock response'],
    missingInputs: [],
    manualReviewNotes: ['requiresManualReview=true'],
  };
}

function mockServiceRequest(request, topic) {
  const ctx = mergeCtx(request);
  const packages = Array.isArray(ctx.packages)
    ? ctx.packages
    : Array.isArray(ctx.service?.packages)
      ? ctx.service.packages
      : [];
  const firstPackage = packages.find((p) => p && typeof p === 'object') || null;
  const packageId = stringOrEmpty(
    firstPackage?.packageId || firstPackage?.id || ctx.packageId,
  );
  const profile = isObject(ctx.userProfile) ? ctx.userProfile : {};
  return {
    serviceRequest: {
      projectTitle: stringOrEmpty(ctx.projectTitle) || `Project: ${topic.slice(0, 60)}`,
      requirements:
        stringOrEmpty(ctx.requirements) ||
        `I need help with ${topic}. Please deliver according to the selected package scope. I will review and submit this request myself.`,
      attachments: ['brief-notes.txt (placeholder — attach manually)'],
      clientName: stringOrEmpty(profile.fullName || ctx.clientName),
      clientEmail: stringOrEmpty(profile.email || ctx.clientEmail),
      packageId,
      budget: null,
      currency: '',
      priority: 'normal',
      deadlineHint: stringOrEmpty(ctx.deadlineHint) || 'Flexible within package delivery days',
      assumptions: [
        'Budget comes from the selected listing package — not invented.',
        'Human must review then Submit Request.',
      ],
      missingInputs: packageId ? [] : ['packageId not available in context'],
      manualReviewNotes: [
        'requiresManualReview=true; proposedAction=null; no Firestore writes.',
        'Apply fills form fields only.',
      ],
    },
  };
}

function mockProposal(topic) {
  return {
    proposal: {
      subject: `Proposal: ${topic.slice(0, 48)}`,
      body: `Thank you for your request about ${topic}. I can deliver within the agreed package scope. Please review my note before accepting.`,
      scopeSummary: 'Deliver package-scoped work with agreed revisions.',
      timeline: 'Aligned with selected package delivery days.',
      priceSuggestion: 'Use selected package price — do not invent.',
      questions: ['Any brand guidelines to follow?', 'Preferred file formats?'],
      assumptions: ['Human accepts manually after review.'],
      missingInputs: [],
      manualReviewNotes: ['requiresManualReview=true; never auto-accept.'],
    },
  };
}

function mockDeliveryNote(topic) {
  return {
    deliveryNote: {
      subject: 'Delivery ready for review',
      body: `Hi,\n\nI have prepared the delivery for ${topic}. Please review the deliverables against the agreed scope. Links/files are attached separately by me.\n\nThanks`,
      links: [],
      assumptions: ['Human submits delivery manually.'],
      missingInputs: ['attachment URLs not invented'],
      manualReviewNotes: ['requiresManualReview=true; never auto-deliver.'],
    },
  };
}

function mockNotesBlock(key, topic, bodyPrefix) {
  return {
    [key]: {
      subject: titleForKey(key),
      body: `${bodyPrefix}\n\nContext: ${topic}`,
      assumptions: ['Notes only — human submits the resolution action.'],
      missingInputs: [],
      manualReviewNotes: ['requiresManualReview=true; proposedAction=null.'],
    },
  };
}

function mockProfile(request, topic) {
  const ctx = mergeCtx(request);
  const profile = isObject(ctx.freelancerProfile) ? ctx.freelancerProfile : {};
  const knownSkills = stringArray(ctx.knownSkills || profile.skills || []);
  const knownPortfolio = stringArray(ctx.allowedUrls || profile.portfolioLinks || []);
  return {
    profile: {
      professionalTitle:
        stringOrEmpty(profile.professionalTitle) || `Professional ${topic} specialist`,
      bio:
        stringOrEmpty(profile.bio) ||
        `I help clients with ${topic}. This draft is for manual review before saving.`,
      services: stringOrEmpty(profile.services) || topic,
      category: stringOrEmpty(profile.category || ctx.category) || 'General',
      skills: knownSkills,
      hourlyRate:
        typeof profile.hourlyRate === 'number' && Number.isFinite(profile.hourlyRate)
          ? profile.hourlyRate
          : null,
      portfolioLinks: knownPortfolio,
      assumptions: ['Never invent certs or URLs.'],
      missingInputs: [
        ...(knownSkills.length ? [] : ['skills not in context']),
        ...(knownPortfolio.length ? [] : ['portfolioLinks not in context']),
      ],
      manualReviewNotes: [
        'requiresManualReview=true; never set verifiedBadge.',
        'Apply fills profile form only — Save remains user action.',
      ],
    },
  };
}

function mockComparison(request, topic) {
  const ctx = mergeCtx(request);
  const candidatesRaw = Array.isArray(ctx.candidates)
    ? ctx.candidates
    : Array.isArray(ctx.freelancers)
      ? ctx.freelancers
      : Array.isArray(ctx.services)
        ? ctx.services
        : [];
  const candidates = candidatesRaw
    .filter((item) => item && typeof item === 'object')
    .slice(0, 5)
    .map((item) => ({
      name: stringOrEmpty(item.name || item.freelancerName || item.title) || 'Candidate',
      summary: stringOrEmpty(item.summary || item.shortDescription || item.bio),
      evidence: stringOrEmpty(item.evidence || item.category),
      matchedSkills: stringArray(item.linkedSkills || item.skills),
      gaps: [],
    }));
  const notEnoughEvidence = candidates.length < 2;
  return {
    comparison: {
      summary: notEnoughEvidence
        ? 'Not enough evidence to compare freelancers fairly.'
        : `Evidence-only comparison draft for ${topic}.`,
      criteria: ['skills match', 'package fit', 'delivery clarity'],
      candidates: notEnoughEvidence ? [] : candidates,
      notEnoughEvidence,
      manualReviewNotes: [
        'requiresManualReview=true; never invent ratings or portfolio.',
        'Advisory only — never hire or message automatically.',
      ],
    },
  };
}

function mockServiceListingStructuredData(request, topic) {
  const ctx = mergeCtx(request);
  const existing = isObject(ctx.serviceListing)
    ? ctx.serviceListing
    : isObject(ctx.service)
      ? ctx.service
      : isObject(ctx.currentDraft)
        ? ctx.currentDraft
        : {};
  const knownSkills = stringArray(
    existing.linkedSkills || ctx.linkedSkills || ctx.skills || ctx.knownSkills || [],
  );
  const knownCertIds = stringArray(
    existing.linkedCertificateIds ||
      ctx.linkedCertificateIds ||
      ctx.certificateIds ||
      ctx.knownCertificateIds ||
      [],
  );
  const knownPortfolio = stringArray(
    existing.portfolioLinks || ctx.portfolioLinks || ctx.allowedUrls || [],
  );
  const knownCover = stringOrEmpty(existing.coverImageUrl || ctx.coverImageUrl);
  const knownGallery = stringArray(existing.galleryUrls || ctx.galleryUrls || []);
  const skillScore =
    typeof existing.skillScore === 'number'
      ? existing.skillScore
      : typeof ctx.platformSkillScore === 'number'
        ? ctx.platformSkillScore
        : typeof ctx.skillScore === 'number'
          ? ctx.skillScore
          : null;

  const isImprove = request.taskType === 'freelancerServiceListingImprover';
  const title =
    stringOrEmpty(existing.title) ||
    (isImprove ? `Improved: ${topic}` : `Professional ${topic} service`);
  const shortDescription =
    stringOrEmpty(existing.shortDescription) ||
    `Clear, client-ready ${topic} offering with defined scope and delivery.`;
  const fullDescription =
    stringOrEmpty(existing.fullDescription) ||
    `This draft service listing covers ${topic}. Scope, deliverables, and timeline are placeholders for the freelancer to review before publishing. No order, payment, or publish action was performed.`;

  return {
    serviceListing: {
      title,
      shortDescription,
      fullDescription,
      category: stringOrEmpty(existing.category || ctx.category) || 'General',
      tags: stringArray(existing.tags || ctx.tags).length
        ? stringArray(existing.tags || ctx.tags)
        : topic
            .split(/[\s,]+/)
            .map((t) => t.trim())
            .filter(Boolean)
            .slice(0, 5),
      pricingType:
        existing.pricingType === 'hourly' || existing.pricingType === 'fixed'
          ? existing.pricingType
          : 'fixed',
      startingPrice:
        typeof existing.startingPrice === 'number' && Number.isFinite(existing.startingPrice)
          ? existing.startingPrice
          : 50,
      estimatedDelivery:
        stringOrEmpty(existing.estimatedDelivery) || '3-5 business days',
      currency: stringOrEmpty(existing.currency || ctx.currency) || 'USD',
      packages: Array.isArray(existing.packages) && existing.packages.length
        ? existing.packages
        : [
            {
              title: 'Starter',
              price: 50,
              deliveryDays: 3,
              revisionsIncluded: 1,
              description: `Basic ${topic} package for a focused deliverable.`,
            },
            {
              title: 'Standard',
              price: 120,
              deliveryDays: 5,
              revisionsIncluded: 2,
              description: `Full ${topic} package with clearer scope and one extra revision.`,
            },
            {
              title: 'Premium',
              price: 250,
              deliveryDays: 7,
              revisionsIncluded: 3,
              description: `Expanded ${topic} package for higher-detail work. Review pricing before publish.`,
            },
          ],
      coverImageUrl: knownCover,
      galleryUrls: knownGallery,
      portfolioLinks: knownPortfolio,
      linkedSkills: knownSkills,
      linkedCertificateIds: knownCertIds,
      skillScore,
      suggestedVerifiedBadge: false,
      assumptions: [
        'Draft is for human review only; freelancer must edit before Save Draft or Publish.',
        'Pricing and delivery estimates are suggestions, not guarantees.',
      ],
      missingInputs: [
        ...(knownCover ? [] : ['coverImageUrl not provided in context']),
        ...(knownGallery.length ? [] : ['galleryUrls not provided in context']),
        ...(knownPortfolio.length ? [] : ['portfolioLinks not provided in context']),
        ...(knownSkills.length ? [] : ['linkedSkills not provided in context']),
        ...(knownCertIds.length ? [] : ['linkedCertificateIds not provided in context']),
        ...(skillScore == null ? ['skillScore not provided in context'] : []),
      ],
      manualReviewNotes: [
        'requiresManualReview=true; proposedAction=null; no Firestore writes.',
        'Never invent cover/gallery/portfolio URLs, certificate IDs, or set verifiedBadge=true.',
        'Apply fills editor fields only; Publish/Save Draft remain user actions.',
      ],
    },
  };
}

function messageFor(taskType, topic) {
  if (SERVICE_LISTING_TASKS.has(taskType)) {
    return `Mock service listing draft for: ${topic}\n\nReview every field, then Apply manually. Nothing was published or saved.`;
  }
  return `Mock AI draft for ${taskType}: ${topic}\n\nReview, Apply to the form, then submit yourself. Nothing was executed.`;
}

function titleFor(taskType) {
  if (taskType === 'freelancerServiceListingBuilder') return 'Service Listing Draft';
  if (taskType === 'freelancerServiceListingImprover') return 'Service Listing Improvement';
  if (taskType === 'customerServiceRequestDraft') return 'Service Request Draft';
  if (taskType === 'freelancerProposalDraft') return 'Proposal Draft';
  if (taskType === 'freelancerDeliveryNoteBuilder') return 'Delivery Note Draft';
  if (taskType === 'customerDeliveryAcceptanceChecklist') return 'Acceptance Checklist';
  if (taskType === 'customerFreelancerComparison') return 'Freelancer Comparison';
  if (taskType === 'freelancerProfileImprover') return 'Profile Improvement Draft';
  if (taskType.startsWith('teacher')) return 'Teacher AI Draft';
  if (taskType.startsWith('student')) return 'Student Tutor Draft';
  if (taskType.startsWith('company')) return 'Hiring AI Draft';
  if (taskType.startsWith('admin')) return 'Admin Recommendation Draft';
  if (taskType.startsWith('freelancer')) return 'Freelancer Draft';
  if (taskType.startsWith('customer')) return 'Customer Draft';
  return 'SkillForge AI Draft';
}

function titleForKey(key) {
  return key
    .replace(/([A-Z])/g, ' $1')
    .replace(/^./, (c) => c.toUpperCase())
    .trim();
}

function mergeCtx(request) {
  return {
    ...(isObject(request.safeAppContext) ? request.safeAppContext : {}),
    ...(isObject(request.pageContext) ? request.pageContext : {}),
  };
}

function isObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value);
}

function stringOrEmpty(value) {
  return typeof value === 'string' && value.trim() ? value.trim() : '';
}

function stringArray(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => (typeof item === 'string' ? item.trim() : String(item || '').trim()))
    .filter(Boolean)
    .slice(0, 20);
}
