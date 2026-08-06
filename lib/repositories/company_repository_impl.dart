import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/app_exceptions.dart';
import '../models/company_model.dart';
import 'company_repository.dart';

class CompanyRepositoryImpl implements CompanyRepository {
  const CompanyRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _companiesRef =>
      _firestore.collection('companies');

  @override
  Future<void> createCompany(CompanyModel company) async {
    try {
      await _companiesRef.doc(company.userId).set(company.toJson());
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to create company: ${e.toString()}');
    }
  }

  @override
  Future<CompanyModel?> getCompany(String userId) async {
    try {
      final doc = await _companiesRef.doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return CompanyModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to fetch company: ${e.toString()}');
    }
  }

  @override
  Stream<CompanyModel?> companyStream(String userId) {
    return _companiesRef.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return CompanyModel.fromFirestore(doc);
    });
  }

  @override
  Future<void> updateCompany({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _companiesRef.doc(userId).set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to update company: ${e.toString()}');
    }
  }
}
