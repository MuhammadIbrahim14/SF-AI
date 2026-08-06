import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/freelancer_model.dart';
import '../../../models/freelancer_service_model.dart';
import '../models/marketplace_ai_draft_models.dart';

/// Hydrates Firestore docs for marketplace AI `safeAppContext`.
class MarketplaceAiContextLoader {
  MarketplaceAiContextLoader({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<Map<String, dynamic>> hydrateIds({
    String? serviceId,
    String? requestId,
    String? serviceRequestId,
    String? orderId,
    String? caseId,
  }) async {
    final context = <String, dynamic>{
      'manualReviewRequired': true,
      'noDatabaseWrites': true,
      'noPaymentOrSettlementExecution': true,
    };

    final resolvedServiceId = (serviceId ?? '').trim();
    final resolvedRequestId = (requestId ?? serviceRequestId ?? '').trim();
    final resolvedOrderId = (orderId ?? '').trim();
    final resolvedCaseId = (caseId ?? '').trim();

    if (resolvedServiceId.isNotEmpty) {
      context['serviceId'] = resolvedServiceId;
      final service = await _loadService(resolvedServiceId);
      if (service != null) {
        context['service'] = _safeService(service);
      }
    }

    if (resolvedRequestId.isNotEmpty) {
      context['requestId'] = resolvedRequestId;
      context['serviceRequestId'] = resolvedRequestId;
      final request = await _loadDoc('serviceRequests', resolvedRequestId);
      if (request != null) {
        context['serviceRequest'] = _safeMap(request);
      }
    }

    if (resolvedOrderId.isNotEmpty) {
      context['orderId'] = resolvedOrderId;
      final order = await _loadDoc('serviceOrders', resolvedOrderId);
      if (order != null) {
        context['serviceOrder'] = _safeMap(order);
      }
    }

    if (resolvedCaseId.isNotEmpty) {
      context['caseId'] = resolvedCaseId;
      final resolutionCase = await _loadDoc('resolutionCases', resolvedCaseId);
      if (resolutionCase != null) {
        context['resolutionCase'] = _safeMap(resolutionCase);
      }
    }

    return context;
  }

  /// Context for Create/Improve service listing dialogs.
  Map<String, dynamic> buildServiceListingContext({
    required String freelancerId,
    required String freelancerName,
    FreelancerModel? freelancer,
    FreelancerServiceModel? existingService,
    Map<String, dynamic>? draftFields,
    String? serviceId,
    double? platformSkillScore,
    List<String> knownCertificateIds = const [],
  }) {
    final portfolioLinks = <String>{
      ...?freelancer?.portfolioLinks,
      if ((freelancer?.portfolio ?? '').trim().isNotEmpty)
        freelancer!.portfolio.trim(),
      if ((freelancer?.linkedin ?? '').trim().isNotEmpty)
        freelancer!.linkedin.trim(),
      if ((freelancer?.github ?? '').trim().isNotEmpty) freelancer!.github.trim(),
      if ((freelancer?.behance ?? '').trim().isNotEmpty)
        freelancer!.behance.trim(),
      if ((freelancer?.dribbble ?? '').trim().isNotEmpty)
        freelancer!.dribbble.trim(),
      if ((freelancer?.website ?? '').trim().isNotEmpty)
        freelancer!.website.trim(),
      ...?existingService?.portfolioLinks,
      if ((existingService?.coverImageUrl ?? '').trim().isNotEmpty)
        existingService!.coverImageUrl.trim(),
      ...?existingService?.galleryUrls,
    }.where((item) => item.trim().isNotEmpty).toList();

    final skills = <String>{
      ...?freelancer?.skills,
      ...?existingService?.linkedSkills,
    }.where((item) => item.trim().isNotEmpty).toList();

    final certIds = <String>{
      ...knownCertificateIds,
      ...?existingService?.linkedCertificateIds,
    }.where((item) => item.trim().isNotEmpty).toList();

    final score =
        platformSkillScore ??
        (existingService != null && existingService.skillScore > 0
            ? existingService.skillScore
            : null);

    return {
      'freelancerId': freelancerId,
      'freelancerName': freelancerName,
      if ((serviceId ?? existingService?.serviceId ?? '').trim().isNotEmpty)
        'serviceId': (serviceId ?? existingService?.serviceId)!.trim(),
      if (freelancer != null) 'freelancerProfile': _safeFreelancer(freelancer),
      if (existingService != null) 'service': _safeService(existingService),
      if (draftFields != null && draftFields.isNotEmpty)
        'currentDraft': draftFields,
      'knownSkills': skills,
      'knownCertificateIds': certIds,
      'allowedUrls': portfolioLinks,
      'platformSkillScore': ?score,
      'manualReviewRequired': true,
      'noDatabaseWrites': true,
      'noPaymentOrSettlementExecution': true,
      'neverAutoPublish': true,
      'neverSetVerifiedBadgeFromAi': true,
    };
  }

  MarketplaceAiKnownEvidence evidenceFromContext(Map<String, dynamic> context) {
    final packages = <String>[];
    final service = context['service'];
    if (service is Map) {
      final rawPackages = service['packages'];
      if (rawPackages is Iterable) {
        for (final item in rawPackages) {
          if (item is Map) {
            final id = (item['packageId'] ?? item['id'] ?? '').toString();
            if (id.trim().isNotEmpty) packages.add(id.trim());
          }
        }
      }
    }
    return MarketplaceAiKnownEvidence(
      knownSkills: _stringList(context['knownSkills']),
      knownCertificateIds: _stringList(context['knownCertificateIds']),
      allowedUrls: _stringList(context['allowedUrls']),
      knownPackageIds: [
        ...packages,
        ..._stringList(context['knownPackageIds']),
      ],
      platformSkillScore: _doubleOrNull(context['platformSkillScore']),
      clientName: (context['clientName'] ?? '').toString(),
      clientEmail: (context['clientEmail'] ?? '').toString(),
    );
  }

  Future<FreelancerServiceModel?> _loadService(String serviceId) async {
    final snap = await _firestore
        .collection('freelancerServices')
        .doc(serviceId)
        .get();
    if (!snap.exists) return null;
    return FreelancerServiceModel.fromFirestore(snap);
  }

  Future<Map<String, dynamic>?> _loadDoc(
    String collection,
    String docId,
  ) async {
    final snap = await _firestore.collection(collection).doc(docId).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return Map<String, dynamic>.from(data)..putIfAbsent('id', () => snap.id);
  }

  Map<String, dynamic> _safeService(FreelancerServiceModel service) {
    return _safeMap({
      'serviceId': service.serviceId,
      'freelancerId': service.freelancerId,
      'title': service.title,
      'shortDescription': service.shortDescription,
      'fullDescription': service.fullDescription,
      'category': service.category,
      'tags': service.tags,
      'pricingType': service.pricingType,
      'startingPrice': service.startingPrice,
      'estimatedDelivery': service.estimatedDelivery,
      'packages': service.packages.map((item) => item.toJson()).toList(),
      'currency': service.currency,
      'coverImageUrl': service.coverImageUrl,
      'galleryUrls': service.galleryUrls,
      'portfolioLinks': service.portfolioLinks,
      'linkedCertificateIds': service.linkedCertificateIds,
      'linkedSkills': service.linkedSkills,
      'skillScore': service.skillScore,
      'status': service.status,
      'isPublished': service.isPublished,
    });
  }

  Map<String, dynamic> _safeFreelancer(FreelancerModel freelancer) {
    return {
      'userId': freelancer.userId,
      'professionalTitle': freelancer.professionalTitle,
      'category': freelancer.category,
      'bio': freelancer.bio,
      'skills': freelancer.skills,
      'services': freelancer.services,
      'portfolioLinks': freelancer.portfolioLinks,
      'portfolio': freelancer.portfolio,
      'hourlyRate': freelancer.hourlyRate,
    };
  }

  Map<String, dynamic> _safeMap(Map<String, dynamic> input) {
    final out = <String, dynamic>{};
    input.forEach((key, value) {
      final converted = _jsonSafe(value);
      if (converted != null) out[key] = converted;
    });
    return out;
  }

  Object? _jsonSafe(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is num || value is bool || value is String) return value;
    if (value is Iterable) {
      return value.map(_jsonSafe).where((item) => item != null).toList();
    }
    if (value is Map) {
      final map = <String, dynamic>{};
      value.forEach((key, nested) {
        final converted = _jsonSafe(nested);
        if (converted != null) map[key.toString()] = converted;
      });
      return map;
    }
    return value.toString();
  }
}

List<String> _stringList(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

double? _doubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}
