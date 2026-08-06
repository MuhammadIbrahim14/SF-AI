import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/freelancer_model.dart';
import '../../../models/freelancer_service_model.dart';
import '../../../models/user_role.dart';
import '../../../providers/freelancer_provider.dart';
import '../../../providers/freelancer_service_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../marketplace_ai/models/marketplace_ai_draft_models.dart';
import '../../marketplace_ai/services/marketplace_ai_context_loader.dart';
import '../../marketplace_ai/services/marketplace_ai_draft_history.dart';
import '../../marketplace_ai/services/marketplace_ai_quality_gates.dart';
import '../../marketplace_ai/services/marketplace_ai_sanitize.dart';
import '../../marketplace_ai/widgets/freelancer_ai_service_listing_dialog.dart';

class FreelancerServiceEditorScreen extends ConsumerStatefulWidget {
  const FreelancerServiceEditorScreen({
    super.key,
    this.serviceId,
    this.aiDraft,
  });

  final String? serviceId;

  /// Optional `serviceListing` map from Marketplace AI Apply navigation.
  final Map<String, dynamic>? aiDraft;

  @override
  ConsumerState<FreelancerServiceEditorScreen> createState() =>
      _FreelancerServiceEditorScreenState();
}

class _FreelancerServiceEditorScreenState
    extends ConsumerState<FreelancerServiceEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _shortDescriptionController = TextEditingController();
  final _fullDescriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _startingPriceController = TextEditingController();
  final _estimatedDeliveryController = TextEditingController();
  final _packagesController = TextEditingController();
  final _currencyController = TextEditingController(text: 'USD');
  final _coverImageUrlController = TextEditingController();
  final _galleryUrlsController = TextEditingController();
  final _portfolioLinksController = TextEditingController();
  final _linkedSkillsController = TextEditingController();
  final _linkedCertificateIdsController = TextEditingController();
  final _skillScoreController = TextEditingController();

  String _pricingType = FreelancerServicePricingType.fixed;
  bool _verifiedBadge = false;
  String? _hydratedServiceId;
  bool _hydratedNew = false;
  bool _aiDraftApplied = false;

  bool get _isEditing => widget.serviceId?.trim().isNotEmpty == true;

  bool get _hasDraftContent {
    return _titleController.text.trim().isNotEmpty ||
        _shortDescriptionController.text.trim().isNotEmpty ||
        _fullDescriptionController.text.trim().isNotEmpty ||
        _categoryController.text.trim().isNotEmpty ||
        _tagsController.text.trim().isNotEmpty ||
        _packagesController.text.trim().isNotEmpty ||
        _startingPriceController.text.trim().isNotEmpty;
  }

  bool get _canImproveWithAi => _isEditing || _hasDraftContent;

  @override
  void dispose() {
    _titleController.dispose();
    _shortDescriptionController.dispose();
    _fullDescriptionController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _startingPriceController.dispose();
    _estimatedDeliveryController.dispose();
    _packagesController.dispose();
    _currencyController.dispose();
    _coverImageUrlController.dispose();
    _galleryUrlsController.dispose();
    _portfolioLinksController.dispose();
    _linkedSkillsController.dispose();
    _linkedCertificateIdsController.dispose();
    _skillScoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final freelancer = ref.watch(freelancerProvider).value;
    final serviceAsync = _isEditing
        ? ref.watch(freelancerServiceDetailProvider(widget.serviceId!))
        : const AsyncValue<FreelancerServiceModel?>.data(null);
    final actionState = ref.watch(freelancerServiceActionProvider);
    final service = serviceAsync.value;

    if (_isEditing &&
        service != null &&
        _hydratedServiceId != service.serviceId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _hydrate(service);
        _maybeApplyRouteAiDraft(freelancer: freelancer, service: service);
      });
    }

    if (!_isEditing && !_hydratedNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _hydratedNew = true;
          if (_portfolioLinksController.text.trim().isEmpty) {
            _portfolioLinksController.text = [
              ...?freelancer?.portfolioLinks,
              if ((freelancer?.portfolio ?? '').trim().isNotEmpty)
                freelancer!.portfolio,
            ].join('\n');
          }
          if (_linkedSkillsController.text.trim().isEmpty) {
            _linkedSkillsController.text = freelancer?.skills.join(', ') ?? '';
          }
          if (_categoryController.text.trim().isEmpty) {
            _categoryController.text = freelancer?.category ?? '';
          }
        });
        _maybeApplyRouteAiDraft(freelancer: freelancer, service: service);
      });
    }

    return RoleFixedHeaderPage(
      role: UserRole.freelancer,
      title: _isEditing ? 'Edit Service' : 'Create Service',
      subtitle:
          'Use URL-based proof only in FM3A. Upload galleries and marketplace requests come later.',
      showBackButton: true,
      actions: [
        OutlinedButton.icon(
          onPressed: actionState.isLoading
              ? null
              : () => _openAiListingDialog(
                    improve: false,
                    freelancer: freelancer,
                    service: service,
                  ),
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: const Text('Create with AI'),
        ),
        if (_canImproveWithAi)
          OutlinedButton.icon(
            onPressed: actionState.isLoading
                ? null
                : () => _openAiListingDialog(
                      improve: true,
                      freelancer: freelancer,
                      service: service,
                    ),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Improve with AI'),
          ),
        OutlinedButton.icon(
          onPressed: actionState.isLoading ? null : _showDraftHistory,
          icon: const Icon(Icons.history_rounded, size: 18),
          label: const Text('AI Drafts'),
        ),
        OutlinedButton.icon(
          onPressed: actionState.isLoading ? null : () => _save(false, service),
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Save Draft'),
        ),
        FilledButton.icon(
          onPressed: actionState.isLoading
              ? null
              : () => _saveWithQualityCheck(true, service),
          icon: const Icon(Icons.public_rounded, size: 18),
          label: const Text('Publish'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
        child: serviceAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (_) {
            if (_isEditing && service == null) {
              return const Center(child: Text('Service not found.'));
            }
            return Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (actionState.isLoading)
                    const LinearProgressIndicator(minHeight: 2),
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: AppColors.freelancerPrimary.withValues(alpha: 0.08),
                      border: Border.all(
                        color: AppColors.freelancerPrimary.withValues(
                          alpha: 0.24,
                        ),
                      ),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.freelancerPrimary,
                        ),
                        const Text(
                          'SkillForge AI can draft or improve this listing. Preview first, then apply manually. Publish stays yours.',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        OutlinedButton.icon(
                          onPressed: actionState.isLoading
                              ? null
                              : () => _openAiListingDialog(
                                    improve: _canImproveWithAi,
                                    freelancer: freelancer,
                                    service: service,
                                  ),
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: Text(
                            _canImproveWithAi
                                ? 'Improve with AI'
                                : 'Create with AI',
                          ),
                        ),
                      ],
                    ),
                  ),
                  _EditorSection(
                    title: 'Identity',
                    icon: Icons.badge_rounded,
                    children: [
                      _TextInput(
                        controller: _titleController,
                        label: 'Title',
                        maxLength: 90,
                        validator: _required,
                      ),
                      _TextInput(
                        controller: _shortDescriptionController,
                        label: 'Short description',
                        maxLength: 180,
                        maxLines: 2,
                        validator: _required,
                      ),
                      _TextInput(
                        controller: _fullDescriptionController,
                        label: 'Full description',
                        maxLines: 5,
                        validator: _required,
                      ),
                      _TextInput(
                        controller: _categoryController,
                        label: 'Category',
                        validator: _required,
                      ),
                      _TextInput(
                        controller: _tagsController,
                        label: 'Tags',
                        helperText: 'Comma separated, e.g. Flutter, Firebase',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _EditorSection(
                    title: 'Pricing',
                    icon: Icons.payments_rounded,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _pricingType,
                        decoration: const InputDecoration(
                          labelText: 'Pricing type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: FreelancerServicePricingType.fixed,
                            child: Text('Fixed'),
                          ),
                          DropdownMenuItem(
                            value: FreelancerServicePricingType.hourly,
                            child: Text('Hourly'),
                          ),
                        ],
                        onChanged: (value) => setState(
                          () => _pricingType =
                              value ?? FreelancerServicePricingType.fixed,
                        ),
                      ),
                      _TextInput(
                        controller: _startingPriceController,
                        label: 'Starting price',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        validator: _priceValidator,
                      ),
                      _TextInput(
                        controller: _estimatedDeliveryController,
                        label: 'Estimated delivery',
                        helperText: 'Example: 3 days, 1 week, or hourly',
                        validator: _required,
                      ),
                      _TextInput(
                        controller: _packagesController,
                        label: 'Packages',
                        helperText:
                            'One per line: Title | Price | Days | Revisions | Description',
                        maxLines: 4,
                      ),
                      _TextInput(
                        controller: _currencyController,
                        label: 'Currency',
                        maxLength: 3,
                        validator: _required,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _EditorSection(
                    title: 'Portfolio Proof',
                    icon: Icons.link_rounded,
                    children: [
                      _TextInput(
                        controller: _coverImageUrlController,
                        label: 'Cover image URL',
                        keyboardType: TextInputType.url,
                      ),
                      _TextInput(
                        controller: _galleryUrlsController,
                        label: 'Gallery URLs',
                        helperText: 'One URL per line',
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                      ),
                      _TextInput(
                        controller: _portfolioLinksController,
                        label: 'Portfolio links',
                        helperText: 'One URL per line',
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _EditorSection(
                    title: 'Trust Signals',
                    icon: Icons.verified_rounded,
                    children: [
                      _TextInput(
                        controller: _linkedSkillsController,
                        label: 'Linked skills',
                        helperText:
                            'Prefer verified skills from Freelancer Bridge (comma separated)',
                      ),
                      _TextInput(
                        controller: _linkedCertificateIdsController,
                        label: 'Linked certificate IDs',
                        helperText: 'Comma separated existing certificate IDs',
                      ),
                      _TextInput(
                        controller: _skillScoreController,
                        label: 'Skill score',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                      ),
                      SwitchListTile(
                        value: _verifiedBadge,
                        onChanged: (value) =>
                            setState(() => _verifiedBadge = value),
                        title: const Text('Show verified badge'),
                        subtitle: const Text(
                          'Use only when the profile has real SkillForge proof.',
                        ),
                        activeThumbColor: AppColors.freelancerPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: actionState.isLoading
                            ? null
                            : () => _save(false, service),
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Save Draft'),
                      ),
                      FilledButton.icon(
                        onPressed: actionState.isLoading
                            ? null
                            : () => _save(true, service),
                        icon: const Icon(Icons.public_rounded, size: 18),
                        label: const Text('Publish'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _hydrate(FreelancerServiceModel service) {
    setState(() {
      _hydratedServiceId = service.serviceId;
      _titleController.text = service.title;
      _shortDescriptionController.text = service.shortDescription;
      _fullDescriptionController.text = service.fullDescription;
      _categoryController.text = service.category;
      _tagsController.text = service.tags.join(', ');
      _pricingType = service.pricingType;
      _startingPriceController.text = service.startingPrice == 0
          ? ''
          : service.startingPrice.toStringAsFixed(0);
      _estimatedDeliveryController.text = service.estimatedDelivery;
      _packagesController.text = _packagesText(service);
      _currencyController.text = service.currency;
      _coverImageUrlController.text = service.coverImageUrl;
      _galleryUrlsController.text = service.galleryUrls.join('\n');
      _portfolioLinksController.text = service.portfolioLinks.join('\n');
      _linkedCertificateIdsController.text = service.linkedCertificateIds.join(
        ', ',
      );
      _linkedSkillsController.text = service.linkedSkills.join(', ');
      _skillScoreController.text = service.skillScore == 0
          ? ''
          : service.skillScore.toStringAsFixed(0);
      _verifiedBadge = service.verifiedBadge;
    });
  }

  void _maybeApplyRouteAiDraft({
    FreelancerModel? freelancer,
    FreelancerServiceModel? service,
  }) {
    if (_aiDraftApplied) return;
    final pending = MarketplaceAiPendingApply.serviceListing;
    final draft = widget.aiDraft ?? pending;
    if (draft == null || draft.isEmpty) {
      _aiDraftApplied = true;
      return;
    }
    if (_isEditing && _hydratedServiceId == null) return;
    _aiDraftApplied = true;
    MarketplaceAiPendingApply.serviceListing = null;
    _applyAiServiceListing(
      draft,
      freelancer: freelancer,
      service: service,
    );
    _showSnack('AI draft applied. Review fields, then Save Draft or Publish.');
  }

  void _openAiListingDialog({
    required bool improve,
    FreelancerModel? freelancer,
    FreelancerServiceModel? service,
  }) {
    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      _showSnack('A signed-in freelancer is required.');
      return;
    }

    FreelancerAiServiceListingDialog.show(
      context: context,
      freelancerId: user.uid,
      freelancerName: user.fullName,
      freelancer: freelancer,
      existingService: service,
      draftFields: _draftFieldsForAi(),
      platformSkillScore: service != null && service.skillScore > 0
          ? service.skillScore
          : double.tryParse(_skillScoreController.text.trim()),
      knownCertificateIds: [
        ..._commaList(_linkedCertificateIdsController.text),
        ...?service?.linkedCertificateIds,
      ],
      improve: improve,
      onApply: (listing) => _applyAiServiceListing(
        listing,
        freelancer: freelancer,
        service: service,
      ),
    );
  }

  Map<String, dynamic> _draftFieldsForAi() {
    return {
      'title': _titleController.text.trim(),
      'shortDescription': _shortDescriptionController.text.trim(),
      'fullDescription': _fullDescriptionController.text.trim(),
      'category': _categoryController.text.trim(),
      'tags': _commaList(_tagsController.text),
      'pricingType': _pricingType,
      'startingPrice':
          double.tryParse(_startingPriceController.text.trim()) ?? 0,
      'estimatedDelivery': _estimatedDeliveryController.text.trim(),
      'packagesText': _packagesController.text.trim(),
      'currency': _currencyController.text.trim(),
      'coverImageUrl': _coverImageUrlController.text.trim(),
      'galleryUrls': _lineList(_galleryUrlsController.text),
      'portfolioLinks': _lineList(_portfolioLinksController.text),
      'linkedSkills': _commaList(_linkedSkillsController.text),
      'linkedCertificateIds': _commaList(_linkedCertificateIdsController.text),
      'skillScore': double.tryParse(_skillScoreController.text.trim()),
    };
  }

  Future<void> _applyAiServiceListing(
    Map<String, dynamic> listing, {
    FreelancerModel? freelancer,
    FreelancerServiceModel? service,
  }) async {
    final previousPackages = _packagesController.text;
    final loader = MarketplaceAiContextLoader();
    final safeContext = loader.buildServiceListingContext(
      freelancerId: service?.freelancerId ??
          ref.read(currentUserProvider).value?.uid ??
          '',
      freelancerName: service?.freelancerName ??
          ref.read(currentUserProvider).value?.fullName ??
          '',
      freelancer: freelancer,
      existingService: service,
      draftFields: _draftFieldsForAi(),
      serviceId: service?.serviceId ?? widget.serviceId,
      platformSkillScore: service != null && service.skillScore > 0
          ? service.skillScore
          : double.tryParse(_skillScoreController.text.trim()),
      knownCertificateIds: [
        ..._commaList(_linkedCertificateIdsController.text),
        ...?service?.linkedCertificateIds,
      ],
    );
    final evidence = loader.evidenceFromContext(safeContext);
    final sanitized = MarketplaceAiSanitize.sanitizeServiceListing(
      MarketplaceServiceListingDraft.fromMap(listing),
      evidence: evidence,
    );

    String text(String value, String fallback) =>
        value.trim().isNotEmpty ? value.trim() : fallback;

    setState(() {
      _titleController.text = text(sanitized.title, _titleController.text);
      _shortDescriptionController.text = text(
        sanitized.shortDescription,
        _shortDescriptionController.text,
      );
      _fullDescriptionController.text = text(
        sanitized.fullDescription,
        _fullDescriptionController.text,
      );
      _categoryController.text = text(
        sanitized.category,
        _categoryController.text,
      );
      if (sanitized.tags.isNotEmpty) {
        _tagsController.text = sanitized.tags.join(', ');
      }
      if (sanitized.pricingType == FreelancerServicePricingType.fixed ||
          sanitized.pricingType == FreelancerServicePricingType.hourly) {
        _pricingType = sanitized.pricingType;
      }
      if (sanitized.startingPrice != null && sanitized.startingPrice! > 0) {
        final price = sanitized.startingPrice!;
        _startingPriceController.text = price == price.roundToDouble()
            ? price.toStringAsFixed(0)
            : price.toString();
      }
      _estimatedDeliveryController.text = text(
        sanitized.estimatedDelivery,
        _estimatedDeliveryController.text,
      );
      if (sanitized.packages.isNotEmpty) {
        _packagesController.text = sanitized.packagesPipeText;
      }
      _currencyController.text = text(
        sanitized.currency,
        _currencyController.text.isEmpty ? 'USD' : _currencyController.text,
      );
      if (sanitized.coverImageUrl.trim().isNotEmpty) {
        _coverImageUrlController.text = sanitized.coverImageUrl.trim();
      }
      if (sanitized.galleryUrls.isNotEmpty) {
        _galleryUrlsController.text = sanitized.galleryUrls.join('\n');
      }
      if (sanitized.portfolioLinks.isNotEmpty) {
        _portfolioLinksController.text = sanitized.portfolioLinks.join('\n');
      }
      if (sanitized.linkedSkills.isNotEmpty) {
        _linkedSkillsController.text = sanitized.linkedSkills.join(', ');
      }
      if (sanitized.linkedCertificateIds.isNotEmpty) {
        _linkedCertificateIdsController.text = sanitized.linkedCertificateIds
            .join(', ');
      }
      if (sanitized.skillScore != null && sanitized.skillScore! > 0) {
        final score = sanitized.skillScore!;
        _skillScoreController.text = score == score.roundToDouble()
            ? score.toStringAsFixed(0)
            : score.toString();
      }
      // Never set _verifiedBadge from AI (suggestedVerifiedBadge ignored).
    });

    // Soft pricing advisory — show tier suggestions; Apply only on confirm.
    if (sanitized.packages.length >= 2) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pricing / package advisory'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI suggested package tiers. Confirm to keep them in the form. '
                'Live published prices are never changed silently.',
              ),
              const SizedBox(height: 8),
              SelectableText(sanitized.packagesPipeText),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep current packages'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Keep AI packages'),
            ),
          ],
        ),
      );
      if (confirm == false && mounted) {
        setState(() {
          _packagesController.text = previousPackages;
        });
      }
    }

    final warnings = MarketplaceAiQualityGates.listingWarnings(sanitized);
    if (warnings.isNotEmpty && mounted) {
      _showSnack('Applied with notes: ${warnings.take(2).join(' ')}');
    }
  }

  Future<void> _saveWithQualityCheck(
    bool publish,
    FreelancerServiceModel? existing,
  ) async {
    final warnings = MarketplaceAiQualityGates.listingWarningsFromControllers(
      title: _titleController.text,
      shortDescription: _shortDescriptionController.text,
      fullDescription: _fullDescriptionController.text,
      packagesText: _packagesController.text,
      linkedSkills: _linkedSkillsController.text,
      startingPrice: _startingPriceController.text,
    );
    if (warnings.isNotEmpty && publish) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Soft quality checks'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'These are warnings only — they do not block publish:',
              ),
              const SizedBox(height: 8),
              for (final warning in warnings) Text('• $warning'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Review'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Publish anyway'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    await _save(publish, existing);
  }

  Future<void> _showDraftHistory() async {
    final history = MarketplaceAiDraftHistoryStore();
    final items = await history.listRecent();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recent AI drafts'),
        content: SizedBox(
          width: 520,
          child: items.isEmpty
              ? const Text('No saved AI drafts yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.title),
                      subtitle: Text(
                        '${item.taskType} · ${item.createdAt.toLocal()}',
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          if (MarketplaceAiTaskType.isServiceListingTask(
                            item.taskType,
                          )) {
                            _applyAiServiceListing(item.applyPayload);
                            _showSnack(
                              'Restored AI draft. Review, then Save Draft or Publish.',
                            );
                          } else {
                            _showSnack(
                              'This draft type is not a service listing.',
                            );
                          }
                        },
                        child: const Text('Apply'),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(bool publish, FreelancerServiceModel? existing) async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      _showSnack('A signed-in freelancer is required.');
      return;
    }

    final now = DateTime.now();
    final status = publish
        ? FreelancerServiceStatus.published
        : existing?.status == FreelancerServiceStatus.hidden
        ? FreelancerServiceStatus.hidden
        : FreelancerServiceStatus.draft;
    final service =
        (existing ??
                FreelancerServiceModel.empty(
                  freelancerId: user.uid,
                  freelancerName: user.fullName,
                  freelancerAvatarUrl: user.photoUrl ?? '',
                ))
            .copyWith(
              freelancerId: user.uid,
              freelancerName: user.fullName,
              freelancerAvatarUrl: user.photoUrl ?? '',
              title: _titleController.text.trim(),
              shortDescription: _shortDescriptionController.text.trim(),
              fullDescription: _fullDescriptionController.text.trim(),
              category: _categoryController.text.trim(),
              tags: _commaList(_tagsController.text),
              pricingType: _pricingType,
              startingPrice:
                  double.tryParse(_startingPriceController.text.trim()) ?? 0,
              estimatedDelivery: _estimatedDeliveryController.text.trim(),
              packages: _parsePackages(
                _packagesController.text,
                double.tryParse(_startingPriceController.text.trim()) ?? 0,
                _estimatedDeliveryController.text.trim(),
              ),
              currency: _currencyController.text.trim().toUpperCase(),
              coverImageUrl: _coverImageUrlController.text.trim(),
              galleryUrls: _lineList(_galleryUrlsController.text),
              portfolioLinks: _lineList(_portfolioLinksController.text),
              linkedCertificateIds: _commaList(
                _linkedCertificateIdsController.text,
              ),
              linkedSkills: _commaList(_linkedSkillsController.text),
              skillScore:
                  (double.tryParse(_skillScoreController.text.trim()) ?? 0)
                      .clamp(0, 100)
                      .toDouble(),
              verifiedBadge: _verifiedBadge,
              status: status,
              isPublished: status == FreelancerServiceStatus.published,
              updatedAt: now,
              publishedAt: status == FreelancerServiceStatus.published
                  ? existing?.publishedAt ?? now
                  : null,
              clearPublishedAt: status != FreelancerServiceStatus.published,
            );

    final notifier = ref.read(freelancerServiceActionProvider.notifier);
    final ok = existing == null
        ? await notifier.createService(service) != null
        : await notifier.updateService(service);
    if (!mounted) return;
    if (!ok) {
      _showSnack(notifier.errorMessage ?? 'Service could not be saved.');
      return;
    }
    _showSnack(publish ? 'Service published.' : 'Service saved.');
    context.goNamed(RouteNames.freelancerServices);
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? _priceValidator(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) return 'Enter a valid price';
    return null;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

List<ServicePackageModel> _parsePackages(
  String value,
  double startingPrice,
  String estimatedDelivery,
) {
  final parsed = <ServicePackageModel>[];
  final lines = value
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  for (var index = 0; index < lines.length; index++) {
    final parts = lines[index].split('|').map((part) => part.trim()).toList();
    if (parts.length < 3) continue;
    final title = parts[0];
    final price = double.tryParse(parts[1]) ?? 0;
    final deliveryDays = int.tryParse(parts[2]) ?? 0;
    final revisions = parts.length >= 4 ? int.tryParse(parts[3]) ?? 1 : 1;
    final description = parts.length >= 5 ? parts.sublist(4).join(' | ') : '';
    if (title.isEmpty || price <= 0 || deliveryDays < 1) continue;
    parsed.add(
      ServicePackageModel(
        packageId: _packageId(title, index),
        title: title,
        description: description,
        price: price,
        deliveryDays: deliveryDays.clamp(1, 365).toInt(),
        revisionsIncluded: revisions.clamp(0, 20).toInt(),
        isActive: true,
      ),
    );
  }
  if (parsed.isNotEmpty) return parsed;
  return [
    ServicePackageModel(
      packageId: 'legacy_standard',
      title: 'Standard',
      description: estimatedDelivery.trim().isEmpty
          ? 'Standard service package'
          : estimatedDelivery,
      price: startingPrice,
      deliveryDays: _deliveryDaysFromText(estimatedDelivery),
      revisionsIncluded: 1,
      isActive: true,
    ),
  ];
}

String _packagesText(FreelancerServiceModel service) {
  final packages = service.packages.isEmpty
      ? service.legacyPackages
      : service.packages;
  return packages
      .map(
        (package) =>
            '${package.title} | ${package.price.toStringAsFixed(0)} | ${package.deliveryDays} | ${package.revisionsIncluded} | ${package.description}',
      )
      .join('\n');
}

String _packageId(String title, int index) {
  final slug = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return slug.isEmpty ? 'package_$index' : slug;
}

int _deliveryDaysFromText(String value) {
  final match = RegExp(r'\d+').firstMatch(value);
  final parsed = int.tryParse(match?.group(0) ?? '') ?? 7;
  return parsed.clamp(1, 365).toInt();
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.freelancerPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 820;
                if (!twoColumns) {
                  return Column(
                    children: children
                        .map(
                          (child) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: child,
                          ),
                        )
                        .toList(),
                  );
                }
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: children
                      .map(
                        (child) => SizedBox(
                          width: (constraints.maxWidth - 14) / 2,
                          child: child,
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    this.helperText,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

List<String> _commaList(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();
}

List<String> _lineList(String value) {
  return value
      .split(RegExp(r'[\n,]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();
}
