import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/errors/app_exceptions.dart';
import '../models/student_model.dart';
import 'student_repository.dart';

class StudentRepositoryImpl implements StudentRepository {
  const StudentRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _studentsRef =>
      _firestore.collection('students');

  @override
  Future<void> createStudent(StudentModel student) async {
    try {
      await _studentsRef.doc(student.userId).set(student.toJson());
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to create student: ${e.toString()}');
    }
  }

  @override
  Future<StudentModel?> getStudent(String userId) async {
    try {
      final doc = await _studentsRef.doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return StudentModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to fetch student: ${e.toString()}');
    }
  }

  @override
  Stream<StudentModel?> studentStream(String userId) {
    return _studentsRef.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return StudentModel.fromFirestore(doc);
    });
  }

  @override
  Future<void> updateStudent({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _studentsRef.doc(userId).set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to update student: ${e.toString()}');
    }
  }
}
