import '../../../models/user_model.dart';
import '../models/copilot_guided_action_model.dart';
import '../models/copilot_intent_model.dart';
import 'copilot_route_catalog.dart';

class CopilotGuidedActionService {
  const CopilotGuidedActionService();

  CopilotGuidedActionModel buildGuidedAction({
    required CopilotIntentModel intent,
    required UserModel? user,
  }) {
    final role = _roleFor(user);
    final prefill = _extractPrefill(intent.rawText);

    if (intent.actionLevel == CopilotActionLevel.sensitive) {
      return buildSensitiveActionWarning(intent, role: role);
    }

    if (user == null) {
      return _blocked(
        intent,
        role: role,
        title: 'Sign in required',
        description: 'This guided workflow belongs to a private workspace.',
        blockedReason: 'Please sign in before starting this workflow.',
      );
    }

    if (user.isCustomerAccount) {
      return _customer(intent, role: role, prefill: prefill);
    }

    switch (_normalize(user.primaryRole)) {
      case 'freelancer':
        return _freelancer(intent, role: role, prefill: prefill);
      case 'teacher':
        return _teacher(intent, role: role, prefill: prefill);
      case 'company':
        return _company(intent, role: role, prefill: prefill);
      case 'admin':
      case 'superadmin':
        return _admin(intent, role: role, prefill: prefill);
      default:
        return _blocked(
          intent,
          role: role,
          title: 'Guided action unavailable',
          description: 'I could not match this workflow to your workspace.',
          blockedReason:
              'Select the correct role workspace, then ask Copilot again.',
        );
    }
  }

  CopilotGuidedActionModel buildSensitiveActionWarning(
    CopilotIntentModel intent, {
    required String role,
  }) {
    final settlement =
        intent.type == CopilotIntentType.releaseEscrow ||
        intent.type == CopilotIntentType.splitSettlement;
    return _blocked(
      intent,
      role: role,
      title: settlement ? 'Settlement Backend Paused' : 'Manual Confirmation',
      description: settlement
          ? 'Release/Split settlement cannot be executed by Copilot.'
          : 'This action needs a real user review and confirmation.',
      blockedReason: settlement
          ? 'Backend executor required. Enable Blaze and deploy Cloud Functions to activate Release/Split.'
          : 'Copilot can guide you to the page, but it cannot perform payments, refunds, payouts, case resolution, bans, deletes, or admin enforcement.',
      safetyMessage:
          'Sensitive workflow protected. No form was submitted and no data was changed.',
      nextSteps: settlement
          ? const [
              'Open the Admin Resolution Desk if you need to review the case.',
              'Use refund only if the current demo mode supports it safely.',
              'Enable Blaze and deploy the backend executor before Release/Split.',
            ]
          : const [
              'Open the related page manually.',
              'Review all details yourself.',
              'Confirm only from the real app form if you are sure.',
            ],
    );
  }

  CopilotGuidedActionModel _customer(
    CopilotIntentModel intent, {
    required String role,
    required Map<String, String> prefill,
  }) {
    switch (intent.type) {
      case CopilotIntentType.guideRefundRequest:
        return _action(
          intent,
          role: role,
          routeId: 'customerResolution',
          title: 'Request Refund',
          description:
              'I will open Resolution Center. Select the order and submit the refund manually.',
          safety:
              'I cannot submit refund requests or move wallet funds automatically.',
          prefill: prefill,
          steps: const [
            'Open the related order from My Orders if needed.',
            'Select Request refund.',
            'Add refund reason and evidence if available.',
            'Review everything and submit manually.',
          ],
        );
      case CopilotIntentType.guideOpenDispute:
        return _action(
          intent,
          role: role,
          routeId: 'customerResolution',
          title: 'Open Dispute',
          description:
              'I will open Resolution Center. Choose the order and create the dispute manually.',
          safety: 'I cannot open a dispute automatically.',
          prefill: prefill,
          steps: const [
            'Open the order with the issue.',
            'Choose Open dispute.',
            'Describe the issue clearly.',
            'Attach evidence if available and submit manually.',
          ],
        );
      case CopilotIntentType.guideRequestRevision:
        return _action(
          intent,
          role: role,
          routeId: 'customerResolution',
          title: 'Request Revision',
          description:
              'I will open the resolution area. Request changes from the order manually.',
          safety: 'I cannot request a revision automatically.',
          prefill: prefill,
          steps: const [
            'Open the delivered order.',
            'Choose Request revision.',
            'Explain the exact changes needed.',
            'Submit manually after review.',
          ],
        );
      case CopilotIntentType.guideAddEvidence:
        return _action(
          intent,
          role: role,
          routeId: 'customerResolution',
          title: 'Add Evidence',
          description:
              'I will open your cases. Choose the active case and add evidence manually.',
          safety: 'I cannot upload or submit evidence automatically.',
          prefill: prefill,
          steps: const [
            'Open the active case.',
            'Choose Add evidence.',
            'Paste links/notes or attach proof if the screen supports it.',
            'Save manually.',
          ],
        );
      case CopilotIntentType.guideOpenWalletTopUp:
        return _action(
          intent,
          role: role,
          routeId: 'customerWallet',
          title: 'Wallet Top-up Help',
          description: 'I will open your sandbox wallet.',
          safety: 'I cannot add balance or submit top-up automatically.',
          steps: const [
            'Review your current sandbox balance.',
            'Choose the top-up option if available.',
            'Enter the amount yourself.',
            'Confirm manually from the wallet screen.',
          ],
        );
      case CopilotIntentType.guideCreateServiceRequest:
        return _action(
          intent,
          role: role,
          routeId: 'servicesMarketplace',
          title: 'Create Service Request',
          description:
              'I will open the services marketplace. Pick a service and submit the request manually.',
          safety: 'I cannot create project requests automatically.',
          prefill: prefill,
          steps: const [
            'Choose a freelancer service.',
            'Open the service details.',
            'Click Request Service.',
            'Fill project details and submit manually.',
          ],
        );
      case CopilotIntentType.guideContactSupport:
        return _support(intent, role: role, prefill: prefill);
      default:
        return _blockedForWorkspace(intent, role);
    }
  }

  CopilotGuidedActionModel _freelancer(
    CopilotIntentModel intent, {
    required String role,
    required Map<String, String> prefill,
  }) {
    switch (intent.type) {
      case CopilotIntentType.guideSubmitDelivery:
        return _action(
          intent,
          role: role,
          routeId: 'freelancerOrders',
          title: 'Submit Delivery',
          description:
              'I will open your orders. Open the right order and submit delivery manually.',
          safety:
              'I cannot submit delivery or files without your confirmation.',
          prefill: prefill,
          steps: const [
            'Open the order you want to deliver.',
            'Click Submit Delivery.',
            'Add delivery message, links, or files.',
            'Review and submit manually.',
          ],
        );
      case CopilotIntentType.guideAddEvidence:
      case CopilotIntentType.guideOpenDispute:
        return _action(
          intent,
          role: role,
          routeId: 'freelancerResolution',
          title: intent.type == CopilotIntentType.guideAddEvidence
              ? 'Add Evidence'
              : 'Open Dispute',
          description:
              'I will open Freelancer Resolution Center. Choose the case or order manually.',
          safety: 'I cannot submit disputes or evidence automatically.',
          prefill: prefill,
          steps: const [
            'Open the relevant resolution case.',
            'Review the order and evidence history.',
            'Add your note/proof if needed.',
            'Submit manually.',
          ],
        );
      case CopilotIntentType.guidePayoutRequest:
        return _action(
          intent,
          role: role,
          routeId: 'freelancerPayouts',
          title: 'Create Payout Request',
          description: 'I will open Withdrawal Center.',
          safety:
              'I cannot withdraw funds or create a payout request automatically.',
          steps: const [
            'Check available balance.',
            'Enter amount and sandbox destination.',
            'Review payout details.',
            'Submit manually for admin review.',
          ],
        );
      case CopilotIntentType.guideManageServiceRequests:
        return _action(
          intent,
          role: role,
          routeId: 'freelancerServiceRequests',
          title: 'Manage Service Requests',
          description: 'I will open your client service requests.',
          safety: 'I cannot accept/reject requests automatically.',
          steps: const [
            'Open the request.',
            'Read project requirements.',
            'Accept, reject, or continue manually.',
          ],
        );
      case CopilotIntentType.guideUpdateServicePackages:
        return _action(
          intent,
          role: role,
          routeId: 'freelancerServices',
          title: 'Update Service Packages',
          description: 'I will open your Service Studio.',
          safety: 'I cannot publish or edit services automatically.',
          steps: const [
            'Open the service you want to edit.',
            'Update pricing/package details.',
            'Save draft or publish manually.',
          ],
        );
      case CopilotIntentType.guideContactSupport:
        return _support(intent, role: role, prefill: prefill);
      default:
        return _blockedForWorkspace(intent, role);
    }
  }

  CopilotGuidedActionModel _teacher(
    CopilotIntentModel intent, {
    required String role,
    required Map<String, String> prefill,
  }) {
    switch (intent.type) {
      case CopilotIntentType.guideCreateCourse:
        return _action(
          intent,
          role: role,
          routeId: 'teacherCourseCreate',
          title: 'Create Course',
          description: 'I will open the course editor.',
          safety: 'I cannot create or publish courses automatically.',
          steps: const [
            'Add course title, details, image, and skills.',
            'Review lessons/structure.',
            'Save draft or publish manually.',
          ],
        );
      case CopilotIntentType.guideManageCourse:
      case CopilotIntentType.guideCreateCertificate:
        return _action(
          intent,
          role: role,
          routeId: 'teacherCourses',
          title: intent.type == CopilotIntentType.guideCreateCertificate
              ? 'Manage Certificates'
              : 'Manage Courses',
          description: 'I will open Teacher Courses.',
          safety:
              'I cannot issue certificates, edit courses, or publish changes automatically.',
          steps: const [
            'Open the course.',
            'Choose lessons, assignments, grand tests, or certificates.',
            'Review eligibility/details.',
            'Save or issue manually.',
          ],
        );
      case CopilotIntentType.guideContactSupport:
        return _support(intent, role: role, prefill: prefill);
      default:
        return _blockedForWorkspace(intent, role);
    }
  }

  CopilotGuidedActionModel _company(
    CopilotIntentModel intent, {
    required String role,
    required Map<String, String> prefill,
  }) {
    switch (intent.type) {
      case CopilotIntentType.guidePostJob:
        return _action(
          intent,
          role: role,
          routeId: 'createJob',
          title: 'Post a Job',
          description: 'I will open the job editor.',
          safety: 'I cannot create or publish jobs automatically.',
          steps: const [
            'Add role title, skills, requirements, and eligibility.',
            'Review matching settings.',
            'Save or publish manually.',
          ],
        );
      case CopilotIntentType.guideReviewApplications:
        return _action(
          intent,
          role: role,
          routeId: 'hiringPipeline',
          title: 'Review Applications',
          description: 'I will open the hiring pipeline.',
          safety:
              'I cannot select, reject, hire, or schedule candidates automatically.',
          steps: const [
            'Open the candidate/application.',
            'Review match score, resume, and evidence.',
            'Choose the next hiring action manually.',
          ],
        );
      case CopilotIntentType.guideContactSupport:
        return _support(intent, role: role, prefill: prefill);
      default:
        return _blockedForWorkspace(intent, role);
    }
  }

  CopilotGuidedActionModel _admin(
    CopilotIntentModel intent, {
    required String role,
    required Map<String, String> prefill,
  }) {
    switch (intent.type) {
      case CopilotIntentType.guideReviewResolutionCase:
      case CopilotIntentType.guideRequestEvidence:
        return _action(
          intent,
          role: role,
          routeId: 'adminResolutionDesk',
          title: intent.type == CopilotIntentType.guideRequestEvidence
              ? 'Request Evidence'
              : 'Review Resolution Case',
          description: 'I will open Admin Resolution Desk.',
          safety:
              'I cannot resolve cases, refund, release, or split settlement automatically.',
          prefill: prefill,
          steps: const [
            'Open the case.',
            'Review order state, delivery, and evidence.',
            'Request evidence or choose action manually.',
            'Release/Split remains backend-pending until Cloud Functions are deployed.',
          ],
        );
      case CopilotIntentType.guideReviewPayout:
        return _action(
          intent,
          role: role,
          routeId: 'adminPayouts',
          title: 'Review Payout',
          description: 'I will open the Admin Payout Queue.',
          safety: 'I cannot approve, reject, process, or mark payouts paid.',
          steps: const [
            'Open the payout request.',
            'Review freelancer and wallet status.',
            'Approve/reject/process manually if policy allows.',
          ],
        );
      case CopilotIntentType.guideManageLaw:
        return _action(
          intent,
          role: role,
          routeId: 'adminLegal',
          title: 'Manage Policy Content',
          description: 'I will open the admin legal/policy area.',
          safety: 'I cannot modify legal or policy content automatically.',
          steps: const [
            'Choose the policy document.',
            'Review content carefully.',
            'Save manually only after approval.',
          ],
        );
      case CopilotIntentType.guideContactSupport:
        return _support(intent, role: role, prefill: prefill);
      default:
        return _blockedForWorkspace(intent, role);
    }
  }

  CopilotGuidedActionModel _support(
    CopilotIntentModel intent, {
    required String role,
    required Map<String, String> prefill,
  }) {
    return _action(
      intent,
      role: role,
      routeId: 'support',
      title: 'Contact Support',
      description: 'I will open the support form.',
      safety: 'I cannot submit support tickets automatically.',
      prefill: prefill,
      steps: const [
        'Choose the right support category.',
        'Paste the issue details if helpful.',
        'Review your message.',
        'Submit manually.',
      ],
    );
  }

  CopilotGuidedActionModel _action(
    CopilotIntentModel intent, {
    required String role,
    required String routeId,
    required String title,
    required String description,
    required String safety,
    required List<String> steps,
    Map<String, String> prefill = const <String, String>{},
  }) {
    final destination = CopilotRouteCatalog.byId(routeId);
    return CopilotGuidedActionModel(
      id: intent.type,
      title: title,
      description: description,
      intentType: intent.type,
      role: role,
      targetRouteId: routeId,
      targetRoutePath: destination?.path,
      actionLevel: CopilotActionLevel.guidedAction,
      requiresManualSubmit: true,
      requiresConfirmation: false,
      canPrefill: prefill.isNotEmpty,
      prefillData: prefill,
      safetyMessage: safety,
      nextSteps: steps,
      blockedReason: destination == null || !destination.isAvailable
          ? destination?.unavailableReason ??
                'This page is not available in the current build.'
          : null,
    );
  }

  CopilotGuidedActionModel _blockedForWorkspace(
    CopilotIntentModel intent,
    String role,
  ) {
    return _blocked(
      intent,
      role: role,
      title: 'Guided action unavailable',
      description: 'This workflow is not available in the $role workspace.',
      blockedReason: 'Try a workflow that belongs to your current role.',
    );
  }

  CopilotGuidedActionModel _blocked(
    CopilotIntentModel intent, {
    required String role,
    required String title,
    required String description,
    required String blockedReason,
    String safetyMessage =
        'No action was executed. Copilot only guides safe manual workflows.',
    List<String> nextSteps = const <String>[],
  }) {
    return CopilotGuidedActionModel(
      id: intent.type,
      title: title,
      description: description,
      intentType: intent.type,
      role: role,
      actionLevel: intent.actionLevel,
      requiresManualSubmit: true,
      requiresConfirmation: false,
      canPrefill: false,
      blockedReason: blockedReason,
      safetyMessage: safetyMessage,
      nextSteps: nextSteps,
    );
  }
}

Map<String, String> _extractPrefill(String rawText) {
  final normalized = rawText.trim();
  if (normalized.isEmpty) return const <String, String>{};
  final lower = normalized.toLowerCase();
  const markers = [
    'because',
    'due to',
    'reason',
    'issue',
    'masla',
    'kyun ke',
    'q ke',
    'qk',
  ];
  for (final marker in markers) {
    final index = lower.indexOf(marker);
    if (index < 0) continue;
    final value = normalized.substring(index + marker.length).trim();
    if (value.length >= 4) return {'note': value};
  }
  return const <String, String>{};
}

String _roleFor(UserModel? user) {
  if (user == null) return 'guest';
  if (user.isCustomerAccount) return 'customer';
  final role = _normalize(user.primaryRole);
  return role.isEmpty ? 'unknown' : role;
}

String _normalize(String? value) {
  final normalized = (value ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '')
      .trim();
  if (normalized == 'superadmin' || normalized == 'super_admin') {
    return 'superadmin';
  }
  return normalized;
}
