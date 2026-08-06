import '../models/marketplace_ai_draft_models.dart';

/// Soft quality gates before Apply / Publish. Never hard-block unless
/// the product already requires form validation.
class MarketplaceAiQualityGates {
  const MarketplaceAiQualityGates._();

  static List<String> listingWarnings(MarketplaceServiceListingDraft draft) {
    final warnings = <String>[];
    if (draft.title.trim().isEmpty) {
      warnings.add('Title is missing.');
    }
    if (draft.shortDescription.trim().isEmpty &&
        draft.fullDescription.trim().isEmpty) {
      warnings.add('Description is empty.');
    }
    if (draft.packages.isEmpty) {
      warnings.add('No packages defined.');
    }
    if (draft.linkedSkills.isEmpty) {
      warnings.add('No linked skills — consider linking verified skills.');
    }
    if (draft.startingPrice == null || draft.startingPrice! <= 0) {
      warnings.add('Starting price is missing or zero.');
    }
    return warnings;
  }

  static List<String> listingWarningsFromControllers({
    required String title,
    required String shortDescription,
    required String fullDescription,
    required String packagesText,
    required String linkedSkills,
    required String startingPrice,
  }) {
    return listingWarnings(
      MarketplaceServiceListingDraft(
        raw: const {},
        title: title,
        shortDescription: shortDescription,
        fullDescription: fullDescription,
        packages: packagesText.trim().isEmpty
            ? const []
            : [
                {'title': 'parsed'},
              ],
        linkedSkills: linkedSkills
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        startingPrice: double.tryParse(startingPrice.trim()),
      ),
    );
  }

  static List<String> serviceRequestWarnings(
    MarketplaceServiceRequestDraft draft,
  ) {
    final warnings = <String>[];
    if (draft.projectTitle.trim().isEmpty) {
      warnings.add('Project title is missing.');
    }
    if (draft.requirements.trim().isEmpty) {
      warnings.add('Requirements are empty.');
    }
    return warnings;
  }

  static List<String> profileWarnings(MarketplaceProfileDraft draft) {
    final warnings = <String>[];
    if (draft.professionalTitle.trim().isEmpty) {
      warnings.add('Professional title is missing.');
    }
    if (draft.bio.trim().isEmpty) {
      warnings.add('Bio is empty.');
    }
    if (draft.skills.isEmpty) {
      warnings.add('No skills linked from your profile evidence.');
    }
    return warnings;
  }
}
