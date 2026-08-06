import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../models/lesson_model.dart';

abstract class LessonRepository {
  Future<String> createLesson(LessonModel lesson);
  Future<void> updateLesson(LessonModel lesson);
  Future<void> archiveLesson({
    required String courseId,
    required String lessonId,
    required String teacherId,
  });
  Future<LessonModel?> getLesson({
    required String courseId,
    required String lessonId,
  });
  Future<int> countLessonsInCourse(String courseId);
  Stream<List<LessonModel>> watchLessons(String courseId);
}

class FirestoreLessonRepository implements LessonRepository {
  const FirestoreLessonRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _lessons(String courseId) =>
      _firestore.collection('courses').doc(courseId).collection('lessons');

  @override
  Future<String> createLesson(LessonModel lesson) async {
    try {
      final docRef = lesson.lessonId.isEmpty
          ? _lessons(lesson.courseId).doc()
          : _lessons(lesson.courseId).doc(lesson.lessonId);
      final now = DateTime.now();
      final batch = _firestore.batch();
      batch.set(
        docRef,
        lesson
            .copyWith(
              lessonId: docRef.id,
              createdAt: now,
              updatedAt: now,
              isArchived: false,
            )
            .toJson(),
      );
      batch.update(_firestore.collection('courses').doc(lesson.courseId), {
        'lessonCount': FieldValue.increment(1),
        'updatedAt': Timestamp.fromDate(now),
      });
      await batch.commit();
      return docRef.id;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to create lesson: ${e.toString()}');
    }
  }

  @override
  Future<void> updateLesson(LessonModel lesson) async {
    try {
      await _lessons(lesson.courseId)
          .doc(lesson.lessonId)
          .update(lesson.copyWith(updatedAt: DateTime.now()).toJson());
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to update lesson: ${e.toString()}');
    }
  }

  @override
  Future<void> archiveLesson({
    required String courseId,
    required String lessonId,
    required String teacherId,
  }) async {
    try {
      final docRef = _lessons(courseId).doc(lessonId);
      final snapshot = await docRef.get();
      final data = snapshot.data();
      if (data == null) throw StateError('Lesson not found.');
      if (data['teacherId']?.toString() != teacherId) {
        throw StateError('Only the lesson teacher can archive this lesson.');
      }
      final lesson = LessonModel.fromFirestore(snapshot);
      if (lesson.isArchived) return;

      final now = DateTime.now();
      final batch = _firestore.batch();
      batch.update(docRef, {
        'isArchived': true,
        'updatedAt': Timestamp.fromDate(now),
      });
      batch.update(_firestore.collection('courses').doc(courseId), {
        'lessonCount': FieldValue.increment(-1),
        'updatedAt': Timestamp.fromDate(now),
      });
      await batch.commit();
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to archive lesson: ${e.toString()}');
    }
  }

  @override
  Future<LessonModel?> getLesson({
    required String courseId,
    required String lessonId,
  }) async {
    try {
      final snapshot = await _lessons(courseId).doc(lessonId).get();
      if (!snapshot.exists || snapshot.data() == null) return null;
      return LessonModel.fromFirestore(snapshot);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to load lesson: ${e.toString()}');
    }
  }

  @override
  Future<int> countLessonsInCourse(String courseId) async {
    try {
      final snapshot = await _lessons(courseId)
          .where('isArchived', isEqualTo: false)
          .count()
          .get();
      return snapshot.count ?? 0;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to count lessons: ${e.toString()}');
    }
  }

  @override
  Stream<List<LessonModel>> watchLessons(String courseId) {
    return _lessons(
      courseId,
    ).where('isArchived', isEqualTo: false).snapshots().map((snapshot) {
      final lessons = snapshot.docs
          .map((doc) => LessonModel.fromFirestore(doc))
          .toList();
      lessons.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return lessons;
    });
  }
}
