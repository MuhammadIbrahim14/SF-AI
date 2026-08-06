import '../models/company_ai_hiring_models.dart';

class CompanyAiFairHiringSafetyService {
  const CompanyAiFairHiringSafetyService();

  static const _manualReviewNote =
      'AI suggestions require human review. No candidate status was changed.';
  static const _fairHiringNote =
      'Protected or sensitive attributes were not used for evaluation.';

  CompanyAiHiringResponseModel sanitize(CompanyAiHiringResponseModel response) {
    final notes = <String>{
      ...response.safetyNotes,
      _manualReviewNote,
      _fairHiringNote,
    }.toList();

    return response.copyWith(
      title: _cleanDecisionLanguage(response.title),
      summary: _cleanDecisionLanguage(response.summary),
      structuredData: _sanitizeMap(response.structuredData),
      recommendations: response.recommendations
          .map(_cleanDecisionLanguage)
          .toList(growable: false),
      safetyNotes: notes,
      requiresManualReview: true,
    );
  }

  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    return map.map((key, value) {
      if (value is String) return MapEntry(key, _cleanDecisionLanguage(value));
      if (value is Map) {
        return MapEntry(key, _sanitizeMap(Map<String, dynamic>.from(value)));
      }
      if (value is Iterable) {
        return MapEntry(
          key,
          value.map((item) {
            if (item is String) return _cleanDecisionLanguage(item);
            if (item is Map) {
              return _sanitizeMap(Map<String, dynamic>.from(item));
            }
            return item;
          }).toList(),
        );
      }
      return MapEntry(key, value);
    });
  }

  String _cleanDecisionLanguage(String value) {
    var text = value;
    final replacements = <RegExp, String>{
      RegExp(r'\bdefinitely hire\b', caseSensitive: false): 'strong match',
      RegExp(r'\bmust hire\b', caseSensitive: false): 'consider for review',
      RegExp(r'\bautomatically hire\b', caseSensitive: false):
          'consider after manual review',
      RegExp(r'\bdefinitely reject\b', caseSensitive: false):
          'needs more review',
      RegExp(r'\bmust reject\b', caseSensitive: false): 'needs more review',
      RegExp(r'\bautomatically reject\b', caseSensitive: false):
          'needs manual review',
    };
    for (final entry in replacements.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    return text;
  }
}
