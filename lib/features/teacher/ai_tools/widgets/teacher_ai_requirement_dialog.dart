import 'package:flutter/material.dart';

import '../models/teacher_ai_generation_request_model.dart';

class TeacherAiRequirementConfig {
  const TeacherAiRequirementConfig({
    required this.prompt,
    required this.questionCount,
    required this.durationMinutes,
    required this.difficulty,
    required this.totalPoints,
    required this.extraContext,
  });

  final String prompt;
  final int questionCount;
  final int? durationMinutes;
  final String difficulty;
  final int totalPoints;
  final Map<String, dynamic> extraContext;
}

class TeacherAiRequirementDialog extends StatefulWidget {
  const TeacherAiRequirementDialog({
    super.key,
    required this.taskType,
    required this.title,
    required this.initialTopic,
    this.initialQuestionCount = 5,
    this.initialDurationMinutes,
    this.initialTotalPoints = 100,
  });

  final String taskType;
  final String title;
  final String initialTopic;
  final int initialQuestionCount;
  final int? initialDurationMinutes;
  final int initialTotalPoints;

  static Future<TeacherAiRequirementConfig?> show({
    required BuildContext context,
    required String taskType,
    required String title,
    required String initialTopic,
    int initialQuestionCount = 5,
    int? initialDurationMinutes,
    int initialTotalPoints = 100,
  }) {
    return showDialog<TeacherAiRequirementConfig>(
      context: context,
      builder: (context) => TeacherAiRequirementDialog(
        taskType: taskType,
        title: title,
        initialTopic: initialTopic,
        initialQuestionCount: initialQuestionCount,
        initialDurationMinutes: initialDurationMinutes,
        initialTotalPoints: initialTotalPoints,
      ),
    );
  }

  @override
  State<TeacherAiRequirementDialog> createState() =>
      _TeacherAiRequirementDialogState();
}

class _TeacherAiRequirementDialogState
    extends State<TeacherAiRequirementDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _topic;
  late final TextEditingController _questions;
  late final TextEditingController _duration;
  late final TextEditingController _points;
  late final TextEditingController _extra;
  late final TextEditingController _deliverables;
  late final TextEditingController _milestones;
  late final TextEditingController _rubric;
  late final TextEditingController _passingScore;
  String _difficulty = 'beginner';
  String _assignmentType = 'mcq';
  String _languageStyle = 'english';
  bool _includeRubric = true;
  bool _includeAnswerKey = true;
  bool _includeExplanations = true;

  @override
  void initState() {
    super.initState();
    _topic = TextEditingController(text: widget.initialTopic);
    _questions = TextEditingController(
      text: widget.initialQuestionCount.clamp(1, 80).toString(),
    );
    _duration = TextEditingController(
      text: (widget.initialDurationMinutes ?? _defaultDuration()).toString(),
    );
    _points = TextEditingController(text: widget.initialTotalPoints.toString());
    _extra = TextEditingController();
    _deliverables = TextEditingController(text: '4');
    _milestones = TextEditingController(text: '3');
    _rubric = TextEditingController(text: '5');
    _passingScore = TextEditingController(text: '70');
  }

  @override
  void dispose() {
    _topic.dispose();
    _questions.dispose();
    _duration.dispose();
    _points.dispose();
    _extra.dispose();
    _deliverables.dispose();
    _milestones.dispose();
    _rubric.dispose();
    _passingScore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Define exact requirements before OpenAI is called. Nothing is saved automatically.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _topic,
                  decoration: const InputDecoration(
                    labelText: 'Topic / learning objective',
                    hintText: 'e.g. C# OOP basics, HTML forms, Firebase auth',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 180,
                      child: TextFormField(
                        controller: _questions,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: _questionLabel(),
                        ),
                        validator: _positive,
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextFormField(
                        controller: _duration,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration minutes',
                        ),
                        validator: _positive,
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextFormField(
                        controller: _points,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total points',
                        ),
                        validator: _positive,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Dropdown(
                      label: 'Difficulty',
                      value: _difficulty,
                      items: const ['beginner', 'intermediate', 'advanced'],
                      onChanged: (value) => setState(() => _difficulty = value),
                    ),
                    _Dropdown(
                      label: 'Language',
                      value: _languageStyle,
                      items: const ['english', 'romanUrdu', 'mixed'],
                      onChanged: (value) =>
                          setState(() => _languageStyle = value),
                    ),
                    if (_isAssignment)
                      _Dropdown(
                        label: 'Assignment type',
                        value: _assignmentType,
                        items: const ['mcq', 'written', 'practical', 'mixed'],
                        onChanged: (value) =>
                            setState(() => _assignmentType = value),
                      ),
                  ],
                ),
                if (_isProject) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _SmallNumberField(
                        controller: _deliverables,
                        label: 'Deliverables',
                      ),
                      _SmallNumberField(
                        controller: _milestones,
                        label: 'Milestones',
                      ),
                      _SmallNumberField(
                        controller: _rubric,
                        label: 'Rubric criteria',
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Include rubric'),
                      selected: _includeRubric,
                      onSelected: (value) =>
                          setState(() => _includeRubric = value),
                    ),
                    FilterChip(
                      label: const Text('Include answer key'),
                      selected: _includeAnswerKey,
                      onSelected: (value) =>
                          setState(() => _includeAnswerKey = value),
                    ),
                    FilterChip(
                      label: const Text('Include explanations'),
                      selected: _includeExplanations,
                      onSelected: (value) =>
                          setState(() => _includeExplanations = value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passingScore,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Passing score'),
                  validator: _positive,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _extra,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Extra instructions',
                    hintText: 'Any style, coverage, scenario, or constraint',
                  ),
                ),
                const SizedBox(height: 14),
                _Summary(config: _previewConfig()),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Generate with OpenAI'),
        ),
      ],
    );
  }

  bool get _isProject =>
      widget.taskType == TeacherAiTaskType.projectAssignmentBuilder;

  bool get _isAssignment =>
      widget.taskType == TeacherAiTaskType.assignmentBuilder;

  String _questionLabel() {
    if (_isProject) return 'Checklist items';
    if (widget.taskType == TeacherAiTaskType.grandTestBuilder) {
      return 'Total questions';
    }
    return 'Question count';
  }

  int _defaultDuration() {
    return switch (widget.taskType) {
      TeacherAiTaskType.grandTestBuilder => 90,
      TeacherAiTaskType.projectAssignmentBuilder => 7,
      TeacherAiTaskType.quizBuilder => 30,
      _ => 45,
    };
  }

  TeacherAiRequirementConfig _previewConfig() {
    final topic = _topic.text.trim();
    final questionCount = int.tryParse(_questions.text.trim()) ?? 5;
    final duration = int.tryParse(_duration.text.trim());
    final points = int.tryParse(_points.text.trim()) ?? 100;
    return TeacherAiRequirementConfig(
      prompt: _prompt(topic, questionCount, points),
      questionCount: questionCount,
      durationMinutes: duration,
      difficulty: _difficulty,
      totalPoints: points,
      extraContext: _context(topic, questionCount, points),
    );
  }

  Map<String, dynamic> _context(String topic, int questionCount, int points) {
    return {
      'topic': topic,
      'targetAudience': 'SkillForge enrolled students',
      'difficultyLevel': _difficulty,
      'languageStyle': _languageStyle,
      'contentDepth': 'detailed',
      'questionCount': questionCount,
      'totalPoints': points,
      'passingScore': int.tryParse(_passingScore.text.trim()) ?? 70,
      'includeRubric': _includeRubric,
      'includeAnswerKey': _includeAnswerKey,
      'includeExplanations': _includeExplanations,
      'extraInstructions': _extra.text.trim(),
      if (_isAssignment) 'assignmentType': _assignmentType,
      if (_isProject) ...{
        'deliverableCount': int.tryParse(_deliverables.text.trim()) ?? 4,
        'milestoneCount': int.tryParse(_milestones.text.trim()) ?? 3,
        'rubricCriteriaCount': int.tryParse(_rubric.text.trim()) ?? 5,
        'includeStarterGuidance': true,
        'includeSubmissionChecklist': true,
        'expectedDurationDays': int.tryParse(_duration.text.trim()) ?? 7,
      },
    };
  }

  String _prompt(String topic, int count, int points) {
    final base =
        'Topic: $topic. Difficulty: $_difficulty. Language: $_languageStyle. '
        'Total points: $points. Passing score: ${_passingScore.text.trim()}. '
        'Extra instructions: ${_extra.text.trim()}';
    return switch (widget.taskType) {
      TeacherAiTaskType.projectAssignmentBuilder =>
        'Create a project assignment. $base Deliverables: ${_deliverables.text.trim()}, milestones: ${_milestones.text.trim()}, rubric criteria: ${_rubric.text.trim()}.',
      TeacherAiTaskType.grandTestBuilder =>
        'Create a grand test with exactly $count questions. $base Include rubric: $_includeRubric.',
      TeacherAiTaskType.quizBuilder =>
        'Create exactly $count MCQs. $base Include explanations: $_includeExplanations.',
      TeacherAiTaskType.assignmentBuilder =>
        'Create a $_assignmentType assignment with exactly $count questions/tasks. $base Include rubric: $_includeRubric.',
      _ => 'Create teacher LMS content. $base',
    };
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(_previewConfig());
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? _positive(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    return parsed == null || parsed <= 0 ? 'Enter a positive number' : null;
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _SmallNumberField extends StatelessWidget {
  const _SmallNumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final parsed = int.tryParse(value?.trim() ?? '');
          return parsed == null || parsed <= 0 ? 'Required' : null;
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.config});

  final TeacherAiRequirementConfig config;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        'Output summary: ${config.questionCount} items, '
        '${config.totalPoints} points, ${config.difficulty} difficulty. '
        'Preview appears before applying. Manual save is still required.',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}
