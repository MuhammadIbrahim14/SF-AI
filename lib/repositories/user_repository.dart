import '../models/user_model.dart';

/// SkillForge AI — User Repository Contract
/// Defines the user data interface that data layer must implement.
abstract class UserRepository {
  /// Creates a new user document in Firestore.
  Future<void> createUser(UserModel user);

  /// Retrieves a user document by [uid].
  Future<UserModel?> getUser(String uid);

  /// Returns a real-time stream of the user document for [uid].
  Stream<UserModel?> userStream(String uid);

  /// Updates the role fields for a user.
  Future<void> updateUserRole({
    required String uid,
    required List<String> roles,
    required String primaryRole,
  });

  /// Updates arbitrary fields on the user document.
  Future<void> updateUser({
    required String uid,
    required Map<String, dynamic> data,
  });
}
