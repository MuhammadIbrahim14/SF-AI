import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return DateTime.now();
}

String _string(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

/// Per-student attendance mark for a batch session day.
class TeacherBatchAttendanceStatus {
  const TeacherBatchAttendanceStatus._();

  static const present = 'present';
  static const absent = 'absent';
  static const late = 'late';
  static const excused = 'excused';

  static const values = <String>[present, absent, late, excused];

  static String normalize(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    return values.contains(normalized) ? normalized : present;
  }

  static String label(String status) {
    switch (normalize(status)) {
      case absent:
        return 'Absent';
      case late:
        return 'Late';
      case excused:
        return 'Excused';
      case present:
      default:
        return 'Present';
    }
  }
}

/// `teacherBatches/{batchId}/attendance/{dateId}` where dateId is YYYY-MM-DD.
class TeacherBatchAttendanceModel {
  const TeacherBatchAttendanceModel({
    required this.dateId,
    required this.date,
    required this.records,
    required this.teacherId,
    required this.updatedAt,
  });

  final String dateId;
  final String date;
  final Map<String, String> records;
  final String teacherId;
  final DateTime updatedAt;

  factory TeacherBatchAttendanceModel.empty({
    required String dateId,
    required String teacherId,
  }) {
    return TeacherBatchAttendanceModel(
      dateId: dateId,
      date: dateId,
      records: const <String, String>{},
      teacherId: teacherId,
      updatedAt: DateTime.now(),
    );
  }

  factory TeacherBatchAttendanceModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawRecords = data['records'];
    final records = <String, String>{};
    if (rawRecords is Map) {
      for (final entry in rawRecords.entries) {
        final studentId = entry.key.toString().trim();
        if (studentId.isEmpty) continue;
        records[studentId] = TeacherBatchAttendanceStatus.normalize(
          entry.value?.toString(),
        );
      }
    }
    final dateId = doc.id.trim().isEmpty
        ? _string(data['date'])
        : doc.id.trim();
    return TeacherBatchAttendanceModel(
      dateId: dateId,
      date: _string(data['date'], dateId),
      records: records,
      teacherId: _string(data['teacherId']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.trim(),
      'records': {
        for (final entry in records.entries)
          entry.key: TeacherBatchAttendanceStatus.normalize(entry.value),
      },
      'teacherId': teacherId,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  String statusFor(String studentId) {
    return TeacherBatchAttendanceStatus.normalize(records[studentId]);
  }
}

/// Formats a [DateTime] as YYYY-MM-DD for attendance doc IDs.
String teacherBatchAttendanceDateId(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
