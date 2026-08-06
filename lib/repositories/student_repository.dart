import '../models/student_model.dart';

abstract class StudentRepository {
  Future<void> createStudent(StudentModel student);
  Future<StudentModel?> getStudent(String userId);
  Stream<StudentModel?> studentStream(String userId);
  Future<void> updateStudent({
    required String userId,
    required Map<String, dynamic> data,
  });
}
