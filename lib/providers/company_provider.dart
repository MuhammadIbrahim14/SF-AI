import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/company_model.dart';
import 'auth_provider.dart';
import 'repository_providers.dart';

/// Streams the current company's Firestore document.
/// Returns `null` if the user is not authenticated or the document doesn't exist.
final companyProvider = StreamProvider<CompanyModel?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (firebaseUser) {
      if (firebaseUser == null) return Stream.value(null);
      return ref
          .watch(companyRepositoryProvider)
          .companyStream(firebaseUser.uid);
    },
    loading: () => Stream.value(null),
    error: (_, _) => Stream.value(null),
  );
});
