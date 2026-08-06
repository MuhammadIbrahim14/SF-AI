import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/customer_workspace_shell.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../ai_usage/models/ai_usage_models.dart';
import '../../ai_usage/widgets/skillforge_ai_widgets.dart';
import '../../admin/presentation/widgets/admin_control_scaffold.dart';
import '../../copilot/config/copilot_ai_config.dart';
import '../../copilot/models/copilot_ai_request_model.dart';
import '../../copilot/models/copilot_ai_response_model.dart';
import '../../copilot/services/ai_gateway_client.dart';
import '../models/marketplace_ai_draft_models.dart';
import '../services/marketplace_ai_context_loader.dart';
import '../services/marketplace_ai_sanitize.dart';
import '../widgets/marketplace_ai_draft_panel.dart';

class FreelancerAiAssistantScreen extends StatelessWidget {
  const FreelancerAiAssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleFixedHeaderPage(
      role: UserRole.freelancer,
      title: 'Freelancer AI Assistant',
      subtitle: 'Draft proposals, services, updates, and dispute evidence.',
      scrollable: false,
      child: _MarketplaceAiAssistant(
        role: 'freelancer',
        accountType: 'professional',
        title: 'Freelancer AI Assistant',
        subtitle: 'Create better client-facing drafts using real AI.',
        accent: AppColors.freelancerPrimary,
        tasks: _freelancerTasks,
      ),
    );
  }
}

class CustomerAiAssistantScreen extends StatelessWidget {
  const CustomerAiAssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomerWorkspaceShell(
      child: _MarketplaceAiAssistant(
        role: 'customer',
        accountType: 'customer',
        title: 'Customer AI Assistant',
        subtitle: 'Turn rough ideas into clear project briefs and messages.',
        accent: AppColors.studentPrimary,
        tasks: _customerTasks,
      ),
    );
  }
}

class AdminResolutionAiAnalystScreen extends StatelessWidget {
  const AdminResolutionAiAnalystScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminControlScaffold(
      title: 'Resolution AI Analyst',
      subtitle:
          'Read-only dispute analysis, timelines, risks, and draft decisions.',
      currentPath: RoutePaths.adminResolutionAiAnalyst,
      body: _MarketplaceAiAssistant(
        role: 'admin',
        accountType: 'professional',
        title: 'Resolution AI Analyst',
        subtitle: 'Analyze evidence without executing settlement actions.',
        accent: AppColors.adminPrimary,
        tasks: _adminResolutionTasks,
        adminMode: true,
      ),
    );
  }
}

class _MarketplaceAiAssistant extends ConsumerStatefulWidget {
  const _MarketplaceAiAssistant({
    required this.role,
    required this.accountType,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.tasks,
    this.adminMode = false,
  });

  final String role;
  final String accountType;
  final String title;
  final String subtitle;
  final Color accent;
  final List<_AiTaskOption> tasks;
  final bool adminMode;

  @override
  ConsumerState<_MarketplaceAiAssistant> createState() =>
      _MarketplaceAiAssistantState();
}

class _MarketplaceAiAssistantState
    extends ConsumerState<_MarketplaceAiAssistant> {
  late _AiTaskOption _selected = widget.tasks.first;
  final _promptController = TextEditingController();
  final _contextLoader = MarketplaceAiContextLoader();
  bool _loading = false;
  bool _healthLoading = false;
  bool _initialQueryApplied = false;
  bool _hydratingContext = false;
  Map<String, dynamic>? _health;
  Map<String, dynamic> _hydratedContext = const {};
  CopilotAiResponseModel? _response;
  MarketplaceAiDraftResponse? _draftResponse;
  late final AiGatewayClient _gatewayClient;

  @override
  void initState() {
    super.initState();
    _gatewayClient = AiGatewayClient(baseUrl: CopilotAiConfig.gatewayBaseUrl);
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = GoRouterState.of(context).uri.queryParameters;
    if (!_initialQueryApplied) {
      _initialQueryApplied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyInitialQuery(params);
        _checkHealth();
      });
    }
    final contextFields = _contextFields(params);
    final taskCost = AiUsageDefaults.featureCosts[_selected.taskType] ?? 1;
    final content = ListView(
      padding: widget.adminMode
          ? const EdgeInsets.all(20)
          : const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        _HeroCard(
          title: widget.title,
          subtitle: widget.subtitle,
          accent: widget.accent,
        ),
        const SizedBox(height: 16),
        _GatewayStatusCard(
          health: _health,
          loading: _healthLoading,
          gatewayUrl: CopilotAiConfig.gatewayBaseUrl,
          onRetry: _checkHealth,
        ),
        const SizedBox(height: 16),
        SkillForgeAiCreditBalanceCard(compact: !widget.adminMode),
        const SizedBox(height: 16),
        _ContextCard(
          selected: _selected,
          fields: contextFields,
          accent: widget.accent,
          hydrated: _hydratedContext.isNotEmpty,
          hydrating: _hydratingContext,
        ),
        const SizedBox(height: 16),
        _TaskPicker(
          tasks: widget.tasks,
          selected: _selected,
          accent: widget.accent,
          onChanged: (task) => setState(() => _selected = task),
        ),
        const SizedBox(height: 16),
        _PromptCard(
          controller: _promptController,
          selected: _selected,
          accent: widget.accent,
          loading: _loading,
          cost: taskCost,
          onGenerate: _generate,
        ),
        const SizedBox(height: 16),
        if (_response != null)
          _ResponseCard(
            response: _response!,
            draft: _draftResponse,
            accent: widget.accent,
            selectedTaskType: _selected.taskType,
            onApply: _handleApply,
          ),
      ],
    );

    return widget.adminMode ? content : SafeArea(child: content);
  }

  void _applyInitialQuery(Map<String, String> params) {
    final taskValue = params['task'] ?? '';
    final matching = widget.tasks.where((task) => task.matches(taskValue));
    if (matching.isNotEmpty) {
      setState(() => _selected = matching.first);
    }
    if (_promptController.text.trim().isEmpty) {
      final fields = _contextFields(params);
      _promptController.text = [
        _selected.hint,
        if (fields.isNotEmpty) '',
        if (fields.isNotEmpty) 'Visible workflow context:',
        ...fields.entries.map((entry) => '${entry.key}: ${entry.value}'),
      ].join('\n');
    }
    _hydrateContext(params);
  }

  Future<void> _hydrateContext(Map<String, String> params) async {
    final fields = _contextFields(params);
    if (fields.isEmpty) {
      setState(() => _hydratedContext = const {});
      return;
    }
    setState(() => _hydratingContext = true);
    try {
      final hydrated = await _contextLoader.hydrateIds(
        serviceId: fields['serviceId'],
        requestId: fields['requestId'],
        serviceRequestId: fields['serviceRequestId'],
        orderId: fields['orderId'],
        caseId: fields['caseId'],
      );
      if (!mounted) return;
      setState(() {
        _hydratedContext = hydrated;
        _hydratingContext = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hydratedContext = Map<String, dynamic>.from(fields);
        _hydratingContext = false;
      });
    }
  }

  Map<String, String> _contextFields(Map<String, String> params) {
    final keys = [
      'requestId',
      'serviceRequestId',
      'serviceId',
      'orderId',
      'caseId',
      'applicationId',
    ];
    return {
      for (final key in keys)
        if ((params[key] ?? '').trim().isNotEmpty) key: params[key]!.trim(),
    };
  }

  Future<void> _checkHealth() async {
    setState(() => _healthLoading = true);
    final health = await _gatewayClient.healthCheck();
    if (!mounted) return;
    setState(() {
      _healthLoading = false;
      _health = health;
    });
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      _show('Add context first so AI can produce a useful draft.');
      return;
    }

    setState(() {
      _loading = true;
      _response = null;
      _draftResponse = null;
    });

    final firebaseUser = FirebaseAuth.instance.currentUser;
    final appUser = ref.read(currentUserProvider).value;
    final queryParams = GoRouterState.of(context).uri.queryParameters;
    final idFields = _contextFields(queryParams);
    if (_hydratedContext.isEmpty && idFields.isNotEmpty && !_hydratingContext) {
      await _hydrateContext(queryParams);
    }

    final request = CopilotAiRequestModel(
      requestId:
          '${_selected.taskType}-${DateTime.now().microsecondsSinceEpoch}',
      userId: firebaseUser?.uid ?? appUser?.uid ?? '',
      role: widget.role,
      accountType: widget.accountType,
      taskType: _selected.taskType,
      userMessage: prompt,
      pageContext: {'screen': widget.title, 'taskLabel': _selected.label},
      safeAppContext: {
        ...idFields,
        ..._hydratedContext,
        if (appUser != null)
          'userProfile': {
            'fullName': appUser.fullName,
            'email': appUser.email,
          },
        'manualReviewRequired': true,
        'noDatabaseWrites': true,
        'noPaymentOrSettlementExecution': true,
        'neverAutoPublish': true,
        'neverSetVerifiedBadgeFromAi': true,
        'applyFillsFormsOnly': true,
        'workflow': _selected.workflow,
      },
      languageHint: 'professional English, simple where useful',
      constraints: const [
        'Return draft/recommendation only.',
        'Do not claim that platform actions were performed.',
        'Do not execute payments, settlements, refunds, hiring, or profile changes.',
        'Do not invent portfolio URLs, gallery URLs, or certificate IDs.',
        'Do not set verifiedBadge from AI.',
      ],
      timestamp: DateTime.now(),
    );

    final response = await _gatewayClient.send(request);
    if (!mounted) return;
    final evidence = _evidenceFromHydrated(appUser?.fullName, appUser?.email);
    final draft = MarketplaceAiSanitize.sanitizeResponse(
      MarketplaceAiDraftResponse.fromCopilot(
        response,
        taskType: _selected.taskType,
      ),
      evidence: evidence,
    );
    setState(() {
      _loading = false;
      _response = response;
      _draftResponse = draft;
    });
  }

  MarketplaceAiKnownEvidence _evidenceFromHydrated(
    String? clientName,
    String? clientEmail,
  ) {
    final serviceFromContext = _hydratedContext['service'];
    final packages = <String>[];
    if (serviceFromContext is Map) {
      final rawPackages = serviceFromContext['packages'];
      if (rawPackages is Iterable) {
        for (final item in rawPackages) {
          if (item is Map) {
            final id = (item['packageId'] ?? item['id'] ?? '').toString();
            if (id.trim().isNotEmpty) packages.add(id.trim());
          }
        }
      }
    }
    return MarketplaceAiKnownEvidence(
      knownSkills: [
        ..._stringList(_hydratedContext['knownSkills']),
        if (serviceFromContext is Map)
          ..._stringList(serviceFromContext['linkedSkills']),
      ],
      knownCertificateIds: [
        ..._stringList(_hydratedContext['knownCertificateIds']),
        if (serviceFromContext is Map)
          ..._stringList(serviceFromContext['linkedCertificateIds']),
      ],
      allowedUrls: [
        ..._stringList(_hydratedContext['allowedUrls']),
        if (serviceFromContext is Map) ...[
          ..._stringList(serviceFromContext['portfolioLinks']),
          ..._stringList(serviceFromContext['galleryUrls']),
          if ((serviceFromContext['coverImageUrl']?.toString() ?? '')
              .trim()
              .isNotEmpty)
            serviceFromContext['coverImageUrl'].toString(),
        ],
      ],
      knownPackageIds: packages,
      platformSkillScore:
          _doubleOrNull(_hydratedContext['platformSkillScore']) ??
          (serviceFromContext is Map
              ? _doubleOrNull(serviceFromContext['skillScore'])
              : null),
      clientName: clientName ?? '',
      clientEmail: clientEmail ?? '',
    );
  }

  void _handleApply(MarketplaceAiDraftResponse draft) {
    final task = draft.taskType.isNotEmpty ? draft.taskType : _selected.taskType;
    final params = GoRouterState.of(context).uri.queryParameters;

    if (draft.hasServiceListing) {
      final sanitized = draft.serviceListing!;
      MarketplaceAiPendingApply.serviceListing = sanitized.toApplyMap();
      final serviceId =
          (_hydratedContext['serviceId'] ?? params['serviceId'] ?? '')
              .toString()
              .trim();
      if (serviceId.isNotEmpty) {
        context.goNamed(
          RouteNames.freelancerServiceEdit,
          pathParameters: {'serviceId': serviceId},
          extra: {'aiServiceListing': sanitized.toApplyMap()},
        );
      } else {
        context.goNamed(
          RouteNames.freelancerServiceCreate,
          extra: {'aiServiceListing': sanitized.toApplyMap()},
        );
      }
      _show('Applied to Service Editor. Review, then Save Draft or Publish.');
      return;
    }

    if (draft.hasServiceRequest) {
      MarketplaceAiPendingApply.serviceRequest =
          draft.serviceRequest!.toApplyMap();
      final serviceId = (params['serviceId'] ?? _hydratedContext['serviceId'] ?? '')
          .toString()
          .trim();
      if (serviceId.isNotEmpty) {
        context.pushNamed(
          RouteNames.publicServiceDetail,
          pathParameters: {'serviceId': serviceId},
        );
      }
      _show(
        'Service request draft stored. Open Request form to apply fields. '
        'Submit remains manual.',
      );
      return;
    }

    if (draft.hasProfile) {
      MarketplaceAiPendingApply.profile = draft.profile!.toApplyMap();
      context.pushNamed(RouteNames.freelancerEditProfile);
      _show('Profile draft ready. Review fields, then Save yourself.');
      return;
    }

    if (draft.hasChecklist) {
      MarketplaceAiPendingApply.acceptanceChecklist =
          draft.acceptanceChecklist!.toApplyMap();
      final orderId = (params['orderId'] ?? '').trim();
      if (orderId.isNotEmpty) {
        context.pushNamed(
          RouteNames.serviceOrderDetail,
          pathParameters: {'orderId': orderId},
        );
      }
      _show('Acceptance checklist stored (advisory only — no escrow action).');
      return;
    }

    if (draft.hasTextDraft) {
      final body = draft.textDraft!.composedNoteBody;
      final kind = _noteKindForTask(task);
      MarketplaceAiPendingApply.setNote(kind: kind, body: body);
      if (MarketplaceAiTaskType.isDeliveryNoteTask(task)) {
        final orderId = (params['orderId'] ?? '').trim();
        if (orderId.isNotEmpty) {
          context.pushNamed(
            RouteNames.serviceOrderDetail,
            pathParameters: {'orderId': orderId},
          );
        }
        _show('Delivery note ready. Open Submit Delivery — message prefills.');
        return;
      }
      if (MarketplaceAiTaskType.isProposalTask(task) ||
          task == MarketplaceAiTaskType.freelancerScopeClarifier) {
        final requestId =
            (params['requestId'] ?? params['serviceRequestId'] ?? '').trim();
        if (requestId.isNotEmpty) {
          context.pushNamed(
            RouteNames.serviceRequestDetail,
            pathParameters: {'requestId': requestId},
          );
        }
        _show('Note draft ready. Open Freelancer note — it will prefill.');
        return;
      }
      if (MarketplaceAiTaskType.isResolutionNotesTask(task)) {
        final orderId = (params['orderId'] ?? '').trim();
        if (orderId.isNotEmpty) {
          context.pushNamed(
            RouteNames.serviceOrderDetail,
            pathParameters: {'orderId': orderId},
          );
        } else if (widget.role == 'freelancer') {
          context.pushNamed(RouteNames.freelancerResolutions);
        } else {
          context.pushNamed(RouteNames.customerResolutions);
        }
        _show('Resolution notes ready. Open Notes — draft prefills.');
        return;
      }
      if (MarketplaceAiTaskType.isMessageDraftTask(task)) {
        Clipboard.setData(ClipboardData(text: body));
        _show('Message draft copied. Paste into composer — never auto-sent.');
        return;
      }
      Clipboard.setData(ClipboardData(text: body));
      _show('Draft copied. Paste into the target notes field.');
      return;
    }

    if (draft.hasComparison) {
      _show(
        draft.comparison!.notEnoughEvidence
            ? 'Not enough evidence to compare.'
            : 'Comparison is advisory only — review above.',
      );
    }
  }

  String _noteKindForTask(String task) {
    return switch (task) {
      MarketplaceAiTaskType.freelancerProposalDraft => 'proposal',
      MarketplaceAiTaskType.freelancerDeliveryNoteBuilder => 'delivery',
      MarketplaceAiTaskType.customerRevisionRequestDraft => 'revision',
      MarketplaceAiTaskType.customerRefundRequestDraft => 'refund',
      MarketplaceAiTaskType.customerDisputeExplanationDraft => 'dispute',
      MarketplaceAiTaskType.freelancerRevisionResponseDraft =>
        'revisionResponse',
      MarketplaceAiTaskType.freelancerDisputeEvidenceSummary => 'evidence',
      MarketplaceAiTaskType.freelancerScopeClarifier => 'proposal',
      MarketplaceAiTaskType.freelancerClientUpdateDraft => 'message',
      MarketplaceAiTaskType.customerMessageDraft => 'message',
      _ => 'notes',
    };
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

List<String> _stringList(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

double? _doubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.18),
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: accent,
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskPicker extends StatelessWidget {
  const _TaskPicker({
    required this.tasks,
    required this.selected,
    required this.accent,
    required this.onChanged,
  });

  final List<_AiTaskOption> tasks;
  final _AiTaskOption selected;
  final Color accent;
  final ValueChanged<_AiTaskOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final task in tasks)
          ChoiceChip(
            label: Text(task.label),
            selected: task.taskType == selected.taskType,
            selectedColor: accent.withValues(alpha: 0.22),
            onSelected: (_) => onChanged(task),
          ),
      ],
    );
  }
}

class _GatewayStatusCard extends StatelessWidget {
  const _GatewayStatusCard({
    required this.health,
    required this.loading,
    required this.gatewayUrl,
    required this.onRetry,
  });

  final Map<String, dynamic>? health;
  final bool loading;
  final String gatewayUrl;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ok = health?['ok'] == true;
    final provider = health?['provider']?.toString() ?? 'unknown';
    final hasKey =
        health?['hasOpenAiKey'] == true || health?['hasGeminiKey'] == true;
    final message = ok
        ? 'Connected to $provider. Provider key detected: ${hasKey ? 'yes' : 'no'}.'
        : (health?['message']?.toString() ??
              'Checking AI Gateway connection...');
    final color = ok ? AppColors.success : Theme.of(context).colorScheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ok ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ok ? 'AI Gateway Connected' : 'AI Gateway Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: loading ? null : onRetry,
                  icon: loading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(message),
            const SizedBox(height: 8),
            SelectableText('Gateway URL: $gatewayUrl'),
            const SizedBox(height: 8),
            Text(
              'Local fix: cd skillforge_ai_gateway && npm.cmd run dev',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.selected,
    required this.fields,
    required this.accent,
    this.hydrated = false,
    this.hydrating = false,
  });

  final _AiTaskOption selected;
  final Map<String, String> fields;
  final Color accent;
  final bool hydrated;
  final bool hydrating;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_tree_rounded, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selected.workflow,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (hydrating)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (hydrated)
                  const Chip(
                    avatar: Icon(Icons.cloud_done_rounded, size: 16),
                    label: Text('Docs hydrated'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(selected.contextHelp),
            const SizedBox(height: 10),
            if (fields.isEmpty)
              Text(
                'No specific record selected. Open this assistant from a request, order, service, or resolution case for automatic context.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in fields.entries)
                    Chip(label: Text('${entry.key}: ${entry.value}')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.controller,
    required this.selected,
    required this.accent,
    required this.loading,
    required this.cost,
    required this.onGenerate,
  });

  final TextEditingController controller;
  final _AiTaskOption selected;
  final Color accent;
  final bool loading;
  final int cost;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selected.label,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(selected.description),
            const SizedBox(height: 8),
            Chip(
              avatar: const Icon(Icons.bolt_rounded, size: 16),
              label: Text('$cost AI Credits on successful generation'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              minLines: 6,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: 'Context for AI',
                hintText: selected.hint,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: loading ? null : onGenerate,
                style: FilledButton.styleFrom(backgroundColor: accent),
                icon: loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(loading ? 'Generating...' : 'Generate Draft'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  const _ResponseCard({
    required this.response,
    required this.accent,
    required this.selectedTaskType,
    this.draft,
    this.onApply,
  });

  final CopilotAiResponseModel response;
  final Color accent;
  final String selectedTaskType;
  final MarketplaceAiDraftResponse? draft;
  final ValueChanged<MarketplaceAiDraftResponse>? onApply;

  @override
  Widget build(BuildContext context) {
    final effective = draft ??
        MarketplaceAiDraftResponse.fromCopilot(
          response,
          taskType: selectedTaskType,
        );

    if (effective.hasAnyApplyTarget || effective.isUnavailable) {
      var applyLabel = 'Apply to Form';
      if (effective.hasServiceListing) applyLabel = 'Apply to Service Editor';
      if (effective.hasServiceRequest) applyLabel = 'Apply to Request Form';
      if (effective.hasTextDraft) applyLabel = 'Apply to Notes';
      if (effective.hasProfile) applyLabel = 'Apply to Profile';
      if (effective.hasChecklist) applyLabel = 'Show on Order';

      return MarketplaceAiDraftPanel(
        response: effective,
        accent: accent,
        applyLabel: applyLabel,
        onApplyServiceListing: effective.hasServiceListing && onApply != null
            ? () => onApply!(effective)
            : null,
        onApplyServiceRequest: effective.hasServiceRequest && onApply != null
            ? () => onApply!(effective)
            : null,
        onApplyTextDraft: effective.hasTextDraft && onApply != null
            ? () => onApply!(effective)
            : null,
        onApplyProfile: effective.hasProfile && onApply != null
            ? () => onApply!(effective)
            : null,
        onApplyChecklist: effective.hasChecklist && onApply != null
            ? () => onApply!(effective)
            : null,
      );
    }

    final debugReason = [
      if ((response.safeErrorCode ?? '').isNotEmpty)
        'Code: ${response.safeErrorCode}',
      if ((response.blockedReason ?? '').isNotEmpty)
        'Reason: ${response.blockedReason}',
      if (response.providerAttempts.isNotEmpty)
        'Attempts: ${response.providerAttempts.map((item) => '${item['provider']}:${item['status']}${item['safeErrorCode'] == null ? '' : ' (${item['safeErrorCode']})'}').join(', ')}',
    ].join('\n');
    final text = [
      response.title,
      response.message,
      if (debugReason.isNotEmpty) debugReason,
      if (response.suggestions.isNotEmpty) 'Suggestions:',
      ...response.suggestions.map((item) => '- $item'),
      if (response.safetyNotes.isNotEmpty) 'Safety notes:',
      ...response.safetyNotes.map((item) => '- $item'),
    ].where((item) => item.trim().isNotEmpty).join('\n\n');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  response.isSuccess
                      ? Icons.verified_rounded
                      : Icons.info_outline_rounded,
                  color: response.isSuccess ? accent : AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    response.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(response.provider),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(response.message),
            if (response.structuredData.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Structured data keys: ${response.structuredData.keys.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (debugReason.isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(
                debugReason,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (response.suggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Suggestions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final item in response.suggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $item'),
                ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text('Status: ${response.status}')),
                Chip(
                  label: Text(
                    'Manual review: ${response.requiresManualReview ? 'yes' : 'no'}',
                  ),
                ),
                if ((response.model ?? '').isNotEmpty)
                  Chip(label: Text(response.model!)),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AI draft copied.')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy Draft'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiTaskOption {
  const _AiTaskOption({
    required this.taskType,
    required this.label,
    required this.description,
    required this.hint,
    required this.workflow,
    required this.contextHelp,
    this.aliases = const [],
  });

  final String taskType;
  final String label;
  final String description;
  final String hint;
  final String workflow;
  final String contextHelp;
  final List<String> aliases;

  bool matches(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return taskType.toLowerCase() == normalized ||
        label.toLowerCase() == normalized ||
        aliases.any((item) => item.toLowerCase() == normalized);
  }
}

const _freelancerTasks = [
  _AiTaskOption(
    taskType: 'freelancerProposalDraft',
    label: 'Proposal Draft',
    description: 'Write a client-ready proposal from job or request details.',
    hint: 'Paste client request, budget, timeline, your skills, and questions.',
    workflow: 'Draft Proposal',
    contextHelp: 'Best used from a service request using requestId.',
    aliases: ['proposal', 'draftProposal'],
  ),
  _AiTaskOption(
    taskType: 'freelancerServiceListingBuilder',
    label: 'Service Listing',
    description: 'Build a clear marketplace service listing.',
    hint: 'Describe your service, deliverables, pricing, skills, and timeline.',
    workflow: 'Create Service Listing',
    contextHelp: 'Best used from service studio or create service.',
    aliases: ['service', 'serviceBuilder', 'createService'],
  ),
  _AiTaskOption(
    taskType: 'freelancerServiceListingImprover',
    label: 'Improve Listing',
    description: 'Improve an existing marketplace service listing.',
    hint: 'Paste the current listing and what should be clearer or stronger.',
    workflow: 'Improve Service Listing',
    contextHelp: 'Best used from edit service using serviceId.',
    aliases: ['serviceImprover', 'improveService', 'improveListing'],
  ),
  _AiTaskOption(
    taskType: 'freelancerScopeClarifier',
    label: 'Scope Clarifier',
    description: 'Find missing requirements before accepting work.',
    hint: 'Paste the client brief and what feels unclear.',
    workflow: 'Clarify Project Scope',
    contextHelp: 'Best used before accepting a request or starting an order.',
    aliases: ['scope', 'clarifyScope'],
  ),
  _AiTaskOption(
    taskType: 'freelancerDeliveryNoteBuilder',
    label: 'Delivery Note',
    description: 'Draft a professional delivery handoff note.',
    hint: 'List delivered items, links, known limits, and next steps.',
    workflow: 'Draft Delivery Note',
    contextHelp: 'Best used from an active order using orderId.',
    aliases: ['delivery', 'deliveryNote', 'freelancerDeliveryMessageDraft'],
  ),
  _AiTaskOption(
    taskType: 'freelancerClientUpdateDraft',
    label: 'Client Update',
    description: 'Draft a client progress update. Never auto-sends.',
    hint: 'Describe progress, blockers, and next steps.',
    workflow: 'Draft Client Update',
    contextHelp: 'Best used from an active order using orderId.',
    aliases: ['clientUpdate', 'update'],
  ),
  _AiTaskOption(
    taskType: 'freelancerRevisionResponseDraft',
    label: 'Revision Response',
    description: 'Draft notes for submitting a revision response.',
    hint: 'Describe what you changed and how it meets the revision request.',
    workflow: 'Draft Revision Response',
    contextHelp: 'Best used from resolution center Notes → submitRevision.',
    aliases: ['revisionResponse'],
  ),
  _AiTaskOption(
    taskType: 'freelancerDisputeEvidenceSummary',
    label: 'Evidence Summary',
    description: 'Summarize dispute evidence for manual review.',
    hint: 'Paste timeline, messages, delivery notes, and dispute context.',
    workflow: 'Summarize Dispute Evidence',
    contextHelp: 'Best used from resolution center using caseId or orderId.',
    aliases: ['dispute', 'disputeEvidence', 'evidence'],
  ),
  _AiTaskOption(
    taskType: 'freelancerProfileImprover',
    label: 'Profile Improver',
    description: 'Improve professional title, bio, services, and skills.',
    hint: 'Describe your strengths, niche, and target clients.',
    workflow: 'Improve Freelancer Profile',
    contextHelp: 'Apply fills profile form only — Save remains manual.',
    aliases: ['profile', 'freelancerProfileImprove'],
  ),
  _AiTaskOption(
    taskType: 'freelancerTimelineBuilder',
    label: 'Timeline Builder',
    description: 'Draft a project timeline for client review.',
    hint: 'Paste scope, package delivery days, and milestones.',
    workflow: 'Draft Project Timeline',
    contextHelp: 'Advisory timeline only — never starts work automatically.',
    aliases: ['timeline', 'projectTimeline'],
  ),
];

const _customerTasks = [
  _AiTaskOption(
    taskType: 'customerProjectBriefBuilder',
    label: 'Project Brief',
    description: 'Turn an idea into a freelancer-ready brief.',
    hint:
        'Describe what you need, target users, budget, deadline, and examples.',
    workflow: 'Build Project Brief',
    contextHelp: 'Best used before creating a service request.',
    aliases: ['brief', 'projectBrief'],
  ),
  _AiTaskOption(
    taskType: 'customerServiceRequestDraft',
    label: 'Service Request',
    description: 'Draft a complete service request for a freelancer listing.',
    hint:
        'Describe project title, requirements, deadline, and preferred package.',
    workflow: 'Draft Service Request',
    contextHelp: 'Best used from a service detail before requesting work.',
    aliases: ['serviceRequest', 'requestDraft'],
  ),
  _AiTaskOption(
    taskType: 'customerRequirementClarifier',
    label: 'Requirements',
    description: 'Create questions and requirements before hiring.',
    hint: 'Paste your rough idea or freelancer service listing.',
    workflow: 'Clarify Requirements',
    contextHelp: 'Best used from a service detail or before requesting work.',
    aliases: ['requirements', 'clarify'],
  ),
  _AiTaskOption(
    taskType: 'customerFreelancerComparison',
    label: 'Compare Talent',
    description: 'Compare freelancer options using provided evidence only.',
    hint: 'Paste freelancer summaries, prices, skills, and portfolio notes.',
    workflow: 'Compare Freelancers',
    contextHelp: 'Use provided service/freelancer details only.',
    aliases: ['comparison', 'compare'],
  ),
  _AiTaskOption(
    taskType: 'customerMessageDraft',
    label: 'Message Draft',
    description: 'Draft a message to a freelancer. Never auto-sends.',
    hint: 'Describe what you want to ask or clarify.',
    workflow: 'Draft Message',
    contextHelp: 'Copy into composer only — never sends automatically.',
    aliases: ['message', 'customerSupportMessageDraft'],
  ),
  _AiTaskOption(
    taskType: 'customerRevisionRequestDraft',
    label: 'Revision Request',
    description: 'Draft a polite, specific revision request.',
    hint: 'Describe the delivery, what is missing, and expected changes.',
    workflow: 'Draft Revision Request',
    contextHelp: 'Best used from an order — fills Notes only.',
    aliases: ['revision'],
  ),
  _AiTaskOption(
    taskType: 'customerRefundRequestDraft',
    label: 'Refund Request',
    description: 'Draft refund explanation notes. Never executes refund.',
    hint: 'Explain why you are requesting a sandbox refund.',
    workflow: 'Draft Refund Notes',
    contextHelp: 'Best used from an order — fills Notes only.',
    aliases: ['refund', 'refundDraft', 'customerRefundReasonDraft'],
  ),
  _AiTaskOption(
    taskType: 'customerDisputeExplanationDraft',
    label: 'Dispute Explanation',
    description: 'Draft dispute explanation notes. Never opens dispute alone.',
    hint: 'Describe the issue and expected outcome.',
    workflow: 'Draft Dispute Notes',
    contextHelp: 'Best used from an order — fills Notes only.',
    aliases: ['disputeDraft', 'customerDisputeSummaryDraft'],
  ),
  _AiTaskOption(
    taskType: 'customerDeliveryAcceptanceChecklist',
    label: 'Acceptance Checklist',
    description: 'Build a checklist before approving delivery.',
    hint:
        'Paste order scope, freelancer delivery note, and acceptance criteria.',
    workflow: 'Review Delivery Checklist',
    contextHelp: 'Best used from a delivered order using orderId.',
    aliases: ['deliveryChecklist', 'checklist'],
  ),
  _AiTaskOption(
    taskType: 'customerOrderScopeReview',
    label: 'Order Scope Review',
    description: 'Advisory gaps before accept/pay. Never pays automatically.',
    hint: 'Paste order scope and what feels unclear before paying.',
    workflow: 'Review Order Scope',
    contextHelp: 'Best used before accept/pay on an order.',
    aliases: ['orderScope', 'scopeReview'],
  ),
];

const _adminResolutionTasks = [
  _AiTaskOption(
    taskType: 'adminResolutionCaseSummary',
    label: 'Case Summary',
    description: 'Summarize dispute facts for admin review.',
    hint:
        'Paste order scope, timeline, messages, evidence, and current status.',
    workflow: 'Analyze Resolution Case',
    contextHelp: 'Best used from the Resolution Desk with caseId.',
    aliases: ['case', 'summary', 'analyze'],
  ),
  _AiTaskOption(
    taskType: 'adminResolutionEvidenceAnalysis',
    label: 'Evidence Analysis',
    description: 'Identify evidence strengths, gaps, and contradictions.',
    hint: 'Paste evidence from customer, freelancer, delivery, and revisions.',
    workflow: 'Summarize Evidence',
    contextHelp: 'Use only submitted evidence and case notes.',
    aliases: ['evidence'],
  ),
  _AiTaskOption(
    taskType: 'adminResolutionTimelineBuilder',
    label: 'Timeline',
    description: 'Build a neutral timeline of case events.',
    hint:
        'Paste dated events, messages, payments, delivery, revisions, disputes.',
    workflow: 'Build Case Timeline',
    contextHelp: 'Best used when case events/evidence are visible.',
    aliases: ['timeline'],
  ),
  _AiTaskOption(
    taskType: 'adminResolutionDraftDecision',
    label: 'Draft Decision',
    description: 'Draft a manual-review decision explanation.',
    hint: 'Paste full case context and preferred policy considerations.',
    workflow: 'Draft Admin Decision',
    contextHelp: 'Advisory only. Admin must decide manually.',
    aliases: ['draftDecision', 'decision'],
  ),
  _AiTaskOption(
    taskType: 'adminSettlementRecommendation',
    label: 'Settlement Review',
    description: 'Suggest refund/release/split reasoning without execution.',
    hint: 'Paste escrow amount, delivery status, evidence, and dispute reason.',
    workflow: 'Settlement Risk Review',
    contextHelp: 'Advisory only. Never executes release, split, or refund.',
    aliases: ['settlement', 'risk'],
  ),
];
