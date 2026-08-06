import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/role_theme.dart';
import '../../models/user_role.dart';
import '../../providers/profile_provider.dart';
import '../../features/marketplace_ai/models/marketplace_ai_draft_models.dart';
import '../../features/marketplace_ai/services/marketplace_ai_sanitize.dart';
import '../../features/marketplace_ai/services/marketplace_ai_service.dart';
import 'custom_text_field.dart';
import 'loading_overlay.dart';
import 'profile_image_picker.dart';
import 'role_fixed_header_page.dart';

class RoleEditProfileForm extends ConsumerStatefulWidget {
  const RoleEditProfileForm({super.key, required this.role});

  final UserRole role;

  @override
  ConsumerState<RoleEditProfileForm> createState() =>
      _RoleEditProfileFormState();
}

class _RoleEditProfileFormState extends ConsumerState<RoleEditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool _initialized = false;

  TextEditingController _controller(String key) {
    return _controllers.putIfAbsent(key, TextEditingController.new);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initialize(ProfileData profile) {
    if (_initialized) return;
    _controller('fullName').text = profile.user.fullName;
    _controller('email').text = profile.user.email;
    _controller('phone').text = profile.user.phone;
    _controller('gender').text = profile.user.gender;
    _controller('dateOfBirth').text = profile.user.dateOfBirth == null
        ? ''
        : DateFormat('yyyy-MM-dd').format(profile.user.dateOfBirth!);
    _controller('country').text = profile.user.country;
    _controller('city').text = profile.user.city;
    _controller('personalBio').text = profile.user.bio;
    for (final field in _fieldsForRole(widget.role)) {
      final value = profile.details[field.key];
      _controller(field.key).text = value is Iterable
          ? value.join(', ')
          : value?.toString() ?? '';
    }
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyPendingProfileDraft(profile);
    });
  }

  void _applyPendingProfileDraft(ProfileData profile) {
    final pending = MarketplaceAiPendingApply.profile;
    if (pending == null || pending.isEmpty) return;
    if (widget.role != UserRole.freelancer) return;
    MarketplaceAiPendingApply.profile = null;
    _applyProfileDraft(MarketplaceProfileDraft.fromMap(pending), profile);
  }

  void _applyProfileDraft(
    MarketplaceProfileDraft draft,
    ProfileData profile,
  ) {
    final detailSkills = profile.details['skills'];
    final detailPortfolio = profile.details['portfolioLinks'];
    final knownSkills = <String>[
      if (detailSkills is Iterable)
        ...detailSkills.map((e) => e.toString()),
      ...draft.skills,
    ];
    final evidence = MarketplaceAiKnownEvidence(
      knownSkills: knownSkills,
      allowedUrls: [
        if (detailPortfolio is Iterable)
          ...detailPortfolio.map((e) => e.toString()),
        if ((profile.details['portfolio'] ?? '').toString().trim().isNotEmpty)
          profile.details['portfolio'].toString(),
        if ((profile.details['linkedin'] ?? '').toString().trim().isNotEmpty)
          profile.details['linkedin'].toString(),
        if ((profile.details['github'] ?? '').toString().trim().isNotEmpty)
          profile.details['github'].toString(),
        if ((profile.details['website'] ?? '').toString().trim().isNotEmpty)
          profile.details['website'].toString(),
      ],
    );
    final sanitized = MarketplaceAiSanitize.sanitizeProfile(
      draft,
      evidence: evidence,
    );
    setState(() {
      if (sanitized.professionalTitle.trim().isNotEmpty) {
        _controller('professionalTitle').text = sanitized.professionalTitle;
      }
      if (sanitized.bio.trim().isNotEmpty) {
        _controller('bio').text = sanitized.bio;
        _controller('personalBio').text = sanitized.bio;
      }
      if (sanitized.services.trim().isNotEmpty) {
        _controller('services').text = sanitized.services;
      }
      if (sanitized.category.trim().isNotEmpty) {
        _controller('category').text = sanitized.category;
      }
      if (sanitized.skills.isNotEmpty) {
        _controller('skills').text = sanitized.skills.join(', ');
      }
      if (sanitized.hourlyRate != null && sanitized.hourlyRate! > 0) {
        final rate = sanitized.hourlyRate!;
        _controller('hourlyRate').text = rate == rate.roundToDouble()
            ? rate.toStringAsFixed(0)
            : rate.toString();
      }
      if (sanitized.portfolioLinks.isNotEmpty) {
        _controller('portfolioLinks').text =
            sanitized.portfolioLinks.join(', ');
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'AI profile draft applied. Review fields, then Save yourself.',
        ),
      ),
    );
  }

  Future<void> _openProfileAi(ProfileData profile) async {
    final promptController = TextEditingController(
      text:
          'Improve my freelancer profile for clearer positioning. '
          'Do not invent certificates or portfolio URLs.',
    );
    final service = MarketplaceAiService();
    MarketplaceAiDraftResponse? response;
    var loading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Improve profile with AI'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'AI fills profile fields only. You still Save Changes manually.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: promptController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Instructions',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: loading
                            ? null
                            : () async {
                                setDialogState(() => loading = true);
                                final detailSkills = profile.details['skills'];
                                final evidence = MarketplaceAiKnownEvidence(
                                  knownSkills: detailSkills is Iterable
                                      ? detailSkills
                                            .map((e) => e.toString())
                                            .toList()
                                      : const [],
                                  allowedUrls: [
                                    if ((profile.details['portfolio'] ?? '')
                                        .toString()
                                        .trim()
                                        .isNotEmpty)
                                      profile.details['portfolio'].toString(),
                                    if ((profile.details['linkedin'] ?? '')
                                        .toString()
                                        .trim()
                                        .isNotEmpty)
                                      profile.details['linkedin'].toString(),
                                  ],
                                );
                                final result = await service.generate(
                                  taskType: MarketplaceAiTaskType
                                      .freelancerProfileImprover,
                                  prompt: promptController.text.trim(),
                                  safeAppContext: {
                                    'freelancerProfile': {
                                      'professionalTitle':
                                          _controller('professionalTitle').text,
                                      'bio': _controller('bio').text,
                                      'services': _controller('services').text,
                                      'category':
                                          _controller('category').text,
                                      'skills': evidence.knownSkills,
                                    },
                                    'knownSkills': evidence.knownSkills,
                                    'allowedUrls': evidence.allowedUrls,
                                  },
                                  evidence: evidence,
                                  screen: 'RoleEditProfileForm',
                                );
                                if (!context.mounted) return;
                                setDialogState(() {
                                  response = result;
                                  loading = false;
                                });
                              },
                        icon: loading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome_rounded),
                        label: Text(
                          loading ? 'Generating...' : 'Generate Preview',
                        ),
                      ),
                      if (response?.profile != null) ...[
                        const SizedBox(height: 16),
                        Text(response!.summary),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            _applyProfileDraft(response!.profile!, profile);
                            Navigator.of(dialogContext).pop();
                          },
                          icon: const Icon(Icons.post_add_rounded),
                          label: const Text('Apply to Profile Form'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
    promptController.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final roleData = <String, dynamic>{};
    for (final field in _fieldsForRole(widget.role)) {
      final value = _controller(field.key).text.trim();
      roleData[field.key] = switch (field.type) {
        _FieldType.list =>
          value
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
        _FieldType.integer => int.tryParse(value) ?? 0,
        _FieldType.decimal => double.tryParse(value) ?? 0,
        _FieldType.text => value,
      };
    }

    final success = await ref
        .read(profileActionProvider.notifier)
        .saveProfile(
          role: widget.role,
          userData: {
            'fullName': _controller('fullName').text.trim(),
            'phone': _controller('phone').text.trim(),
            'gender': _controller('gender').text.trim(),
            'dateOfBirth': DateTime.tryParse(
              _controller('dateOfBirth').text.trim(),
            ),
            'country': _controller('country').text.trim(),
            'city': _controller('city').text.trim(),
            'bio': _controller('personalBio').text.trim(),
          },
          roleData: roleData,
        );
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          backgroundColor: AppColors.successDark,
        ),
      );
      context.pop();
      return;
    }

    final error =
        ref.read(profileActionProvider.notifier).errorMessage ??
        'Unable to update profile.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileDataProvider);
    final actionState = ref.watch(profileActionProvider);
    final theme = Theme.of(context);
    final roleTheme = getRoleTheme(widget.role);

    return RoleFixedHeaderPage(
      role: widget.role,
      title: 'Edit ${widget.role.label} Profile',
      subtitle:
          'Update your profile image, personal details, and role information.',
      showBackButton: true,
      scrollable: false,
      actions: [
        if (widget.role == UserRole.freelancer)
          IconButton(
            tooltip: 'Improve with AI',
            onPressed: () {
              final profile = ref.read(profileDataProvider).value;
              if (profile == null) return;
              _openProfileAi(profile);
            },
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
      ],
      child: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (profile) {
          if (profile == null || profile.role != widget.role) {
            return const Center(child: Text('Profile data is unavailable.'));
          }
          _initialize(profile);
          final displayName = widget.role == UserRole.company
              ? _controller('companyName').text
              : _controller('fullName').text;
          final fallback = displayName.trim().isEmpty
              ? 'U'
              : displayName.trim()[0].toUpperCase();

          final personalKeys = ['fullName', 'gender', 'dateOfBirth'];
          final contactKeys = [
            'email',
            'officialEmail',
            'phone',
            'phoneNumber',
            'country',
            'city',
          ];
          final professionalKeys = [
            'companyName',
            'professionalTitle',
            'category',
            'industry',
            'companySize',
            'foundedYear',
            'experienceYears',
            'hourlyRate',
            'educationLevel',
            'institute',
            'degree',
            'fieldOfStudy',
            'graduationYear',
            'careerGoal',
            'personalBio',
            'bio',
            'description',
          ];
          final expertiseKeys = [
            'skills',
            'interestedSkills',
            'subjects',
            'skillsTaught',
            'certifications',
            'specializations',
            'services',
          ];
          final portfolioKeys = [
            'portfolio',
            'portfolioWebsite',
            'website',
            'portfolioLinks',
            'linkedin',
            'github',
            'behance',
            'dribbble',
          ];

          return LoadingOverlay(
            isLoading: actionState.isLoading,
            message: 'Saving Profile...',
            child: Stack(
              children: [
                SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Profile Image',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 24),
                                  ProfileImagePicker(
                                    role: widget.role,
                                    imageUrl: profile.user.profileImage,
                                    fallbackText: fallback,
                                  ),
                                ],
                              ),
                            ),
                            _buildSectionCard(
                              'Personal Information',
                              personalKeys,
                              Icons.person_outline_rounded,
                              roleTheme,
                            ),
                            _buildSectionCard(
                              'Contact Details',
                              contactKeys,
                              Icons.contact_mail_outlined,
                              roleTheme,
                            ),
                            _buildSectionCard(
                              'Professional Dossier',
                              professionalKeys,
                              Icons.work_outline_rounded,
                              roleTheme,
                            ),
                            _buildSectionCard(
                              'Expertise & Skills',
                              expertiseKeys,
                              Icons.psychology_outlined,
                              roleTheme,
                            ),
                            _buildSectionCard(
                              'Network & Portfolio',
                              portfolioKeys,
                              Icons.language_rounded,
                              roleTheme,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: SizedBox(
                        height: 64,
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: actionState.isLoading ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: roleTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: actionState.isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline_rounded),
                          label: actionState.isLoading
                              ? const SizedBox.shrink()
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionCard(
    String title,
    List<String> sectionKeys,
    IconData icon,
    RoleThemeColors roleTheme,
  ) {
    final children = _getFieldsForSection(sectionKeys);
    if (children.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: roleTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: roleTheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ...children,
        ],
      ),
    );
  }

  List<Widget> _getFieldsForSection(List<String> keys) {
    final widgets = <Widget>[];
    for (final key in keys) {
      if (key == 'fullName') {
        widgets.add(
          _buildSharedField(
            'fullName',
            widget.role == UserRole.company
                ? 'Account Contact Name'
                : 'Full Name',
            validator: _required,
          ),
        );
      } else if (key == 'email') {
        widgets.add(_buildSharedField('email', 'Email', enabled: false));
      } else if (key == 'phone') {
        widgets.add(
          _buildSharedField(
            'phone',
            'Phone',
            keyboardType: TextInputType.phone,
          ),
        );
      } else if (key == 'gender') {
        widgets.add(_buildSharedField('gender', 'Gender'));
      } else if (key == 'dateOfBirth') {
        widgets.add(
          _buildSharedField(
            'dateOfBirth',
            'Date of Birth',
            hint: 'YYYY-MM-DD',
            keyboardType: TextInputType.datetime,
            validator: _optionalDate,
          ),
        );
      } else if (key == 'country') {
        widgets.add(_buildSharedField('country', 'Country'));
      } else if (key == 'city') {
        widgets.add(_buildSharedField('city', 'City'));
      } else if (key == 'personalBio') {
        widgets.add(
          _buildSharedField('personalBio', 'Personal Bio', maxLines: 4),
        );
      } else {
        final roleFields = _fieldsForRole(widget.role);
        final fieldIndex = roleFields.indexWhere((f) => f.key == key);
        if (fieldIndex != -1) {
          final field = roleFields[fieldIndex];
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: CustomTextField(
                controller: _controller(field.key),
                label: field.label,
                hint: field.hint,
                maxLines: field.maxLines,
                keyboardType: switch (field.type) {
                  _FieldType.integer => TextInputType.number,
                  _FieldType.decimal => const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  _ => field.keyboardType,
                },
                validator: field.required ? _required : null,
              ),
            ),
          );
        }
      }
    }
    return widgets;
  }

  Widget _buildSharedField(
    String key,
    String label, {
    bool enabled = true,
    TextInputType? keyboardType,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: CustomTextField(
        controller: _controller(key),
        label: label,
        enabled: enabled,
        keyboardType: keyboardType,
        hint: hint,
        maxLines: maxLines,
        validator: validator,
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? _optionalDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim()) == null
        ? 'Use the YYYY-MM-DD format'
        : null;
  }
}

enum _FieldType { text, list, integer, decimal }

class _FieldSpec {
  const _FieldSpec(
    this.key,
    this.label, {
    this.hint,
    this.type = _FieldType.text,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String key;
  final String label;
  final String? hint;
  final _FieldType type;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
}

List<_FieldSpec> _fieldsForRole(UserRole role) {
  return switch (role) {
    UserRole.student => const [
      _FieldSpec('educationLevel', 'Education Level', required: true),
      _FieldSpec('institute', 'Institute', required: true),
      _FieldSpec('degree', 'Degree'),
      _FieldSpec('fieldOfStudy', 'Field of Study', required: true),
      _FieldSpec('graduationYear', 'Graduation Year', type: _FieldType.integer),
      _FieldSpec(
        'skills',
        'Skills',
        hint: 'Comma separated',
        type: _FieldType.list,
      ),
      _FieldSpec(
        'interestedSkills',
        'Interested Skills',
        hint: 'Comma separated',
        type: _FieldType.list,
      ),
      _FieldSpec('careerGoal', 'Career Goal', maxLines: 3),
      _FieldSpec('linkedin', 'LinkedIn', keyboardType: TextInputType.url),
      _FieldSpec('github', 'GitHub', keyboardType: TextInputType.url),
      _FieldSpec('behance', 'Behance', keyboardType: TextInputType.url),
      _FieldSpec('dribbble', 'Dribbble', keyboardType: TextInputType.url),
      _FieldSpec(
        'portfolioWebsite',
        'Portfolio Website',
        keyboardType: TextInputType.url,
      ),
    ],
    UserRole.teacher => const [
      _FieldSpec('professionalTitle', 'Professional Title', required: true),
      _FieldSpec(
        'experienceYears',
        'Experience Years',
        type: _FieldType.integer,
        required: true,
      ),
      _FieldSpec('industry', 'Industry', required: true),
      _FieldSpec(
        'subjects',
        'Subjects',
        hint: 'Comma separated',
        type: _FieldType.list,
      ),
      _FieldSpec(
        'skillsTaught',
        'Skills Taught',
        hint: 'Comma separated',
        type: _FieldType.list,
      ),
      _FieldSpec(
        'certifications',
        'Certifications',
        hint: 'Comma separated',
        type: _FieldType.list,
      ),
      _FieldSpec(
        'specializations',
        'Specializations',
        hint: 'Comma separated',
        type: _FieldType.list,
      ),
      _FieldSpec('linkedin', 'LinkedIn', keyboardType: TextInputType.url),
      _FieldSpec('github', 'GitHub', keyboardType: TextInputType.url),
      _FieldSpec('behance', 'Behance', keyboardType: TextInputType.url),
      _FieldSpec('dribbble', 'Dribbble', keyboardType: TextInputType.url),
      _FieldSpec('website', 'Website', keyboardType: TextInputType.url),
      _FieldSpec('bio', 'Bio', maxLines: 4),
    ],
    UserRole.freelancer => const [
      _FieldSpec('professionalTitle', 'Professional Title', required: true),
      _FieldSpec('category', 'Category', required: true),
      _FieldSpec(
        'experienceYears',
        'Experience Years',
        type: _FieldType.integer,
        required: true,
      ),
      _FieldSpec(
        'services',
        'Services',
        hint: 'Comma separated',
        type: _FieldType.list,
        required: true,
      ),
      _FieldSpec(
        'skills',
        'Skills',
        hint: 'Comma separated',
        type: _FieldType.list,
      ),
      _FieldSpec(
        'hourlyRate',
        'Hourly Rate',
        type: _FieldType.decimal,
        required: true,
      ),
      _FieldSpec('portfolio', 'Portfolio', keyboardType: TextInputType.url),
      _FieldSpec(
        'portfolioLinks',
        'Portfolio Links',
        hint: 'Comma separated',
        type: _FieldType.list,
      ),
      _FieldSpec('linkedin', 'LinkedIn', keyboardType: TextInputType.url),
      _FieldSpec('github', 'GitHub', keyboardType: TextInputType.url),
      _FieldSpec('behance', 'Behance', keyboardType: TextInputType.url),
      _FieldSpec('dribbble', 'Dribbble', keyboardType: TextInputType.url),
      _FieldSpec('website', 'Website', keyboardType: TextInputType.url),
      _FieldSpec('bio', 'Bio', maxLines: 4),
    ],
    UserRole.company => const [
      _FieldSpec('companyName', 'Company Name', required: true),
      _FieldSpec('industry', 'Industry', required: true),
      _FieldSpec('companySize', 'Company Size', required: true),
      _FieldSpec(
        'foundedYear',
        'Founded Year',
        type: _FieldType.integer,
        required: true,
      ),
      _FieldSpec('website', 'Website', keyboardType: TextInputType.url),
      _FieldSpec('linkedin', 'LinkedIn', keyboardType: TextInputType.url),
      _FieldSpec('github', 'GitHub', keyboardType: TextInputType.url),
      _FieldSpec('behance', 'Behance', keyboardType: TextInputType.url),
      _FieldSpec('dribbble', 'Dribbble', keyboardType: TextInputType.url),
      _FieldSpec(
        'officialEmail',
        'Official Email',
        keyboardType: TextInputType.emailAddress,
      ),
      _FieldSpec(
        'phoneNumber',
        'Phone Number',
        keyboardType: TextInputType.phone,
      ),
      _FieldSpec('description', 'Description', maxLines: 5),
    ],
    _ => const [],
  };
}
