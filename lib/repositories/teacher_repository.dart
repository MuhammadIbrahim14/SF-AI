import '../models/teacher_model.dart';

abstract class TeacherRepository {
  Future<void> createTeacher(TeacherModel teacher);
  Future<TeacherModel?> getTeacher(String userId);
  Stream<TeacherModel?> teacherStream(String userId);
  Future<void> updateTeacher({
    required String userId,
    required Map<String, dynamic> data,
  });
}
