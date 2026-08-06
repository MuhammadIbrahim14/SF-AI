import 'package:cloud_firestore/cloud_firestore.dart';

class ContactMessage {
  final String messageId;
  final String? userId;
  final String name;
  final String email;
  final String subject;
  final String category;
  final String message;
  final String
  status; // 'new', 'read', 'inProgress', 'responded', 'resolved', 'closed'
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? resolvedBy;
  final String? adminNote;
  final String? adminResponse;
  final DateTime? respondedAt;
  final String? respondedBy;
  final DateTime? resolvedAt;
  final String priority; // 'low', 'normal', 'high'

  const ContactMessage({
    required this.messageId,
    this.userId,
    required this.name,
    required this.email,
    required this.subject,
    required this.category,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedBy,
    this.adminNote,
    this.adminResponse,
    this.respondedAt,
    this.respondedBy,
    this.resolvedAt,
    this.priority = 'normal',
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'userId': userId,
      'name': name,
      'email': email,
      'subject': subject,
      'category': category,
      'message': message,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'resolvedBy': resolvedBy,
      'adminNote': adminNote,
      'adminResponse': adminResponse,
      'respondedAt': respondedAt != null
          ? Timestamp.fromDate(respondedAt!)
          : null,
      'respondedBy': respondedBy,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'priority': priority,
    };
  }

  factory ContactMessage.fromMap(Map<String, dynamic> map, String id) {
    return ContactMessage(
      messageId: id,
      userId: map['userId'] as String?,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      subject: map['subject'] ?? '',
      category: map['category'] ?? '',
      message: map['message'] ?? '',
      status: map['status'] ?? 'new',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedBy: map['resolvedBy'] as String?,
      adminNote: map['adminNote'] as String?,
      adminResponse: map['adminResponse'] as String?,
      respondedAt: (map['respondedAt'] as Timestamp?)?.toDate(),
      respondedBy: map['respondedBy'] as String?,
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      priority: map['priority'] as String? ?? 'normal',
    );
  }

  ContactMessage copyWith({
    String? status,
    DateTime? updatedAt,
    String? resolvedBy,
    String? adminNote,
    String? adminResponse,
    DateTime? respondedAt,
    String? respondedBy,
    DateTime? resolvedAt,
    String? priority,
  }) {
    return ContactMessage(
      messageId: messageId,
      userId: userId,
      name: name,
      email: email,
      subject: subject,
      category: category,
      message: message,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      adminNote: adminNote ?? this.adminNote,
      adminResponse: adminResponse ?? this.adminResponse,
      respondedAt: respondedAt ?? this.respondedAt,
      respondedBy: respondedBy ?? this.respondedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      priority: priority ?? this.priority,
    );
  }
}
