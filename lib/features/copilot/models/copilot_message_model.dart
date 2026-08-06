class CopilotMessageSender {
  const CopilotMessageSender._();

  static const user = 'user';
  static const copilot = 'copilot';
  static const system = 'system';

  static const values = {user, copilot, system};

  static String normalize(String? value) {
    final normalized = (value ?? copilot).trim();
    return values.contains(normalized) ? normalized : copilot;
  }
}

class CopilotActionStatus {
  const CopilotActionStatus._();

  static const none = 'none';
  static const suggested = 'suggested';
  static const executed = 'executed';
  static const blocked = 'blocked';
  static const needsConfirmation = 'needsConfirmation';
  static const unsupported = 'unsupported';

  static const values = {
    none,
    suggested,
    executed,
    blocked,
    needsConfirmation,
    unsupported,
  };

  static String normalize(String? value) {
    final normalized = (value ?? none).trim();
    return values.contains(normalized) ? normalized : none;
  }
}

class CopilotMessageModel {
  const CopilotMessageModel({
    required this.id,
    required this.text,
    required this.sender,
    required this.createdAt,
    this.intentType,
    this.actionTarget,
    this.actionStatus = CopilotActionStatus.none,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String text;
  final String sender;
  final DateTime createdAt;
  final String? intentType;
  final String? actionTarget;
  final String actionStatus;
  final Map<String, dynamic> metadata;

  factory CopilotMessageModel.fromMap(Map<String, dynamic> map) {
    return CopilotMessageModel(
      id: map['id']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      sender: CopilotMessageSender.normalize(map['sender']?.toString()),
      createdAt: _dateValue(map['createdAt']),
      intentType: map['intentType'] is String
          ? map['intentType'] as String
          : null,
      actionTarget: map['actionTarget'] is String
          ? map['actionTarget'] as String
          : null,
      actionStatus: CopilotActionStatus.normalize(
        map['actionStatus']?.toString(),
      ),
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'sender': CopilotMessageSender.normalize(sender),
      'createdAt': createdAt.toIso8601String(),
      if ((intentType ?? '').trim().isNotEmpty) 'intentType': intentType,
      if ((actionTarget ?? '').trim().isNotEmpty) 'actionTarget': actionTarget,
      'actionStatus': CopilotActionStatus.normalize(actionStatus),
      'metadata': metadata,
    };
  }

  CopilotMessageModel copyWith({
    String? id,
    String? text,
    String? sender,
    DateTime? createdAt,
    String? intentType,
    String? actionTarget,
    String? actionStatus,
    Map<String, dynamic>? metadata,
  }) {
    return CopilotMessageModel(
      id: id ?? this.id,
      text: text ?? this.text,
      sender: CopilotMessageSender.normalize(sender ?? this.sender),
      createdAt: createdAt ?? this.createdAt,
      intentType: intentType ?? this.intentType,
      actionTarget: actionTarget ?? this.actionTarget,
      actionStatus: CopilotActionStatus.normalize(
        actionStatus ?? this.actionStatus,
      ),
      metadata: metadata ?? this.metadata,
    );
  }
}

DateTime _dateValue(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return DateTime.now();
}
