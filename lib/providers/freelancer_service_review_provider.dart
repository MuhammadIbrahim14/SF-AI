import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/freelancer_service_review_model.dart';
import '../repositories/freelancer_service_review_repository.dart';
import '../repositories/freelancer_service_review_repository_impl.dart';
import 'firebase_providers.dart';
import 'repository_providers.dart';

final freelancerServiceReviewRepositoryProvider =
    Provider<FreelancerServiceReviewRepository>((ref) {
      return FreelancerServiceReviewRepositoryImpl(
        ref.watch(firestoreProvider),
      );
    });

final visibleServiceReviewsProvider =
    StreamProvider<List<FreelancerServiceReviewModel>>((ref) {
      return ref
          .watch(freelancerServiceReviewRepositoryProvider)
          .watchVisibleReviews();
    });

final serviceReviewsProvider =
    StreamProvider.family<List<FreelancerServiceReviewModel>, String>((
      ref,
      serviceId,
    ) {
      if (serviceId.trim().isEmpty) {
        return Stream.value(const <FreelancerServiceReviewModel>[]);
      }
      return ref
          .watch(freelancerServiceReviewRepositoryProvider)
          .watchServiceReviews(serviceId);
    });

final freelancerReviewsProvider =
    StreamProvider.family<List<FreelancerServiceReviewModel>, String>((
      ref,
      freelancerId,
    ) {
      if (freelancerId.trim().isEmpty) {
        return Stream.value(const <FreelancerServiceReviewModel>[]);
      }
      return ref
          .watch(freelancerServiceReviewRepositoryProvider)
          .watchFreelancerReviews(freelancerId);
    });

final requestReviewProvider =
    StreamProvider.family<FreelancerServiceReviewModel?, String>((
      ref,
      requestId,
    ) {
      if (requestId.trim().isEmpty) return Stream.value(null);
      return ref
          .watch(freelancerServiceReviewRepositoryProvider)
          .watchRequestReview(requestId);
    });

final serviceReviewSummaryProvider = Provider.family<ReviewSummary, String>((
  ref,
  serviceId,
) {
  final reviews =
      ref.watch(serviceReviewsProvider(serviceId)).value ??
      const <FreelancerServiceReviewModel>[];
  return reviewSummaryFor(reviews);
});

final freelancerReviewSummaryProvider = Provider.family<ReviewSummary, String>((
  ref,
  freelancerId,
) {
  final reviews =
      ref.watch(freelancerReviewsProvider(freelancerId)).value ??
      const <FreelancerServiceReviewModel>[];
  return reviewSummaryFor(reviews);
});

final allReviewSummariesProvider = Provider<Map<String, ReviewSummary>>((ref) {
  final reviews =
      ref.watch(visibleServiceReviewsProvider).value ??
      const <FreelancerServiceReviewModel>[];
  final grouped = <String, List<FreelancerServiceReviewModel>>{};
  for (final review in reviews) {
    grouped.putIfAbsent(review.serviceId, () => []).add(review);
  }
  return {
    for (final entry in grouped.entries)
      entry.key: reviewSummaryFor(entry.value),
  };
});

final freelancerServiceReviewActionProvider =
    AsyncNotifierProvider<FreelancerServiceReviewActionNotifier, void>(
      FreelancerServiceReviewActionNotifier.new,
    );

class FreelancerServiceReviewActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createReview(FreelancerServiceReviewModel review) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('Please log in to leave a review.');
      if (review.clientId != user.uid) {
        throw StateError('You can only submit your own review.');
      }
      await ref
          .read(freelancerServiceReviewRepositoryProvider)
          .createReview(review);
    });
    return !state.hasError;
  }

  String? get errorMessage => state.error?.toString();
}

ReviewSummary reviewSummaryFor(List<FreelancerServiceReviewModel> reviews) {
  final visible = reviews.where((review) => review.isVisible).toList();
  if (visible.isEmpty) return ReviewSummary.empty;
  final total = visible.fold<int>(0, (sum, review) => sum + review.rating);
  return ReviewSummary(
    averageRating: total / visible.length,
    reviewCount: visible.length,
  );
}
