import '../../models/resolution_case_model.dart';
import '../../models/service_order_model.dart';

class ResolutionLawRecommendation {
  const ResolutionLawRecommendation({
    required this.lawId,
    required this.lawTitle,
    required this.recommendedAction,
    required this.summary,
  });

  final String lawId;
  final String lawTitle;
  final String recommendedAction;
  final String summary;

  Map<String, dynamic> toJson() {
    return {
      'lawId': lawId,
      'lawTitle': lawTitle,
      'aiRecommendationStatus': ResolutionAiRecommendationStatus.generated,
      'aiRecommendedAction': recommendedAction,
      'aiSummary': summary,
    };
  }
}

class ResolutionLawEngineService {
  const ResolutionLawEngineService();

  ResolutionLawRecommendation generateRecommendation({
    required ResolutionCaseModel resolutionCase,
    required ServiceOrderModel order,
  }) {
    final deliverySubmitted =
        order.orderStatus == ServiceOrderStatus.delivered &&
        order.deliveryStatus == ServiceOrderDeliveryStatus.submitted &&
        (order.lastDeliveryId ?? '').trim().isNotEmpty;
    final clientEvidence = resolutionCase.clientEvidenceCount;
    final freelancerEvidence = resolutionCase.freelancerEvidenceCount;
    final openedByFreelancer =
        resolutionCase.openedByRole == 'freelancer' ||
        resolutionCase.requestedByRole == 'freelancer';

    if (resolutionCase.type == ResolutionCaseType.refund &&
        !deliverySubmitted &&
        freelancerEvidence == 0) {
      return const ResolutionLawRecommendation(
        lawId: 'law_refund_before_delivery',
        lawTitle: 'Refund Before Delivery',
        recommendedAction: ResolutionDecision.refundToClient,
        summary:
            'Client requested refund before delivery and no freelancer evidence is recorded. Client safety has stronger weight; admin may still request freelancer evidence before deciding.',
      );
    }

    if (resolutionCase.type == ResolutionCaseType.refund &&
        !deliverySubmitted &&
        freelancerEvidence > 0) {
      return const ResolutionLawRecommendation(
        lawId: 'law_partial_work_split',
        lawTitle: 'Partial Work Evidence',
        recommendedAction: ResolutionDecision.splitRelease,
        summary:
            'No delivery is submitted, but freelancer evidence exists. Review work proof and consider split settlement if partial work has value.',
      );
    }

    if (resolutionCase.type == ResolutionCaseType.dispute &&
        openedByFreelancer &&
        freelancerEvidence == 0) {
      return const ResolutionLawRecommendation(
        lawId: 'law_freelancer_disputes_refund',
        lawTitle: 'Freelancer Disputes Refund',
        recommendedAction: 'requestEvidence',
        summary:
            'Freelancer opened or responded with a dispute but has not added evidence. Request freelancer evidence before settlement.',
      );
    }

    if (deliverySubmitted && clientEvidence == 0) {
      return const ResolutionLawRecommendation(
        lawId: 'law_delivery_submitted_client_proof',
        lawTitle: 'Delivery Submitted',
        recommendedAction: 'requestEvidence',
        summary:
            'Delivery exists, so freelancer has a stronger claim. Client must provide quality or requirement evidence before refund is favored.',
      );
    }

    if (deliverySubmitted && freelancerEvidence > 0 && clientEvidence == 0) {
      return const ResolutionLawRecommendation(
        lawId: 'law_release_after_delivery',
        lawTitle: 'Release After Delivery Evidence',
        recommendedAction: ResolutionDecision.releaseToFreelancer,
        summary:
            'Delivery and freelancer evidence are present, while client evidence is missing. Release may be appropriate if delivery files satisfy the order.',
      );
    }

    return const ResolutionLawRecommendation(
      lawId: 'law_balanced_review',
      lawTitle: 'Balanced Evidence Review',
      recommendedAction: ResolutionDecision.splitRelease,
      summary:
          'Both sides need review. Compare delivery files, client claim, freelancer proof, and order scope. Split is the neutral recommendation when both claims are partially valid.',
    );
  }

  Map<String, dynamic> buildCaseFacts({
    required ResolutionCaseModel resolutionCase,
    required ServiceOrderModel order,
  }) {
    return {
      'caseType': resolutionCase.type,
      'openedByRole': resolutionCase.openedByRole,
      'againstRole': resolutionCase.againstRole,
      'deliverySubmitted':
          order.orderStatus == ServiceOrderStatus.delivered &&
          order.deliveryStatus == ServiceOrderDeliveryStatus.submitted,
      'clientEvidenceCount': resolutionCase.clientEvidenceCount,
      'freelancerEvidenceCount': resolutionCase.freelancerEvidenceCount,
      'paymentStatus': order.paymentStatus,
      'escrowStatus': order.escrowStatus,
      'amount': order.totalAmount,
    };
  }

  String buildAiPromptForFutureUse({
    required ResolutionCaseModel resolutionCase,
    required ServiceOrderModel order,
  }) {
    final facts = buildCaseFacts(resolutionCase: resolutionCase, order: order);
    return 'SkillForge sandbox resolution facts: $facts. Recommend one action, but admin must decide manually.';
  }
}
