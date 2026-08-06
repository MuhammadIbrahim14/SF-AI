import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/app_logger.dart';
import '../../interview_lab/data/interview_lab_repository.dart';

/// Builds a compact, role-scoped evidence map for Career Intelligence AI.
/// Reuses existing Firestore collections — no parallel data stores.
class CareerIntelligenceContextBuilder {
  const CareerIntelligenceContextBuilder({
    required FirebaseFirestore firestore,
    required InterviewLabRepository labRepository,
  })  : _firestore = firestore,
        _lab = labRepository;

  final FirebaseFirestore _firestore;
  final InterviewLabRepository _lab;

  Future<Map<String, dynamic>> build({
    required String userId,
    required String role,
  }) async {
    final normalized = role.trim().toLowerCase();
    return switch (normalized) {
      'freelancer' => _freelancer(userId),
      'teacher' => _teacher(userId),
      'company' => _company(userId),
      _ => _student(userId),
    };
  }

  Future<Map<String, dynamic>> _student(String userId) async {
    final results = await Future.wait([
      _users.doc(userId).get(),
      _students.doc(userId).get(),
      _enrollments.where('studentId', isEqualTo: userId).limit(40).get(),
      _certificates.where('studentId', isEqualTo: userId).limit(30).get(),
      _skillScores(userId).limit(40).get(),
      _smartResumes.doc(userId).get(),
      _lab.listSessionsForCandidate(userId, limit: 20),
      _lab.listBadgesForCandidate(userId),
      _lab.getProgress(userId),
      _applications.where('applicantId', isEqualTo: userId).limit(20).get(),
      _marketSkills(),
    ]);

    final user = (results[0] as DocumentSnapshot).data() as Map<String, dynamic>?;
    final student =
        (results[1] as DocumentSnapshot).data() as Map<String, dynamic>?;
    final enrollments = (results[2] as QuerySnapshot).docs;
    final certificates = (results[3] as QuerySnapshot).docs;
    final skills = (results[4] as QuerySnapshot).docs;
    final resume = (results[5] as DocumentSnapshot).data() as Map<String, dynamic>?;
    final sessions = results[6] as List;
    final badges = results[7] as List;
    final progress = results[8];
    final applications = (results[9] as QuerySnapshot).docs;
    final market = results[10] as Map<String, dynamic>;

    final completedCourses = enrollments
        .where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['status'] == 'completed' ||
              data['progressPercent'] == 100 ||
              data['isCompleted'] == true;
        })
        .length;

    final skillNames = skills
        .map((d) {
          final data = d.data() as Map<String, dynamic>;
          return (data['skillName'] ?? data['name'] ?? d.id).toString();
        })
        .where((s) => s.trim().isNotEmpty)
        .toList();

    double avgInterview = 0;
    try {
      final overall = (progress as dynamic)?.averageOverall;
      if (overall is num) avgInterview = overall.toDouble();
    } catch (_) {
      AppLogger.debug('Career intelligence interview average was unavailable.');
    }

    return {
      'role': 'student',
      'userId': userId,
      'profile': {
        'name': user?['fullName'] ?? user?['name'] ?? '',
        'headline': student?['headline'] ?? resume?['headline'] ?? '',
        'careerGoal': student?['careerGoal'] ?? '',
        'skills': skillNames,
        'bio': student?['bio'] ?? user?['bio'] ?? '',
      },
      'learning': {
        'enrolledCourses': enrollments.length,
        'completedCourses': completedCourses,
        'certificates': certificates.length,
        'certificateTitles': certificates
            .map((d) =>
                ((d.data() as Map)['courseTitle'] ??
                        (d.data() as Map)['title'] ??
                        '')
                    .toString())
            .where((t) => t.isNotEmpty)
            .take(12)
            .toList(),
      },
      'interviewLab': {
        'sessions': sessions.length,
        'averageScore': avgInterview,
        'badges': badges
            .map((b) {
              try {
                return (b as dynamic).title?.toString() ?? '';
              } catch (_) {
                return '';
              }
            })
            .where((t) => t.toString().isNotEmpty)
            .toList(),
      },
      'applications': {
        'count': applications.length,
        'stages': applications
            .map((d) =>
                ((d.data() as Map)['pipelineStage'] ??
                        (d.data() as Map)['status'] ??
                        '')
                    .toString())
            .take(20)
            .toList(),
      },
      'resume': {
        'exists': resume != null,
        'score': resume?['resumeScore'] ?? 0,
        'strengths': resume?['strengths'] ?? const [],
        'improvementAreas': resume?['improvementAreas'] ?? const [],
      },
      'market': market,
    };
  }

  Future<Map<String, dynamic>> _freelancer(String userId) async {
    final results = await Future.wait([
      _users.doc(userId).get(),
      _freelancers.doc(userId).get(),
      _services.where('freelancerId', isEqualTo: userId).limit(30).get(),
      _orders.where('freelancerId', isEqualTo: userId).limit(40).get(),
      _lab.listSessionsForCandidate(userId, limit: 15),
      _lab.listBadgesForCandidate(userId),
      _lab.getProgress(userId),
      _applications.where('applicantId', isEqualTo: userId).limit(15).get(),
      _marketSkills(),
    ]);

    final user = (results[0] as DocumentSnapshot).data() as Map<String, dynamic>?;
    final freelancer =
        (results[1] as DocumentSnapshot).data() as Map<String, dynamic>?;
    final services = (results[2] as QuerySnapshot).docs;
    final orders = (results[3] as QuerySnapshot).docs;
    final sessions = results[4] as List;
    final badges = results[5] as List;
    final progress = results[6];
    final applications = (results[7] as QuerySnapshot).docs;
    final market = results[8] as Map<String, dynamic>;

    final completedOrders = orders.where((d) {
      final status = ((d.data() as Map)['status'] ?? '').toString();
      return status == 'completed' ||
          status == 'delivered' ||
          status == 'released';
    }).length;

    final ratings = orders
        .map((d) => (d.data() as Map)['rating'])
        .whereType<num>()
        .map((n) => n.toDouble())
        .toList();
    final avgRating = ratings.isEmpty
        ? 0.0
        : ratings.reduce((a, b) => a + b) / ratings.length;

    double avgInterview = 0;
    try {
      final overall = (progress as dynamic)?.averageOverall;
      if (overall is num) avgInterview = overall.toDouble();
    } catch (_) {
      AppLogger.debug('Career intelligence interview average was unavailable.');
    }

    return {
      'role': 'freelancer',
      'userId': userId,
      'profile': {
        'name': user?['fullName'] ?? '',
        'title': freelancer?['professionalTitle'] ?? freelancer?['title'] ?? '',
        'skills': freelancer?['skills'] ?? const [],
        'hourlyRate': freelancer?['hourlyRate'] ?? freelancer?['rate'] ?? '',
        'bio': freelancer?['bio'] ?? '',
        'portfolioLinks': freelancer?['portfolioLinks'] ??
            freelancer?['portfolioUrls'] ??
            const [],
      },
      'commerce': {
        'services': services.length,
        'orders': orders.length,
        'completedOrders': completedOrders,
        'averageRating': avgRating,
        'serviceTitles': services
            .map((d) => ((d.data() as Map)['title'] ?? '').toString())
            .where((t) => t.isNotEmpty)
            .take(12)
            .toList(),
      },
      'interviewLab': {
        'sessions': sessions.length,
        'averageScore': avgInterview,
        'badges': badges.length,
      },
      'applications': applications.length,
      'market': market,
    };
  }

  Future<Map<String, dynamic>> _teacher(String userId) async {
    final results = await Future.wait([
      _users.doc(userId).get(),
      _courses.where('teacherId', isEqualTo: userId).limit(40).get(),
      _marketSkills(),
    ]);

    final user = (results[0] as DocumentSnapshot).data() as Map<String, dynamic>?;
    final courses = (results[1] as QuerySnapshot).docs;
    final market = results[2] as Map<String, dynamic>;

    final published = courses.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['isPublished'] == true || data['status'] == 'published';
    }).toList();

    final enrollmentCounts = <int>[];
    for (final course in published.take(12)) {
      final snap = await _enrollments
          .where('courseId', isEqualTo: course.id)
          .limit(200)
          .get();
      enrollmentCounts.add(snap.docs.length);
    }

    return {
      'role': 'teacher',
      'userId': userId,
      'profile': {
        'name': user?['fullName'] ?? '',
      },
      'courses': {
        'total': courses.length,
        'published': published.length,
        'titles': published
            .map((d) => ((d.data() as Map)['title'] ?? '').toString())
            .where((t) => t.isNotEmpty)
            .take(15)
            .toList(),
        'totalEnrollmentsSampled':
            enrollmentCounts.fold<int>(0, (a, b) => a + b),
        'avgEnrollmentsPerCourse': enrollmentCounts.isEmpty
            ? 0
            : enrollmentCounts.reduce((a, b) => a + b) /
                enrollmentCounts.length,
      },
      'market': market,
    };
  }

  Future<Map<String, dynamic>> _company(String userId) async {
    final results = await Future.wait([
      _users.doc(userId).get(),
      _jobs.where('companyId', isEqualTo: userId).limit(40).get(),
      _applications.where('companyId', isEqualTo: userId).limit(80).get(),
      _interviews.where('companyId', isEqualTo: userId).limit(40).get(),
      _marketSkills(),
    ]);

    final user = (results[0] as DocumentSnapshot).data() as Map<String, dynamic>?;
    final jobs = (results[1] as QuerySnapshot).docs;
    final applications = (results[2] as QuerySnapshot).docs;
    final interviews = (results[3] as QuerySnapshot).docs;
    final market = results[4] as Map<String, dynamic>;

    int countStage(String stage) => applications.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return (data['pipelineStage'] ?? data['status'] ?? '')
              .toString()
              .toLowerCase()
              .contains(stage);
        }).length;

    final offersSent = applications.where((d) {
      final offer = ((d.data() as Map)['offerStatus'] ?? '').toString();
      return offer == 'sent' || offer == 'accepted' || offer == 'declined';
    }).length;
    final offersAccepted = applications
        .where((d) => ((d.data() as Map)['offerStatus'] ?? '') == 'accepted')
        .length;

    return {
      'role': 'company',
      'userId': userId,
      'profile': {
        'name': user?['fullName'] ?? user?['companyName'] ?? '',
      },
      'hiring': {
        'jobs': jobs.length,
        'activeJobs': jobs
            .where((d) => (d.data() as Map)['isActive'] == true)
            .length,
        'applications': applications.length,
        'interviews': interviews.length,
        'shortlisted': countStage('shortlist'),
        'hired': countStage('hired'),
        'rejected': countStage('reject'),
        'offersSent': offersSent,
        'offersAccepted': offersAccepted,
        'offerAcceptanceRate': offersSent == 0
            ? 0
            : (offersAccepted / offersSent) * 100,
      },
      'market': market,
    };
  }

  Future<Map<String, dynamic>> _marketSkills() async {
    final jobs = await _jobs
        .where('isActive', isEqualTo: true)
        .limit(60)
        .get();
    final counts = <String, int>{};
    for (final doc in jobs.docs) {
      final data = doc.data();
      final skills = <String>[];
      final raw = data['skills'] ?? data['requiredSkills'] ?? data['tags'];
      if (raw is Iterable) {
        skills.addAll(raw.map((e) => e.toString()));
      } else if (raw is String) {
        skills.addAll(raw.split(','));
      }
      for (final skill in skills) {
        final key = skill.trim();
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {
      'trendingFromJobs': ranked.take(12).map((e) => e.key).toList(),
      'jobSampleSize': jobs.docs.length,
    };
  }

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _students =>
      _firestore.collection('students');
  CollectionReference<Map<String, dynamic>> get _freelancers =>
      _firestore.collection('freelancers');
  CollectionReference<Map<String, dynamic>> get _courses =>
      _firestore.collection('courses');
  CollectionReference<Map<String, dynamic>> get _enrollments =>
      _firestore.collection('enrollments');
  CollectionReference<Map<String, dynamic>> get _certificates =>
      _firestore.collection('certificates');
  CollectionReference<Map<String, dynamic>> get _smartResumes =>
      _firestore.collection('smartResumes');
  CollectionReference<Map<String, dynamic>> get _jobs =>
      _firestore.collection('jobs');
  CollectionReference<Map<String, dynamic>> get _applications =>
      _firestore.collection('applications');
  CollectionReference<Map<String, dynamic>> get _interviews =>
      _firestore.collection('interviews');
  CollectionReference<Map<String, dynamic>> get _services =>
      _firestore.collection('freelancerServices');
  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('serviceOrders');

  CollectionReference<Map<String, dynamic>> _skillScores(String userId) =>
      _firestore.collection('skillScores').doc(userId).collection('skills');
}
