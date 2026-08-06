import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../interview_lab/models/interview_lab_models.dart';
import '../../interview_lab/providers/interview_lab_providers.dart';
import 'widgets/admin_control_scaffold.dart';

/// Full admin control for AI Interview Lab: enable/disable, limits, scoring,
/// and practice tracks/templates (including custom stacks like MERN).
class AdminInterviewLabScreen extends ConsumerStatefulWidget {
  const AdminInterviewLabScreen({super.key});

  @override
  ConsumerState<AdminInterviewLabScreen> createState() =>
      _AdminInterviewLabScreenState();
}

class _AdminInterviewLabScreenState
    extends ConsumerState<AdminInterviewLabScreen> {
  InterviewLabConfigModel? _draft;
  bool _configReady = false;
  bool _savingConfig = false;
  bool _seeding = false;

  void _ensureDraft(InterviewLabConfigModel config) {
    if (_configReady && _draft != null) return;
    _draft = config;
    _configReady = true;
  }

  Future<void> _saveConfig() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _savingConfig = true);
    final ok =
        await ref.read(interviewLabActionProvider.notifier).saveConfig(draft);
    if (!mounted) return;
    setState(() => _savingConfig = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Interview Lab settings saved.'
              : (ref.read(interviewLabActionProvider.notifier).lastErrorMessage ??
                  'Failed to save settings.'),
        ),
      ),
    );
  }

  Future<void> _seedDefaults() async {
    setState(() => _seeding = true);
    final ok = await ref
        .read(interviewLabActionProvider.notifier)
        .seedTemplates(force: true);
    if (!mounted) return;
    setState(() => _seeding = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Default practice tracks seeded / updated.'
              : (ref.read(interviewLabActionProvider.notifier).lastErrorMessage ??
                  'Seed failed.'),
        ),
      ),
    );
  }

  Future<void> _openTemplateEditor({InterviewLabTemplateModel? existing}) async {
    final saved = await showDialog<InterviewLabTemplateModel>(
      context: context,
      builder: (ctx) => _TemplateEditorDialog(initial: existing),
    );
    if (saved == null || !mounted) return;
    final ok = await ref
        .read(interviewLabActionProvider.notifier)
        .saveTemplate(saved);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Track "${saved.displayTitle}" saved.'
              : (ref.read(interviewLabActionProvider.notifier).lastErrorMessage ??
                  'Failed to save track.'),
        ),
      ),
    );
  }

  Future<void> _toggleTemplate(InterviewLabTemplateModel template) async {
    final ok = await ref.read(interviewLabActionProvider.notifier).saveTemplate(
          template.copyWith(
            isActive: !template.isActive,
            updatedAt: DateTime.now(),
          ),
        );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(interviewLabActionProvider.notifier).lastErrorMessage ??
                'Could not update track.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(interviewLabConfigProvider);
    final templatesAsync = ref.watch(interviewLabAllTemplatesProvider);

    return AdminControlScaffold(
      title: 'AI Interview Lab',
      subtitle:
          'Control practice tracks, session limits, scoring, and lab availability.',
      currentPath: RoutePaths.adminInterviewLab,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () {
            _configReady = false;
            ref.invalidate(interviewLabConfigProvider);
            ref.invalidate(interviewLabAllTemplatesProvider);
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
        FilledButton.tonalIcon(
          onPressed: _seeding ? null : _seedDefaults,
          icon: _seeding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_outlined),
          label: const Text('Seed defaults'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _savingConfig || _draft == null ? null : _saveConfig,
          icon: _savingConfig
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded),
          label: const Text('Save settings'),
        ),
      ],
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Config error: $e')),
        data: (config) {
          _ensureDraft(config);
          final draft = _draft!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            children: [
              AdminPanelCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology_alt_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Lab availability',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Switch.adaptive(
                          value: draft.enabled,
                          onChanged: (v) =>
                              setState(() => _draft = draft.copyWith(enabled: v)),
                        ),
                      ],
                    ),
                    Text(
                      draft.enabled
                          ? 'Students and freelancers can start practice interviews.'
                          : 'Lab is disabled. New practice sessions are blocked.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AdminPanelCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session defaults',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    _SliderRow(
                      label: 'Max questions per session',
                      value: draft.maxQuestions.toDouble(),
                      min: 3,
                      max: 20,
                      divisions: 17,
                      display: '${draft.maxQuestions}',
                      onChanged: (v) => setState(
                        () => _draft =
                            draft.copyWith(maxQuestions: v.round()),
                      ),
                    ),
                    _SliderRow(
                      label: 'Interview timer (minutes)',
                      value: draft.interviewTimeMinutes.toDouble(),
                      min: 10,
                      max: 90,
                      divisions: 16,
                      display: '${draft.interviewTimeMinutes} min',
                      onChanged: (v) => setState(
                        () => _draft = draft.copyWith(
                          interviewTimeMinutes: v.round(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Default difficulty',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: InterviewLabDifficulty.easy,
                          label: Text('Easy'),
                        ),
                        ButtonSegment(
                          value: InterviewLabDifficulty.medium,
                          label: Text('Medium'),
                        ),
                        ButtonSegment(
                          value: InterviewLabDifficulty.hard,
                          label: Text('Hard'),
                        ),
                      ],
                      selected: {draft.defaultDifficulty},
                      onSelectionChanged: (v) => setState(
                        () => _draft =
                            draft.copyWith(defaultDifficulty: v.first),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Evaluation strictness',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: InterviewLabEvaluationStrictness.lenient,
                          label: Text('Lenient'),
                        ),
                        ButtonSegment(
                          value: InterviewLabEvaluationStrictness.balanced,
                          label: Text('Balanced'),
                        ),
                        ButtonSegment(
                          value: InterviewLabEvaluationStrictness.strict,
                          label: Text('Strict'),
                        ),
                      ],
                      selected: {draft.evaluationStrictness},
                      onSelectionChanged: (v) => setState(
                        () => _draft = draft.copyWith(
                          evaluationStrictness: v.first,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enforce session timer'),
                      value: draft.timerEnforced,
                      onChanged: (v) => setState(
                        () => _draft = draft.copyWith(timerEnforced: v),
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Adaptive follow-up questions'),
                      value: draft.adaptiveQuestioning,
                      onChanged: (v) => setState(
                        () =>
                            _draft = draft.copyWith(adaptiveQuestioning: v),
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Difficulty scaling mid-session'),
                      value: draft.difficultyScaling,
                      onChanged: (v) => setState(
                        () =>
                            _draft = draft.copyWith(difficultyScaling: v),
                      ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('One active session lock'),
                      value: draft.sessionLockEnabled,
                      onChanged: (v) => setState(
                        () =>
                            _draft = draft.copyWith(sessionLockEnabled: v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AdminPanelCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scoring thresholds',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _SliderRow(
                      label: 'Pass threshold',
                      value: draft.scoringRules.passThreshold,
                      min: 40,
                      max: 95,
                      divisions: 11,
                      display:
                          '${draft.scoringRules.passThreshold.round()}',
                      onChanged: (v) => setState(
                        () => _draft = draft.copyWith(
                          scoringRules: draft.scoringRules
                              .copyWith(passThreshold: v),
                        ),
                      ),
                    ),
                    _SliderRow(
                      label: 'Hold / needs work threshold',
                      value: draft.scoringRules.holdThreshold,
                      min: 20,
                      max: 70,
                      divisions: 10,
                      display:
                          '${draft.scoringRules.holdThreshold.round()}',
                      onChanged: (v) => setState(
                        () => _draft = draft.copyWith(
                          scoringRules: draft.scoringRules
                              .copyWith(holdThreshold: v),
                        ),
                      ),
                    ),
                    _SliderRow(
                      label: 'Skip confidence penalty',
                      value: draft.skipConfidencePenalty,
                      min: 0,
                      max: 30,
                      divisions: 15,
                      display: '-${draft.skipConfidencePenalty.round()}',
                      onChanged: (v) => setState(
                        () => _draft =
                            draft.copyWith(skipConfidencePenalty: v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Practice tracks',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openTemplateEditor(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add track'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Active tracks appear on the student/freelancer Start Practice screen. '
                'Add custom stacks (e.g. MERN) with focus topics so AI generates matching questions.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              templatesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Templates error: $e'),
                data: (templates) {
                  if (templates.isEmpty) {
                    return AdminPanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'No practice tracks yet. Seed defaults or add a custom track.',
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _seeding ? null : _seedDefaults,
                            icon: const Icon(Icons.auto_awesome_outlined),
                            label: const Text('Seed default tracks'),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final t in templates) ...[
                        AdminPanelCard(
                          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: t.isActive
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              child: Icon(
                                t.isActive
                                    ? Icons.work_outline_rounded
                                    : Icons.pause_circle_outline,
                              ),
                            ),
                            title: Text(
                              t.displayTitle,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              [
                                'slug: ${t.roleTrack}',
                                if (t.focusTopics.isNotEmpty)
                                  'focus: ${t.focusTopics.take(4).join(', ')}',
                                if (!t.isActive) 'inactive',
                              ].join(' · '),
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: t.isActive ? 'Deactivate' : 'Activate',
                                  onPressed: () => _toggleTemplate(t),
                                  icon: Icon(
                                    t.isActive
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () =>
                                      _openTemplateEditor(existing: t),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              display,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TemplateEditorDialog extends StatefulWidget {
  const _TemplateEditorDialog({this.initial});

  final InterviewLabTemplateModel? initial;

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _slug;
  late final TextEditingController _description;
  late final TextEditingController _focus;
  late final TextEditingController _hint;
  late final TextEditingController _sort;
  late String _difficulty;
  late bool _active;
  late bool _slugTouched;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _title = TextEditingController(text: i?.title ?? '');
    _slug = TextEditingController(text: i?.roleTrack ?? '');
    _description = TextEditingController(text: i?.description ?? '');
    _focus = TextEditingController(text: i?.focusTopics.join(', ') ?? '');
    _hint = TextEditingController(text: i?.promptHint ?? '');
    _sort = TextEditingController(text: '${i?.sortOrder ?? 100}');
    _difficulty = i?.defaultDifficulty ?? InterviewLabDifficulty.medium;
    _active = i?.isActive ?? true;
    _slugTouched = i != null;
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _description.dispose();
    _focus.dispose();
    _hint.dispose();
    _sort.dispose();
    super.dispose();
  }

  List<String> _parseCsv(String raw) {
    return raw
        .split(RegExp(r'[,;\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _submit() {
    final title = _title.text.trim();
    var slug = InterviewLabRoleTrack.slugify(_slug.text);
    if (slug.isEmpty) slug = InterviewLabRoleTrack.slugify(title);
    if (title.isEmpty || slug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and track slug are required.')),
      );
      return;
    }
    final now = DateTime.now();
    final initial = widget.initial;
    final model = InterviewLabTemplateModel(
      templateId: initial?.templateId.isNotEmpty == true
          ? initial!.templateId
          : 'tpl_$slug',
      roleTrack: slug,
      title: title,
      description: _description.text.trim(),
      defaultDifficulty: _difficulty,
      defaultQuestionCount: initial?.defaultQuestionCount ?? 8,
      suggestedCategories:
          initial?.suggestedCategories ?? const ['technical', 'behavioral'],
      focusTopics: _parseCsv(_focus.text),
      promptHint: _hint.text.trim(),
      sortOrder: int.tryParse(_sort.text.trim()) ?? 100,
      isActive: _active,
      createdAt: initial?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.pop(context, model);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add practice track' : 'Edit track'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Display title',
                  hintText: 'e.g. MERN Stack Developer',
                ),
                onChanged: (v) {
                  if (_slugTouched) return;
                  _slug.text = InterviewLabRoleTrack.slugify(v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _slug,
                decoration: const InputDecoration(
                  labelText: 'Track slug',
                  hintText: 'e.g. mern',
                  helperText: 'Stored on sessions; used by AI as roleTrack.',
                ),
                onChanged: (_) => _slugTouched = true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Short description',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _focus,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Focus topics (comma-separated)',
                  hintText: 'MongoDB, Express, React, Node.js',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _hint,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'AI prompt hint (optional)',
                  hintText:
                      'Ask about full-stack MERN flows, JWT auth, and React state.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sort,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sort order',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Default difficulty',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: InterviewLabDifficulty.easy,
                    label: Text('Easy'),
                  ),
                  ButtonSegment(
                    value: InterviewLabDifficulty.medium,
                    label: Text('Medium'),
                  ),
                  ButtonSegment(
                    value: InterviewLabDifficulty.hard,
                    label: Text('Hard'),
                  ),
                ],
                selected: {_difficulty},
                onSelectionChanged: (v) =>
                    setState(() => _difficulty = v.first),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active (visible to students)'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save track'),
        ),
      ],
    );
  }
}
