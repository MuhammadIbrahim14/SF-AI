import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/app_exceptions.dart';
import '../models/freelancer_model.dart';
import 'freelancer_repository.dart';

class FreelancerRepositoryImpl implements FreelancerRepository {
  const FreelancerRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _freelancersRef =>
      _firestore.collection('freelancers');

  @override
  Future<void> createFreelancer(FreelancerModel freelancer) async {
    try {
      await _freelancersRef.doc(freelancer.userId).set(freelancer.toJson());
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to create freelancer: ${e.toString()}');
    }
  }

  @override
  Future<FreelancerModel?> getFreelancer(String userId) async {
    try {
      final doc = await _freelancersRef.doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return FreelancerModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to fetch freelancer: ${e.toString()}');
    }
  }

  @override
  Stream<FreelancerModel?> freelancerStream(String userId) {
    return _freelancersRef.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return FreelancerModel.fromFirestore(doc);
    });
  }

  @override
  Future<void> updateFreelancer({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _freelancersRef.doc(userId).set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to update freelancer: ${e.toString()}');
    }
  }
}
