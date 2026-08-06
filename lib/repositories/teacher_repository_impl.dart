import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/app_exceptions.dart';
import '../models/teacher_model.dart';
import 'teacher_repository.dart';

class TeacherRepositoryImpl implements TeacherRepository {
  const TeacherRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _teachersRef =>
      _firestore.collection('teachers');

  @override
  Future<void> createTeacher(TeacherModel teacher) async {
    try {
      await _teachersRef.doc(teacher.userId).set(teacher.toJson());
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to create teacher: ${e.toString()}');
    }
  }

  @override
  Future<TeacherModel?> getTeacher(String userId) async {
    try {
      final doc = await _teachersRef.doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return TeacherModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to fetch teacher: ${e.toString()}');
    }
  }

  @override
  Stream<TeacherModel?> teacherStream(String userId) {
    return _teachersRef.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return TeacherModel.fromFirestore(doc);
    });
  }

  @override
  Future<void> updateTeacher({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _teachersRef.doc(userId).set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to update teacher: ${e.toString()}');
    }
  }
}
