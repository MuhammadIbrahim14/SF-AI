import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/freelancer_model.dart';
import '../../../models/freelancer_service_model.dart';
import '../../../providers/firebase_providers.dart';

final freelancerDirectoryProvider =
    StreamProvider<List<FreelancerDirectoryProfile>>((ref) {
      final firestore = ref.watch(firestoreProvider);
      return firestore
          .collection('freelancerServices')
          .where('isPublished', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
            final services = snapshot.docs
                .map(FreelancerServiceModel.fromFirestore)
                .where((service) => service.isLive)
                .toList();

            final byFreelancer = <String, List<FreelancerServiceModel>>{};
            for (final service in services) {
              if (service.freelancerId.trim().isEmpty) continue;
              byFreelancer
                  .putIfAbsent(
                    service.freelancerId,
                    () => <FreelancerServiceModel>[],
                  )
                  .add(service);
            }

            final profiles = byFreelancer.entries
                .map(
                  (entry) =>
                      FreelancerDirectoryProfile.fromServices(entry.value),
                )
                .where((profile) => profile.isVisible)
                .toList();

            profiles.sort(
              (a, b) => b.profileStrength.compareTo(a.profileStrength),
            );
            return profiles;
          });
    });

class FreelancerDirectoryProfile {
  const FreelancerDirectoryProfile({
    required this.freelancer,
    required this.displayName,
    required this.avatarUrl,
  });

  final FreelancerModel freelancer;
  final String displayName;
  final String? avatarUrl;

  String get userId => freelancer.userId;

  factory FreelancerDirectoryProfile.fromServices(
    List<FreelancerServiceModel> services,
  ) {
    final liveServices = services.where((service) => service.isLive).toList()
      ..sort(
        (a, b) => (b.publishedAt ?? b.updatedAt).compareTo(
          a.publishedAt ?? a.updatedAt,
        ),
      );
    final primary = liveServices.isNotEmpty
        ? liveServices.first
        : services.first;
    final tags = <String>{
      ...liveServices.expand((service) => service.tags),
      ...liveServices.expand((service) => service.linkedSkills),
    }.where((item) => item.trim().isNotEmpty).toList();
    final categories = liveServices
        .map((service) => service.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();
    final portfolioLinks = <String>{
      ...liveServices.expand((service) => service.portfolioLinks),
    }.where((link) => link.trim().isNotEmpty).toList();
    final hourlyServices = liveServices.where(
      (service) => service.pricingType == FreelancerServicePricingType.hourly,
    );
    final hourlyRate = hourlyServices.isEmpty
        ? 0.0
        : hourlyServices
              .map((service) => service.startingPrice)
              .where((price) => price > 0)
              .fold<double>(0, (max, price) => price > max ? price : max);
    final skillScore = liveServices
        .map((service) => service.skillScore)
        .where((score) => score > 0)
        .toList();

    final freelancer = FreelancerModel(
      userId: primary.freelancerId,
      professionalTitle: primary.title.trim().isNotEmpty
          ? primary.title.trim()
          : 'Verified Service Professional',
      category: primary.category.trim().isNotEmpty
          ? primary.category.trim()
          : (categories.isNotEmpty ? categories.first : ''),
      services: liveServices
          .map((service) => service.title.trim())
          .where((title) => title.isNotEmpty)
          .toSet()
          .toList(),
      bio: primary.shortDescription.trim().isNotEmpty
          ? primary.shortDescription.trim()
          : primary.fullDescription.trim(),
      skills: tags,
      portfolioLinks: portfolioLinks,
      completedGigs: 0,
      rating: skillScore.isEmpty
          ? 0
          : (skillScore.reduce((a, b) => a + b) / skillScore.length) / 20,
      hourlyRate: hourlyRate,
    );

    final name = primary.freelancerName.trim();
    return FreelancerDirectoryProfile(
      freelancer: freelancer,
      displayName: name.isEmpty ? 'Verified Freelancer' : name,
      avatarUrl: primary.freelancerAvatarUrl.trim().isEmpty
          ? null
          : primary.freelancerAvatarUrl.trim(),
    );
  }

  String get email => '';
  String get location => '';

  bool get isVisible {
    return freelancer.professionalTitle.trim().isNotEmpty ||
        freelancer.services.isNotEmpty ||
        freelancer.skills.isNotEmpty ||
        freelancer.category.trim().isNotEmpty;
  }

  List<String> get searchableTerms {
    return [
      displayName,
      email,
      freelancer.professionalTitle,
      freelancer.category,
      freelancer.bio,
      ...freelancer.services,
      ...freelancer.skills,
      ...freelancer.portfolioLinks,
    ];
  }

  int get portfolioLinksCount {
    final links = {
      ...freelancer.portfolioLinks,
      freelancer.portfolio,
      freelancer.linkedin,
      freelancer.github,
      freelancer.behance,
      freelancer.dribbble,
      freelancer.website,
    }..removeWhere((link) => link.trim().isEmpty);
    return links.length;
  }

  int get profileStrength {
    var score = 0;
    if (displayName.trim().isNotEmpty) score += 8;
    if ((avatarUrl ?? '').trim().isNotEmpty) score += 8;
    if (freelancer.professionalTitle.trim().isNotEmpty) score += 12;
    if (freelancer.category.trim().isNotEmpty) score += 8;
    if (freelancer.services.isNotEmpty) score += 12;
    if (freelancer.services.length >= 3) score += 8;
    if (freelancer.skills.isNotEmpty) score += 10;
    if (freelancer.skills.length >= 5) score += 8;
    if (freelancer.hourlyRate > 0) score += 8;
    if (freelancer.experienceYears > 0) score += 8;
    if (portfolioLinksCount > 0) score += 8;
    if (portfolioLinksCount >= 2) score += 5;
    if (freelancer.bio.trim().isNotEmpty) score += 10;
    return score.clamp(0, 100);
  }

  bool matchesSearch(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return searchableTerms.any(
      (term) => term.trim().toLowerCase().contains(normalized),
    );
  }
}
