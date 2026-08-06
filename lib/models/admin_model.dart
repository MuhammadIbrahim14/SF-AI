import 'package:cloud_firestore/cloud_firestore.dart';

String _stringValue(Object? value, String fallback) =>
    value is String ? value : fallback;

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime _dateValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return DateTime.now();
}

class AdminModel {
  const AdminModel({
    required this.userId,
    required this.accessLevel, // e.g., 'superadmin', 'moderator'
    required this.assignedRegion, // e.g., 'global', 'NA', 'EU'
    required this.lastActive,
    this.managedReportsCount = 0,
  });

  final String userId;
  final String accessLevel;
  final String assignedRegion;
  final DateTime lastActive;
  final int managedReportsCount;

  factory AdminModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AdminModel(
      userId: doc.id,
      accessLevel: _stringValue(data['accessLevel'], 'moderator'),
      assignedRegion: _stringValue(data['assignedRegion'], 'global'),
      lastActive: _dateValue(data['lastActive']),
      managedReportsCount: _intValue(data['managedReportsCount']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessLevel': accessLevel,
      'assignedRegion': assignedRegion,
      'lastActive': Timestamp.fromDate(lastActive),
      'managedReportsCount': managedReportsCount,
    };
  }

  AdminModel copyWith({
    String? userId,
    String? accessLevel,
    String? assignedRegion,
    DateTime? lastActive,
    int? managedReportsCount,
  }) {
    return AdminModel(
      userId: userId ?? this.userId,
      accessLevel: accessLevel ?? this.accessLevel,
      assignedRegion: assignedRegion ?? this.assignedRegion,
      lastActive: lastActive ?? this.lastActive,
      managedReportsCount: managedReportsCount ?? this.managedReportsCount,
    );
  }
}
