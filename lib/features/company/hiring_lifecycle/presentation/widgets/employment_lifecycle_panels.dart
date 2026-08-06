import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/services/cloudinary_delivery_upload_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../models/application_model.dart';
import '../../../../../models/hiring_lifecycle_models.dart';
import '../../../../../providers/auth_provider.dart';
import '../../providers/hiring_lifecycle_providers.dart';

class EmploymentInfoCard extends StatelessWidget {
  const EmploymentInfoCard({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        color: AppColors.primary.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class EmploymentWelcomePackPanel extends ConsumerStatefulWidget {
  const EmploymentWelcomePackPanel({
    super.key,
    required this.app,
    required this.editable,
    this.busy = false,
  });

  final ApplicationModel app;
  final bool editable;
  final bool busy;

  @override
  ConsumerState<EmploymentWelcomePackPanel> createState() =>
      _EmploymentWelcomePackPanelState();
}

class _EmploymentWelcomePackPanelState
    extends ConsumerState<EmploymentWelcomePackPanel> {
  late final TextEditingController _message;
  late final TextEditingController _contacts;
  late final TextEditingController _links;
  late final TextEditingController _policies;

  @override
  void initState() {
    super.initState();
    final pack = widget.app.welcomePack;
    _message = TextEditingController(text: pack.message);
    _contacts = TextEditingController(text: pack.teamContacts.join('\n'));
    _links = TextEditingController(text: pack.links.join('\n'));
    _policies = TextEditingController(text: pack.policiesSummary);
  }

  @override
  void dispose() {
    _message.dispose();
    _contacts.dispose();
    _links.dispose();
    _policies.dispose();
    super.dispose();
  }

  List<String> _splitLines(String raw) => raw
      .split(RegExp(r'[\n,]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final pack = widget.app.welcomePack;
    if (!widget.editable) {
      if (!pack.isPublished) {
        return const EmploymentInfoCard(
          title: 'Welcome pack',
          children: [
            Text('Your company has not published a welcome pack yet.'),
          ],
        );
      }
      return EmploymentInfoCard(
        title: 'Welcome pack',
        children: [
          if (pack.message.isNotEmpty) Text(pack.message),
          if (pack.policiesSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Policies', style: Theme.of(context).textTheme.titleSmall),
            Text(pack.policiesSummary),
          ],
          if (pack.teamContacts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Team contacts',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            ...pack.teamContacts.map((c) => Text('• $c')),
          ],
          if (pack.links.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Links', style: Theme.of(context).textTheme.titleSmall),
            ...pack.links.map((l) => Text('• $l')),
          ],
        ],
      );
    }

    return EmploymentInfoCard(
      title: 'Welcome pack editor',
      children: [
        TextField(
          controller: _message,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Welcome message',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _policies,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Policies summary',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _contacts,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Team contacts (one per line)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _links,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Links (one per line)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: widget.busy
              ? null
              : () async {
                  final ok = await ref
                      .read(hiringLifecycleActionProvider.notifier)
                      .publishWelcomePack(
                        applicationId: widget.app.id,
                        pack: WelcomePack(
                          message: _message.text.trim(),
                          policiesSummary: _policies.text.trim(),
                          teamContacts: _splitLines(_contacts.text),
                          links: _splitLines(_links.text),
                        ),
                      );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Welcome pack published.'
                            : (ref
                                      .read(
                                        hiringLifecycleActionProvider.notifier,
                                      )
                                      .lastErrorMessage ??
                                  'Unable to publish welcome pack.'),
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.publish_rounded),
          label: const Text('Publish welcome pack'),
        ),
      ],
    );
  }
}

class EmploymentDocumentsPanel extends ConsumerWidget {
  const EmploymentDocumentsPanel({
    super.key,
    required this.app,
    required this.asCandidate,
    this.busy = false,
    this.readOnly = false,
  });

  final ApplicationModel app;
  final bool asCandidate;
  final bool busy;
  final bool readOnly;

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    try {
      final upload = CloudinaryDeliveryUploadService();
      final files = await upload.pickDeliveryFiles();
      if (files.isEmpty) return;
      final uploaded = await upload.uploadDeliveryFiles(files.take(3).toList());
      var savedCount = 0;
      for (final file in uploaded) {
        final url = (file['secureUrl'] ?? file['url'] ?? '').toString();
        if (url.isEmpty) continue;
        final title = (file['fileName'] ?? 'Document').toString();
        final ok = await ref
            .read(hiringLifecycleActionProvider.notifier)
            .addEmploymentDocument(
              applicationId: app.id,
              asCandidate: asCandidate,
              document: EmploymentDocument(
                id: '${DateTime.now().millisecondsSinceEpoch}_${title.hashCode}',
                title: title,
                category: 'other',
                url: url,
                uploadedBy: asCandidate ? app.applicantId : app.companyId,
                uploadedAt: DateTime.now(),
                visibleToCandidate: true,
              ),
            );
        if (ok) savedCount++;
      }
      if (!context.mounted) return;
      if (savedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to upload document.')),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          Future<void>.delayed(const Duration(seconds: 1), () {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          });
          return const AlertDialog(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green),
                SizedBox(width: 12),
                Expanded(child: Text('Document uploaded successfully')),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  String _uploaderLabel(EmploymentDocument doc) {
    if (doc.uploadedBy == app.companyId) return 'Uploaded by HR';
    if (doc.uploadedBy == app.applicantId) return 'Uploaded by Candidate';
    return 'Uploaded by unknown';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = asCandidate
        ? app.documents
              .where(
                (d) => d.visibleToCandidate || d.uploadedBy == app.applicantId,
              )
              .toList()
        : app.documents;

    return EmploymentInfoCard(
      title: 'Documents vault',
      children: [
        if (docs.isEmpty)
          const Text('No employment documents yet.')
        else
          ...docs.map((doc) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(doc.title),
              subtitle: Text(
                '${_uploaderLabel(doc)} · ${doc.category} · '
                '${DateFormat.yMMMd().format(doc.uploadedAt)}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: () async {
                  final uri = Uri.tryParse(doc.url);
                  if (uri == null) return;
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
            );
          }),
        if (!readOnly) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : () => _upload(context, ref),
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Upload document'),
          ),
        ],
      ],
    );
  }
}

class EmploymentHrChatPanel extends ConsumerStatefulWidget {
  const EmploymentHrChatPanel({
    super.key,
    required this.app,
    required this.senderRole,
    this.readOnly = false,
  });

  final ApplicationModel app;
  final String senderRole;
  final bool readOnly;

  @override
  ConsumerState<EmploymentHrChatPanel> createState() =>
      _EmploymentHrChatPanelState();
}

class _EmploymentHrChatPanelState extends ConsumerState<EmploymentHrChatPanel> {
  final _controller = TextEditingController();
  late String _threadId;
  bool _threadReady = false;
  bool _ensureFailed = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.app.hrThreadId.trim();
    _threadId = existing.isNotEmpty ? existing : widget.app.id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensure());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ensure() async {
    final id = await ref
        .read(hiringLifecycleActionProvider.notifier)
        .ensureHrThread(widget.app.id);
    if (!mounted) return;
    setState(() {
      if (id != null && id.trim().isNotEmpty) {
        _threadId = id.trim();
        _threadReady = true;
        _ensureFailed = false;
      } else {
        _threadReady = false;
        _ensureFailed = true;
      }
    });
  }

  String _senderLabel(EmploymentHrMessage message, bool mine) {
    if (mine) return 'You';
    switch (message.senderRole.toLowerCase()) {
      case 'candidate':
        return 'Candidate';
      case 'company':
      case 'hr':
        return 'Company / HR';
      default:
        return 'HR';
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = _threadReady
        ? ref.watch(employmentHrMessagesProvider(_threadId))
        : null;
    final currentUserId = ref.watch(authStateProvider).asData?.value?.uid;

    return EmploymentInfoCard(
      title: 'HR messages',
      children: [
        if (_ensureFailed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Could not prepare the HR thread. You can still try sending — '
              'pull to refresh or reopen this screen if messages do not appear.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        if (messagesAsync == null && !_ensureFailed)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (messagesAsync != null)
          messagesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unable to load messages. Check connection / rules, then retry.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    ref.invalidate(employmentHrMessagesProvider(_threadId));
                    _ensure();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
                Text('$e', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return const Text(
                  'No messages yet. Say hello to start the thread.',
                );
              }
              return SizedBox(
                height: 220,
                child: ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final mine =
                        currentUserId != null && msg.senderId == currentUserId;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: mine
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            _senderLabel(msg, mine),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            constraints: const BoxConstraints(maxWidth: 320),
                            decoration: BoxDecoration(
                              color: mine
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.body,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat.MMMd().add_jm().format(
                                    msg.createdAt,
                                  ),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        if (!widget.readOnly) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Write a message…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _send,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (!_threadReady) {
      await _ensure();
      if (!mounted) return;
      if (!_threadReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to prepare the HR thread.')),
        );
        return;
      }
    }
    final ok = await ref
        .read(hiringLifecycleActionProvider.notifier)
        .sendHrMessage(
          applicationId: widget.app.id,
          body: text,
          senderRole: widget.senderRole,
        );
    if (!mounted) return;
    if (ok) {
      _controller.clear();
      setState(() => _ensureFailed = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(hiringLifecycleActionProvider.notifier).lastErrorMessage ??
                'Unable to send message.',
          ),
        ),
      );
    }
  }
}

class EmploymentProbationPanel extends ConsumerWidget {
  const EmploymentProbationPanel({
    super.key,
    required this.app,
    required this.companyActions,
    this.busy = false,
  });

  final ApplicationModel app;
  final bool companyActions;
  final bool busy;

  Future<int?> _showDaysDialog(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    required int initialDays,
    String? description,
  }) async {
    final controller = TextEditingController(text: '$initialDays');
    String? validationMessage;
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description != null) ...[
                Text(description),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Total probation days',
                  hintText: '7–365',
                  border: const OutlineInputBorder(),
                  errorText: validationMessage,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final days = int.tryParse(controller.text.trim());
                if (days == null || days < 7 || days > 365) {
                  setDialogState(
                    () =>
                        validationMessage = 'Enter a value from 7 to 365 days.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, days);
              },
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  void _showActionResult(
    BuildContext context,
    WidgetRef ref, {
    required bool ok,
    required String successMessage,
    required String fallbackError,
  }) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? successMessage
              : (ref
                        .read(hiringLifecycleActionProvider.notifier)
                        .lastErrorMessage ??
                    fallbackError),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final probation = app.probation;
    final status = probation.normalizedStatus;

    // Active employees with no probation: optional start (company) / quiet note (candidate).
    if (status == 'none') {
      if (!app.isActiveEmployee) return const SizedBox.shrink();
      return EmploymentInfoCard(
        title: 'Probation',
        children: [
          const Text(
            'No probation period is set for this role. '
            'Probation is optional and separate from the job posting.',
          ),
          if (companyActions) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: busy
                  ? null
                  : () async {
                      await ref
                          .read(hiringLifecycleActionProvider.notifier)
                          .startProbation(applicationId: app.id, days: 90);
                    },
              child: const Text('Start 90-day probation'),
            ),
          ],
        ],
      );
    }

    final days = probation.daysRemaining;
    return EmploymentInfoCard(
      title: 'Probation',
      children: [
        Text('Status: $status'),
        if (probation.startsAt != null)
          Text('Started: ${DateFormat.yMMMd().format(probation.startsAt!)}'),
        if (probation.endsAt != null)
          Text('Ends: ${DateFormat.yMMMd().format(probation.endsAt!)}'),
        if (days != null)
          Text(
            days >= 0
                ? '$days day${days == 1 ? '' : 's'} remaining'
                : '${-days} day${days == -1 ? '' : 's'} overdue',
          ),
        if (status == 'active' || status == 'extended') ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: probation.progressFraction),
        ],
        if (probation.notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(probation.notes),
        ],
        if (companyActions &&
            app.isActiveEmployee &&
            (status == 'active' || status == 'extended')) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: busy
                    ? null
                    : () async {
                        await ref
                            .read(hiringLifecycleActionProvider.notifier)
                            .completeProbation(app.id);
                      },
                child: const Text('Mark completed'),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        await ref
                            .read(hiringLifecycleActionProvider.notifier)
                            .extendProbation(
                              applicationId: app.id,
                              extraDays: 30,
                            );
                      },
                child: const Text('Extend 30 days'),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final start = probation.startsAt;
                        final end = probation.endsAt;
                        final currentDays = start == null || end == null
                            ? 90
                            : end.difference(start).inDays;
                        final days = await _showDaysDialog(
                          context,
                          title: 'Edit probation days',
                          confirmLabel: 'Save',
                          initialDays: currentDays.clamp(7, 365),
                          description:
                              'The end date will be recalculated from the original start date.',
                        );
                        if (days == null) return;
                        if (!context.mounted) return;
                        final ok = await ref
                            .read(hiringLifecycleActionProvider.notifier)
                            .updateProbationDuration(
                              applicationId: app.id,
                              totalDays: days,
                            );
                        if (!context.mounted) return;
                        _showActionResult(
                          context,
                          ref,
                          ok: ok,
                          successMessage: 'Probation duration updated.',
                          fallbackError: 'Unable to update probation duration.',
                        );
                      },
                icon: const Icon(Icons.edit_calendar_rounded),
                label: const Text('Edit days'),
              ),
            ],
          ),
        ],
        if (companyActions &&
            app.isActiveEmployee &&
            (status == 'active' ||
                status == 'extended' ||
                status == 'completed')) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final start = probation.startsAt;
                    final end = probation.endsAt;
                    final previousDays = start == null || end == null
                        ? 90
                        : end.difference(start).inDays;
                    final days = await _showDaysDialog(
                      context,
                      title: 'Restart probation',
                      confirmLabel: 'Restart',
                      initialDays: previousDays.clamp(7, 365),
                      description:
                          'This starts a new probation period today and replaces the current dates.',
                    );
                    if (days == null) return;
                    if (!context.mounted) return;
                    final ok = await ref
                        .read(hiringLifecycleActionProvider.notifier)
                        .restartProbation(applicationId: app.id, days: days);
                    if (!context.mounted) return;
                    _showActionResult(
                      context,
                      ref,
                      ok: ok,
                      successMessage: 'Probation restarted.',
                      fallbackError: 'Unable to restart probation.',
                    );
                  },
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Restart probation'),
          ),
        ],
      ],
    );
  }
}

class EmploymentOffboardingPanel extends ConsumerWidget {
  const EmploymentOffboardingPanel({
    super.key,
    required this.app,
    required this.companyActions,
    this.busy = false,
  });

  final ApplicationModel app;
  final bool companyActions;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (app.isLeftEmployee && app.offboarding.hasData) {
      final off = app.offboarding;
      return EmploymentInfoCard(
        title: companyActions ? 'Offboarding' : 'Employment ended',
        children: [
          if (off.leftAt != null)
            Text('Left: ${DateFormat.yMMMd().add_jm().format(off.leftAt!)}'),
          if (off.reason.isNotEmpty) Text('Reason: ${off.reason}'),
          if (off.notes.isNotEmpty) Text(off.notes),
          if (off.checklist.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...off.checklist.map((item) {
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: item.completed,
                title: Text(item.title),
                onChanged: !companyActions || busy
                    ? null
                    : (value) async {
                        await ref
                            .read(hiringLifecycleActionProvider.notifier)
                            .toggleOffboardingItem(
                              applicationId: app.id,
                              itemId: item.id,
                              completed: value ?? false,
                            );
                      },
              );
            }),
          ],
        ],
      );
    }

    if (!companyActions || app.isLeftEmployee || !app.isActiveEmployee) {
      return const SizedBox.shrink();
    }

    return EmploymentInfoCard(
      title: 'Offboarding',
      children: [
        const Text('Mark this employee as left when employment ends.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: busy
              ? null
              : () async {
                  final reasonCtrl = TextEditingController();
                  final notesCtrl = TextEditingController();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Mark as Left'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: reasonCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Reason',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: notesCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  final ok = await ref
                      .read(hiringLifecycleActionProvider.notifier)
                      .markLeft(
                        applicationId: app.id,
                        reason: reasonCtrl.text.trim(),
                        notes: notesCtrl.text.trim(),
                      );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Employee marked as left.'
                            : (ref
                                      .read(
                                        hiringLifecycleActionProvider.notifier,
                                      )
                                      .lastErrorMessage ??
                                  'Unable to mark left.'),
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Mark as Left'),
        ),
      ],
    );
  }
}

class EmploymentOnboardingChecklistPanel extends ConsumerWidget {
  const EmploymentOnboardingChecklistPanel({
    super.key,
    required this.app,
    required this.asCandidate,
    this.busy = false,
    this.readOnly = false,
  });

  final ApplicationModel app;
  final bool asCandidate;
  final bool busy;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = app.onboardingChecklist;
    final done = items.where((i) => i.completed).length;
    final pct = items.isEmpty ? 0 : ((done / items.length) * 100).round();

    return EmploymentInfoCard(
      title: 'Onboarding checklist ($pct%)',
      children: [
        if (items.isEmpty)
          const Text('No checklist yet.')
        else
          ...items.map((item) {
            final canToggle =
                !readOnly &&
                !busy &&
                (!asCandidate || item.isCandidateCompletable);
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: item.completed,
              title: Text(item.title),
              subtitle: item.completedAt == null
                  ? (asCandidate && !item.isCandidateCompletable
                        ? const Text('Company completes this item')
                        : null)
                  : Text(DateFormat.yMMMd().add_jm().format(item.completedAt!)),
              onChanged: !canToggle
                  ? null
                  : (value) async {
                      if (asCandidate) {
                        await ref
                            .read(hiringLifecycleActionProvider.notifier)
                            .candidateToggleOnboardingItem(
                              applicationId: app.id,
                              itemId: item.id,
                              completed: value ?? false,
                            );
                      } else {
                        await ref
                            .read(hiringLifecycleActionProvider.notifier)
                            .toggleOnboardingItem(
                              applicationId: app.id,
                              itemId: item.id,
                              completed: value ?? false,
                            );
                      }
                    },
            );
          }),
      ],
    );
  }
}
