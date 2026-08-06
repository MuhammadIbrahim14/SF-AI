import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/interview_lab_models.dart';
import 'interview_lab_repository.dart';

class InterviewLabRepositoryImpl implements InterviewLabRepository {
  InterviewLabRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _firestore.doc(InterviewLabCollections.configDocPath);

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _firestore.collection(InterviewLabCollections.sessions);

  CollectionReference<Map<String, dynamic>> get _questions =>
      _firestore.collection(InterviewLabCollections.questions);

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection(InterviewLabCollections.reports);

  CollectionReference<Map<String, dynamic>> get _results =>
      _firestore.collection(InterviewLabCollections.results);

  CollectionReference<Map<String, dynamic>> get _history =>
      _firestore.collection(InterviewLabCollections.history);

  CollectionReference<Map<String, dynamic>> get _templates =>
      _firestore.collection(InterviewLabCollections.templates);

  CollectionReference<Map<String, dynamic>> get _badges =>
      _firestore.collection(InterviewLabCollections.badges);

  CollectionReference<Map<String, dynamic>> get _progress =>
      _firestore.collection(InterviewLabCollections.progress);

  @override
  Future<InterviewLabConfigModel> getConfig() async {
    final snap = await _configRef.get();
    if (!snap.exists) return InterviewLabConfigModel.defaults;
    return InterviewLabConfigModel.fromFirestore(snap);
  }

  @override
  Stream<InterviewLabConfigModel> watchConfig() {
    return _configRef.snapshots().map((snap) {
      if (!snap.exists) return InterviewLabConfigModel.defaults;
      return InterviewLabConfigModel.fromFirestore(snap);
    });
  }

  @override
  Future<void> upsertConfig(InterviewLabConfigModel config) async {
    await _configRef.set(config.toMap(), SetOptions(merge: true));
  }

  @override
  Future<String> createSession(InterviewLabSessionModel session) async {
    final id = session.sessionId.isEmpty
        ? _sessions.doc().id
        : session.sessionId;
    final withId = InterviewLabSessionModel.fromMap({
      ...session.toMap(useServerTimestamps: false),
      'sessionId': id,
      'createdAt': Timestamp.fromDate(session.createdAt),
      'updatedAt': Timestamp.fromDate(session.updatedAt),
    }, docId: id);
    await _sessions.doc(id).set({
      ...withId.toMap(),
      'sessionId': id,
    });
    return id;
  }

  @override
  Future<void> updateSession(InterviewLabSessionModel session) async {
    await _sessions.doc(session.sessionId).set({
      ...session.toMap(),
      'createdAt': Timestamp.fromDate(session.createdAt),
    }, SetOptions(merge: true));
  }

  @override
  Future<InterviewLabSessionModel?> getSession(String sessionId) async {
    final snap = await _sessions.doc(sessionId).get();
    if (!snap.exists) return null;
    return InterviewLabSessionModel.fromFirestore(snap);
  }

  @override
  Stream<InterviewLabSessionModel?> watchSession(String sessionId) {
    return _sessions.doc(sessionId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return InterviewLabSessionModel.fromFirestore(snap);
    });
  }

  @override
  Stream<List<InterviewLabSessionModel>> watchSessionsForCandidate(
    String candidateId,
  ) {
    return _sessions
        .where('candidateId', isEqualTo: candidateId)
        .snapshots()
        .map((snap) {
      final items =
          snap.docs.map(InterviewLabSessionModel.fromFirestore).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  @override
  Future<List<InterviewLabSessionModel>> listSessionsForCandidate(
    String candidateId, {
    int limit = 50,
  }) async {
    final snap = await _sessions
        .where('candidateId', isEqualTo: candidateId)
        .limit(limit)
        .get();
    final items = snap.docs.map(InterviewLabSessionModel.fromFirestore).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<InterviewLabSessionModel?> findResumableSession(
    String candidateId,
  ) async {
    final sessions = await listSessionsForCandidate(candidateId, limit: 30);
    for (final s in sessions) {
      if (s.status == InterviewLabSessionStatus.inProgress ||
          s.status == InterviewLabSessionStatus.paused ||
          s.status == InterviewLabSessionStatus.ready) {
        return s;
      }
    }
    return null;
  }

  @override
  Future<void> deleteSessionCascade(String sessionId) async {
    final session = await getSession(sessionId);
    final candidateId = session?.candidateId.trim() ?? '';
    final batch = _firestore.batch();

    // Owner list rules require candidateId on the same documents where possible.
    Future<void> deleteBySession(
      CollectionReference<Map<String, dynamic>> col, {
      bool includeCandidate = false,
    }) async {
      Query<Map<String, dynamic>> q =
          col.where('sessionId', isEqualTo: sessionId);
      if (includeCandidate && candidateId.isNotEmpty) {
        q = q.where('candidateId', isEqualTo: candidateId);
      }
      final snap = await q.get();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
    }

    // Questions are session-scoped; rules check parent session ownership via get().
    await deleteBySession(_questions);
    await deleteBySession(_reports, includeCandidate: true);
    await deleteBySession(_results, includeCandidate: true);
    await deleteBySession(_history, includeCandidate: true);

    // Also delete by direct ids when present (avoids list entirely).
    final reportId = session?.reportId?.trim();
    if (reportId != null && reportId.isNotEmpty) {
      batch.delete(_reports.doc(reportId));
    }
    final resultId = session?.resultId?.trim();
    if (resultId != null && resultId.isNotEmpty) {
      batch.delete(_results.doc(resultId));
    }

    batch.delete(_sessions.doc(sessionId));
    await batch.commit();
  }

  @override
  Future<void> upsertQuestions(List<InterviewLabQuestionModel> questions) async {
    if (questions.isEmpty) return;
    final batch = _firestore.batch();
    for (final q in questions) {
      final id = q.questionId.isEmpty ? _questions.doc().id : q.questionId;
      batch.set(_questions.doc(id), {
        ...q.toMap(),
        'questionId': id,
      });
    }
    await batch.commit();
  }

  @override
  Future<void> updateQuestion(InterviewLabQuestionModel question) async {
    await _questions.doc(question.questionId).set(
          question.toMap(),
          SetOptions(merge: true),
        );
  }

  @override
  Future<List<InterviewLabQuestionModel>> listQuestionsForSession(
    String sessionId,
  ) async {
    final snap =
        await _questions.where('sessionId', isEqualTo: sessionId).get();
    final items =
        snap.docs.map(InterviewLabQuestionModel.fromFirestore).toList();
    items.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return items;
  }

  @override
  Stream<List<InterviewLabQuestionModel>> watchQuestionsForSession(
    String sessionId,
  ) {
    return _questions
        .where('sessionId', isEqualTo: sessionId)
        .snapshots()
        .map((snap) {
      final items =
          snap.docs.map(InterviewLabQuestionModel.fromFirestore).toList();
      items.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return items;
    });
  }

  @override
  Future<String> saveReport(InterviewLabReportModel report) async {
    final id = report.reportId.isEmpty ? _reports.doc().id : report.reportId;
    await _reports.doc(id).set({
      ...report.toMap(),
      'reportId': id,
    });
    return id;
  }

  @override
  Future<InterviewLabReportModel?> getReport(String reportId) async {
    final snap = await _reports.doc(reportId).get();
    if (!snap.exists) return null;
    return InterviewLabReportModel.fromFirestore(snap);
  }

  @override
  Future<InterviewLabReportModel?> getReportForSession(String sessionId) async {
    // Prefer direct doc read via session.reportId (rules allow owner get).
    final session = await getSession(sessionId);
    final reportId = session?.reportId?.trim();
    if (reportId != null && reportId.isNotEmpty) {
      final byId = await getReport(reportId);
      if (byId != null) return byId;
    }

    // Fallback list query must include candidateId (Firestore rule constraint).
    final candidateId = session?.candidateId.trim() ?? '';
    if (candidateId.isEmpty) return null;
    final snap = await _reports
        .where('sessionId', isEqualTo: sessionId)
        .where('candidateId', isEqualTo: candidateId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return InterviewLabReportModel.fromFirestore(snap.docs.first);
  }

  @override
  Future<String> saveResult(InterviewLabResultModel result) async {
    final id = result.resultId.isEmpty ? _results.doc().id : result.resultId;
    await _results.doc(id).set({
      ...result.toMap(),
      'resultId': id,
    });
    return id;
  }

  @override
  Future<InterviewLabResultModel?> getResultForSession(String sessionId) async {
    final session = await getSession(sessionId);
    final resultId = session?.resultId?.trim();
    if (resultId != null && resultId.isNotEmpty) {
      final snap = await _results.doc(resultId).get();
      if (snap.exists) return InterviewLabResultModel.fromFirestore(snap);
    }

    final candidateId = session?.candidateId.trim() ?? '';
    if (candidateId.isEmpty) return null;
    final snap = await _results
        .where('sessionId', isEqualTo: sessionId)
        .where('candidateId', isEqualTo: candidateId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return InterviewLabResultModel.fromFirestore(snap.docs.first);
  }

  @override
  Future<String> appendHistory(InterviewLabHistoryEntryModel entry) async {
    final id = entry.historyId.isEmpty ? _history.doc().id : entry.historyId;
    await _history.doc(id).set({
      ...entry.toMap(),
      'historyId': id,
    });
    return id;
  }

  @override
  Stream<List<InterviewLabHistoryEntryModel>> watchHistoryForCandidate(
    String candidateId, {
    int limit = 100,
  }) {
    return _history
        .where('candidateId', isEqualTo: candidateId)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final items =
          snap.docs.map(InterviewLabHistoryEntryModel.fromFirestore).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  @override
  Future<String> upsertTemplate(InterviewLabTemplateModel template) async {
    final id =
        template.templateId.isEmpty ? _templates.doc().id : template.templateId;
    await _templates.doc(id).set({
      ...template.toMap(),
      'templateId': id,
    }, SetOptions(merge: true));
    return id;
  }

  @override
  Stream<List<InterviewLabTemplateModel>> watchActiveTemplates() {
    return _templates.where('isActive', isEqualTo: true).snapshots().map((snap) {
      final items =
          snap.docs.map(InterviewLabTemplateModel.fromFirestore).toList();
      _sortTemplates(items);
      return items;
    });
  }

  @override
  Future<List<InterviewLabTemplateModel>> listActiveTemplates() async {
    final snap = await _templates.where('isActive', isEqualTo: true).get();
    final items =
        snap.docs.map(InterviewLabTemplateModel.fromFirestore).toList();
    _sortTemplates(items);
    return items;
  }

  @override
  Stream<List<InterviewLabTemplateModel>> watchAllTemplates() {
    return _templates.snapshots().map((snap) {
      final items =
          snap.docs.map(InterviewLabTemplateModel.fromFirestore).toList();
      _sortTemplates(items);
      return items;
    });
  }

  @override
  Future<List<InterviewLabTemplateModel>> listAllTemplates() async {
    final snap = await _templates.get();
    final items =
        snap.docs.map(InterviewLabTemplateModel.fromFirestore).toList();
    _sortTemplates(items);
    return items;
  }

  void _sortTemplates(List<InterviewLabTemplateModel> items) {
    items.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
  }

  @override
  Future<String> saveBadge(InterviewLabBadgeModel badge) async {
    final id = badge.badgeId.isEmpty ? _badges.doc().id : badge.badgeId;
    await _badges.doc(id).set({
      ...badge.toMap(),
      'badgeId': id,
    });
    return id;
  }

  @override
  Stream<List<InterviewLabBadgeModel>> watchBadgesForCandidate(
    String candidateId,
  ) {
    return _badges
        .where('candidateId', isEqualTo: candidateId)
        .snapshots()
        .map((snap) {
      final items =
          snap.docs.map(InterviewLabBadgeModel.fromFirestore).toList();
      items.sort((a, b) => b.awardedAt.compareTo(a.awardedAt));
      return items;
    });
  }

  @override
  Future<List<InterviewLabBadgeModel>> listBadgesForCandidate(
    String candidateId,
  ) async {
    final snap =
        await _badges.where('candidateId', isEqualTo: candidateId).get();
    final items =
        snap.docs.map(InterviewLabBadgeModel.fromFirestore).toList();
    items.sort((a, b) => b.awardedAt.compareTo(a.awardedAt));
    return items;
  }

  @override
  Future<InterviewLabProgressModel?> getProgress(String candidateId) async {
    final snap = await _progress.doc(candidateId).get();
    if (!snap.exists) return null;
    return InterviewLabProgressModel.fromFirestore(snap);
  }

  @override
  Stream<InterviewLabProgressModel?> watchProgress(String candidateId) {
    return _progress.doc(candidateId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return InterviewLabProgressModel.fromFirestore(snap);
    });
  }

  @override
  Future<void> upsertProgress(InterviewLabProgressModel progress) async {
    await _progress.doc(progress.candidateId).set(
          progress.toMap(),
          SetOptions(merge: true),
        );
  }
}
