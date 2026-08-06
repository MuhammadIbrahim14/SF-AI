import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/freelancer_service_model.dart';
import '../../../models/service_request_model.dart';
import '../../../providers/service_request_provider.dart';
import '../../../providers/user_provider.dart';
import '../../marketplace_ai/models/marketplace_ai_draft_models.dart';
import '../../marketplace_ai/widgets/marketplace_ai_notes_draft_dialog.dart';

Future<void> showServiceRequestFormDialog(
  BuildContext context,
  FreelancerServiceModel service,
) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) =>
        _ServiceRequestDialog(service: service, parentContext: context),
  );
}

class _ServiceRequestDialog extends ConsumerStatefulWidget {
  const _ServiceRequestDialog({
    required this.service,
    required this.parentContext,
  });

  final FreelancerServiceModel service;
  final BuildContext parentContext;

  @override
  ConsumerState<_ServiceRequestDialog> createState() =>
      _ServiceRequestDialogState();
}

class _ServiceRequestDialogState extends ConsumerState<_ServiceRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _projectTitleController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _budgetController = TextEditingController();
  final _currencyController = TextEditingController(text: 'USD');
  final _attachmentsController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _clientEmailController = TextEditingController();
  DateTime? _deadline;
  String _priority = ServiceRequestPriority.normal;
  String? _selectedPackageId;
  bool _hydrated = false;
  bool _pendingAiApplied = false;

  @override
  void dispose() {
    _projectTitleController.dispose();
    _requirementsController.dispose();
    _budgetController.dispose();
    _currencyController.dispose();
    _attachmentsController.dispose();
    _clientNameController.dispose();
    _clientEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final actionState = ref.watch(serviceRequestActionProvider);

    if (user != null && !_hydrated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _hydrated = true;
          _clientNameController.text = user.fullName;
          _clientEmailController.text = user.email;
        });
        _applyPendingAiDraft();
      });
    }

    if (user == null) {
      final returnUrl = RoutePaths.publicServiceDetail.replaceFirst(
        ':serviceId',
        widget.service.serviceId,
      );
      return AlertDialog(
        icon: const Icon(Icons.lock_outline_rounded),
        title: const Text('Login required'),
        content: const Text(
          'Please log in or create a customer account before sending a real service request. This keeps request tracking secure for both client and freelancer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pushNamed(
                RouteNames.signup,
                queryParameters: {'mode': 'customer', 'returnUrl': returnUrl},
              );
            },
            child: const Text('Continue as Customer'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.pushNamed(
                RouteNames.login,
                queryParameters: {'mode': 'customer', 'returnUrl': returnUrl},
              );
            },
            child: const Text('Login'),
          ),
        ],
      );
    }

    final theme = Theme.of(context);
    final packages = widget.service.activePackages;
    final selectedPackage = _selectedPackage(packages);
    if (_selectedPackageId == null && packages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedPackageId = packages.first.packageId;
          _applyPackage(packages.first);
        });
      });
    }
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 850),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Service Request',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.freelancerPrimary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Request ${widget.service.title}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filledTonal(
                    tooltip: 'Fill with AI',
                    onPressed: actionState.isLoading ? null : _openAiDraft,
                    icon: const Icon(Icons.auto_awesome_rounded),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (actionState.isLoading)
              const LinearProgressIndicator(minHeight: 2),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _SectionTitle(
                        title: 'Contact Information',
                        icon: Icons.person_rounded,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _clientNameController,
                        decoration: const InputDecoration(
                          labelText: 'Your name',
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _clientEmailController,
                        decoration: const InputDecoration(
                          labelText: 'Contact email',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (_required(value) != null) return 'Required';
                          return value!.contains('@')
                              ? null
                              : 'Enter a valid email';
                        },
                      ),
                      const SizedBox(height: 32),
                      const _SectionTitle(
                        title: 'Project Details',
                        icon: Icons.description_rounded,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _projectTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Project title',
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _requirementsController,
                        decoration: const InputDecoration(
                          labelText: 'Requirements',
                          alignLabelWithHint: true,
                        ),
                        minLines: 4,
                        maxLines: 6,
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _attachmentsController,
                        decoration: const InputDecoration(
                          labelText: 'Attachment URLs',
                          helperText: 'Optional, one URL per line',
                          alignLabelWithHint: true,
                        ),
                        minLines: 2,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 32),
                      const _SectionTitle(
                        title: 'Budget & Timeline',
                        icon: Icons.payments_rounded,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedPackage.packageId,
                        decoration: const InputDecoration(
                          labelText: 'Service package',
                          helperText:
                              'Price and minimum delivery time are set by the freelancer.',
                        ),
                        items: packages
                            .map(
                              (package) => DropdownMenuItem(
                                value: package.packageId,
                                child: Text(
                                  '${package.title} - ${widget.service.currency} ${package.price.toStringAsFixed(0)} / ${package.deliveryDays} day${package.deliveryDays == 1 ? '' : 's'}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          final package = packages.firstWhere(
                            (item) => item.packageId == value,
                            orElse: () => selectedPackage,
                          );
                          setState(() {
                            _selectedPackageId = package.packageId;
                            _deadline = null;
                            _applyPackage(package);
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _budgetController,
                              decoration: const InputDecoration(
                                labelText: 'Budget',
                              ),
                              readOnly: true,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'),
                                ),
                              ],
                              validator: (value) {
                                final parsed = double.tryParse(
                                  value?.trim() ?? '',
                                );
                                return parsed == null || parsed <= 0
                                    ? 'Enter budget'
                                    : null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 96,
                            child: TextFormField(
                              controller: _currencyController,
                              decoration: const InputDecoration(
                                labelText: 'Currency',
                              ),
                              maxLength: 3,
                              validator: _required,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _priority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: ServiceRequestPriority.low,
                            child: Text('Low'),
                          ),
                          DropdownMenuItem(
                            value: ServiceRequestPriority.normal,
                            child: Text('Normal'),
                          ),
                          DropdownMenuItem(
                            value: ServiceRequestPriority.high,
                            child: Text('High'),
                          ),
                        ],
                        onChanged: (value) => setState(
                          () => _priority =
                              value ?? ServiceRequestPriority.normal,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _deadline == null
                              ? 'No deadline selected'
                              : 'Deadline: ${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
                        ),
                        trailing: OutlinedButton.icon(
                          onPressed: _pickDeadline,
                          icon: const Icon(
                            Icons.calendar_month_rounded,
                            size: 18,
                          ),
                          label: const Text('Pick'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.2,
                ),
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: actionState.isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: actionState.isLoading
                        ? null
                        : () => _submit(user.uid),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Submit Request'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final package = _selectedPackage(widget.service.activePackages);
    final minimumDate = now.add(Duration(days: package.deliveryDays));
    final picked = await showDatePicker(
      context: context,
      firstDate: minimumDate,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _deadline ?? minimumDate,
    );
    if (picked != null && mounted) setState(() => _deadline = picked);
  }

  Future<void> _submit(String clientId) async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    final package = _selectedPackage(widget.service.activePackages);
    final minimumDate = DateTime.now().add(
      Duration(days: package.deliveryDays),
    );
    if (_deadline != null && _deadline!.isBefore(minimumDate)) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid delivery date'),
          content: const Text(
            "Selected delivery date is earlier than the freelancer's package delivery time.",
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }

    final now = DateTime.now();
    final request = ServiceRequestModel(
      requestId: '',
      serviceId: widget.service.serviceId,
      serviceTitle: widget.service.title,
      serviceCategory: widget.service.category,
      freelancerId: widget.service.freelancerId,
      freelancerName: widget.service.freelancerName,
      clientId: clientId,
      clientName: _clientNameController.text.trim(),
      clientEmail: _clientEmailController.text.trim(),
      clientRole: user.primaryRole,
      clientAvatarUrl: user.photoUrl,
      projectTitle: _projectTitleController.text.trim(),
      requirements: _requirementsController.text.trim(),
      budget: package.price,
      currency: _currencyController.text.trim().toUpperCase(),
      selectedPackageId: package.packageId,
      selectedPackageTitle: package.title,
      selectedPackagePrice: package.price,
      selectedDeliveryDays: package.deliveryDays,
      selectedRevisionsIncluded: package.revisionsIncluded,
      deadline: _deadline,
      attachments: _lineList(_attachmentsController.text),
      priority: _priority,
      status: ServiceRequestStatus.pending,
      createdAt: now,
      updatedAt: now,
      acceptedAt: null,
      deliveredAt: null,
      completedAt: null,
      cancelledAt: null,
      freelancerNote: null,
      clientNote: null,
    );

    final parentContext = widget.parentContext;
    final notifier = ref.read(serviceRequestActionProvider.notifier);
    final id = await notifier.createRequest(request);
    if (!mounted || !parentContext.mounted) return;
    if (id == null) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(content: Text(notifier.errorMessage ?? 'Request failed.')),
      );
      return;
    }
    Navigator.of(context).pop();
    if (!parentContext.mounted) return;
    ScaffoldMessenger.of(parentContext).showSnackBar(
      const SnackBar(
        content: Text('Service request sent. Opening request details...'),
        backgroundColor: AppColors.success,
      ),
    );
    parentContext.pushNamed(
      RouteNames.serviceRequestDetail,
      pathParameters: {'requestId': id},
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  ServicePackageModel _selectedPackage(List<ServicePackageModel> packages) {
    if (packages.isEmpty) return widget.service.legacyPackages.first;
    final selectedId = _selectedPackageId;
    if (selectedId == null) return packages.first;
    return packages.firstWhere(
      (package) => package.packageId == selectedId,
      orElse: () => packages.first,
    );
  }

  void _applyPackage(ServicePackageModel package) {
    _budgetController.text = package.price.toStringAsFixed(0);
    _currencyController.text = widget.service.currency;
  }

  void _applyPendingAiDraft() {
    if (_pendingAiApplied) return;
    final pending = MarketplaceAiPendingApply.serviceRequest;
    if (pending == null || pending.isEmpty) return;
    _pendingAiApplied = true;
    MarketplaceAiPendingApply.serviceRequest = null;
    _applyAiServiceRequest(pending);
  }

  Future<void> _openAiDraft() async {
    final user = ref.read(currentUserProvider).value;
    final packages = widget.service.activePackages;
    await MarketplaceAiServiceRequestDialog.show(
      context: context,
      initialPrompt:
          'I want to request "${widget.service.title}". Help me write a clear '
          'project title and requirements for package options: '
          '${packages.map((p) => '${p.title} (${p.packageId})').join(', ')}.',
      safeAppContext: {
        'serviceId': widget.service.serviceId,
        'service': {
          'title': widget.service.title,
          'category': widget.service.category,
          'currency': widget.service.currency,
          'packages': packages
              .map(
                (p) => {
                  'packageId': p.packageId,
                  'title': p.title,
                  'price': p.price,
                  'deliveryDays': p.deliveryDays,
                },
              )
              .toList(),
        },
        'userProfile': {
          'fullName': user?.fullName ?? '',
          'email': user?.email ?? '',
        },
      },
      evidence: MarketplaceAiKnownEvidence(
        knownPackageIds: packages.map((p) => p.packageId).toList(),
        clientName: user?.fullName ?? '',
        clientEmail: user?.email ?? '',
      ),
      onApply: _applyAiServiceRequest,
    );
  }

  void _applyAiServiceRequest(Map<String, dynamic> draft) {
    final parsed = MarketplaceServiceRequestDraft.fromMap(draft);
    final packages = widget.service.activePackages;
    setState(() {
      if (parsed.projectTitle.trim().isNotEmpty) {
        _projectTitleController.text = parsed.projectTitle.trim();
      }
      if (parsed.requirements.trim().isNotEmpty) {
        _requirementsController.text = parsed.requirements.trim();
      }
      if (parsed.attachments.isNotEmpty) {
        _attachmentsController.text = parsed.attachments.join('\n');
      }
      if (parsed.clientName.trim().isNotEmpty) {
        _clientNameController.text = parsed.clientName.trim();
      }
      if (parsed.clientEmail.trim().isNotEmpty) {
        _clientEmailController.text = parsed.clientEmail.trim();
      }
      if (parsed.packageId.trim().isNotEmpty) {
        final match = packages.where((p) => p.packageId == parsed.packageId);
        if (match.isNotEmpty) {
          _selectedPackageId = match.first.packageId;
          _applyPackage(match.first);
        }
      }
      if (parsed.priority == ServiceRequestPriority.low ||
          parsed.priority == ServiceRequestPriority.normal ||
          parsed.priority == ServiceRequestPriority.high) {
        _priority = parsed.priority;
      }
      // Budget/currency stay package-driven — never invent from AI.
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'AI draft applied. Review fields, then Submit Request yourself.',
        ),
      ),
    );
  }
}

List<String> _lineList(String value) {
  return value
      .split(RegExp(r'[\n,]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.freelancerPrimary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
