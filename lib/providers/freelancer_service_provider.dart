import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/freelancer_service_model.dart';
import '../repositories/freelancer_service_repository.dart';
import '../repositories/freelancer_service_repository_impl.dart';
import 'auth_provider.dart';
import 'firebase_providers.dart';
import 'repository_providers.dart';

final freelancerServiceRepositoryProvider =
    Provider<FreelancerServiceRepository>((ref) {
      return FreelancerServiceRepositoryImpl(ref.watch(firestoreProvider));
    });

final myFreelancerServicesProvider =
    StreamProvider<List<FreelancerServiceModel>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value(const <FreelancerServiceModel>[]);
      return ref
          .watch(freelancerServiceRepositoryProvider)
          .watchMyServices(user.uid);
    });

final publishedFreelancerServicesProvider =
    StreamProvider<List<FreelancerServiceModel>>((ref) {
      return ref
          .watch(freelancerServiceRepositoryProvider)
          .watchPublishedServices();
    });

final freelancerServiceDetailProvider =
    StreamProvider.family<FreelancerServiceModel?, String>((ref, serviceId) {
      if (serviceId.trim().isEmpty) return Stream.value(null);
      return ref
          .watch(freelancerServiceRepositoryProvider)
          .watchService(serviceId);
    });

final freelancerServiceActionProvider =
    AsyncNotifierProvider<FreelancerServiceActionNotifier, void>(
      FreelancerServiceActionNotifier.new,
    );

class FreelancerServiceActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> createService(FreelancerServiceModel service) async {
    state = const AsyncLoading();
    String? serviceId;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('A signed-in freelancer is required.');
      if (service.freelancerId != user.uid) {
        throw StateError('You can only create services for your own profile.');
      }
      serviceId = await ref
          .read(freelancerServiceRepositoryProvider)
          .createService(service);
    });
    return state.hasError ? null : serviceId;
  }

  Future<bool> updateService(FreelancerServiceModel service) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('A signed-in freelancer is required.');
      if (service.freelancerId != user.uid) {
        throw StateError('You can only update your own services.');
      }
      await ref
          .read(freelancerServiceRepositoryProvider)
          .updateService(service);
    });
    return !state.hasError;
  }

  Future<bool> deleteService(String serviceId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('A signed-in freelancer is required.');
      await ref
          .read(freelancerServiceRepositoryProvider)
          .deleteService(serviceId: serviceId, freelancerId: user.uid);
    });
    return !state.hasError;
  }

  Future<String?> duplicateService(String serviceId) async {
    state = const AsyncLoading();
    String? duplicateId;
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('A signed-in freelancer is required.');
      duplicateId = await ref
          .read(freelancerServiceRepositoryProvider)
          .duplicateService(serviceId: serviceId, freelancerId: user.uid);
    });
    return state.hasError ? null : duplicateId;
  }

  Future<bool> publishService(String serviceId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('A signed-in freelancer is required.');
      await ref
          .read(freelancerServiceRepositoryProvider)
          .publishService(serviceId: serviceId, freelancerId: user.uid);
    });
    return !state.hasError;
  }

  Future<bool> unpublishService(String serviceId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user == null) throw StateError('A signed-in freelancer is required.');
      await ref
          .read(freelancerServiceRepositoryProvider)
          .unpublishService(serviceId: serviceId, freelancerId: user.uid);
    });
    return !state.hasError;
  }

  String? get errorMessage => state.error?.toString();
}
