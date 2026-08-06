import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLog {
  const AuditLog({
    required this.id,
    required this.adminId,
    required this.action,
    required this.targetId,
    required this.targetType,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String adminId;
  final String action;
  final String targetId;
  final String targetType;
  final String description;
  final DateTime createdAt;

  factory AuditLog.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final createdAt = data['createdAt'];
    return AuditLog(
      id: document.id,
      adminId: data['adminId']?.toString() ?? '',
      action: data['action']?.toString() ?? 'unknown',
      targetId: data['targetId']?.toString() ?? '',
      targetType: data['targetType']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : createdAt is DateTime
          ? createdAt
          : DateTime.now(),
    );
  }
}
