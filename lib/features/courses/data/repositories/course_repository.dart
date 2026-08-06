import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../models/course_model.dart';

abstract class CourseRepository {
  Future<String> createCourse(CourseModel course);
  Future<void> updateCourse(CourseModel course);
  Future<void> publishCourse({
    required String courseId,
    required String teacherId,
  });
  Future<void> archiveCourse({
    required String courseId,
    required String teacherId,
  });
  Future<CourseModel?> getCourse(String courseId);
  Future<int> countPublishedCoursesByTeacher(String teacherId);
  Stream<List<CourseModel>> streamTeacherCourses(String teacherId);
  Stream<List<CourseModel>> streamPublishedCourses();
}

class FirestoreCourseRepository implements CourseRepository {
  const FirestoreCourseRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _coursesRef =>
      _firestore.collection('courses');

  @override
  Future<String> createCourse(CourseModel course) async {
    try {
      final docRef = course.id.isEmpty
          ? _coursesRef.doc()
          : _coursesRef.doc(course.id);
      final now = DateTime.now();
      await docRef.set(
        course.copyWith(id: docRef.id, createdAt: now, updatedAt: now).toJson(),
      );
      return docRef.id;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to create course: ${e.toString()}');
    }
  }

  @override
  Future<void> updateCourse(CourseModel course) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _coursesRef.doc(course.id);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists || snapshot.data() == null) {
          throw StateError('Course not found.');
        }

        final existingTeacherId = snapshot.data()?['teacherId']?.toString();
        if (existingTeacherId != course.teacherId) {
          throw StateError('Only the course teacher can edit this course.');
        }

        final payload = course.copyWith(updatedAt: DateTime.now()).toJson();
        if (course.thumbnailUrl == null ||
            course.thumbnailUrl!.trim().isEmpty) {
          payload['thumbnailUrl'] = FieldValue.delete();
          payload['coverImageUrl'] = FieldValue.delete();
        }

        transaction.update(docRef, payload);
      });
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to update course: ${e.toString()}');
    }
  }

  @override
  Future<void> publishCourse({
    required String courseId,
    required String teacherId,
  }) async {
    await _updateStatus(
      courseId: courseId,
      teacherId: teacherId,
      status: CourseStatus.published,
    );
  }

  @override
  Future<void> archiveCourse({
    required String courseId,
    required String teacherId,
  }) async {
    await _updateStatus(
      courseId: courseId,
      teacherId: teacherId,
      status: CourseStatus.archived,
    );
  }

  @override
  Future<CourseModel?> getCourse(String courseId) async {
    try {
      final snapshot = await _coursesRef.doc(courseId).get();
      if (!snapshot.exists || snapshot.data() == null) return null;
      return CourseModel.fromFirestore(snapshot);
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to fetch course: ${e.toString()}');
    }
  }

  @override
  Future<int> countPublishedCoursesByTeacher(String teacherId) async {
    try {
      final snapshot = await _coursesRef
          .where('teacherId', isEqualTo: teacherId)
          .where('status', isEqualTo: CourseStatus.published)
          .count()
          .get();
      return snapshot.count ?? 0;
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException('Failed to count published courses: ${e.toString()}');
    }
  }

  @override
  Stream<List<CourseModel>> streamTeacherCourses(String teacherId) {
    return _coursesRef.where('teacherId', isEqualTo: teacherId).snapshots().map(
      (snapshot) {
        final courses = snapshot.docs
            .map((doc) => CourseModel.fromFirestore(doc))
            .toList();
        courses.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return courses;
      },
    );
  }

  @override
  Stream<List<CourseModel>> streamPublishedCourses() {
    final controller = StreamController<List<CourseModel>>();
    var statusCourses = <String, CourseModel>{};
    var flagCourses = <String, CourseModel>{};

    void emit() {
      final merged = <String, CourseModel>{...statusCourses, ...flagCourses};
      final courses = merged.values
          .where((course) => course.isPublished)
          .toList();
      courses.sort((a, b) => b.publishedAtValue.compareTo(a.publishedAtValue));
      if (!controller.isClosed) controller.add(courses);
    }

    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
    statusSubscription;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
    flagSubscription;

    Map<String, CourseModel> parseSnapshot(
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final courses = <String, CourseModel>{};
      for (final doc in snapshot.docs) {
        final course = CourseModel.fromFirestore(doc);
        if (course.isPublished) courses[course.id] = course;
      }
      return courses;
    }

    void applyStatusSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
      statusCourses = parseSnapshot(snapshot);
      emit();
    }

    void applyFlagSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
      flagCourses = parseSnapshot(snapshot);
      emit();
    }

    statusSubscription = _coursesRef
        .where('status', isEqualTo: CourseStatus.published)
        .snapshots()
        .listen(applyStatusSnapshot, onError: controller.addError);

    flagSubscription = _coursesRef
        .where('isPublished', isEqualTo: true)
        .snapshots()
        .listen(applyFlagSnapshot, onError: controller.addError);

    controller.onCancel = () async {
      await statusSubscription.cancel();
      await flagSubscription.cancel();
    };

    return controller.stream;
  }

  Future<void> _updateStatus({
    required String courseId,
    required String teacherId,
    required String status,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _coursesRef.doc(courseId);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists || snapshot.data() == null) {
          throw StateError('Course not found.');
        }

        final data = snapshot.data()!;
        if (data['teacherId']?.toString() != teacherId) {
          throw StateError('Only the course teacher can update this course.');
        }

        final now = DateTime.now();
        transaction.update(docRef, {
          'status': status,
          'isPublished': status == CourseStatus.published,
          'updatedAt': Timestamp.fromDate(now),
          if (status == CourseStatus.published)
            'publishedAt': Timestamp.fromDate(now),
          if (status == CourseStatus.archived)
            'archivedAt': Timestamp.fromDate(now),
        });
      });
    } on FirebaseException catch (e) {
      throw FirestoreException.fromCode(e.code);
    } catch (e) {
      throw FirestoreException(
        'Failed to update course status: ${e.toString()}',
      );
    }
  }
}
