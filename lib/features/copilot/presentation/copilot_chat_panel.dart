import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/copilot_message_model.dart';
import '../providers/copilot_provider.dart';
import 'copilot_quick_actions.dart';

class CopilotChatPanel extends ConsumerStatefulWidget {
  const CopilotChatPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<CopilotChatPanel> createState() => _CopilotChatPanelState();
}

class _CopilotChatPanelState extends ConsumerState<CopilotChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref
        .read(copilotProvider.notifier)
        .sendMessageAndMaybeNavigate(context, text);
    _scrollToLatest();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(copilotProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;

    ref.listen<List<CopilotMessageModel>>(copilotProvider, (previous, next) {
      _scrollToLatest();
    });

    return Material(
      color: Colors.transparent,
      child: Container(
        width: isMobile ? double.infinity : 420,
        height: isMobile
            ? (MediaQuery.sizeOf(context).height * 0.82).clamp(420.0, 720.0)
            : 620,
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(isMobile ? 26 : 28),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.36
                    : 0.16,
              ),
              blurRadius: 34,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isMobile ? 26 : 28),
          child: Column(
            children: [
              _CopilotPanelHeader(onClose: widget.onClose),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: messages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: CopilotQuickActions(),
                      );
                    }
                    return _CopilotMessageBubble(message: messages[index - 1]);
                  },
                ),
              ),
              _CopilotInputBar(controller: _controller, onSend: _send),
            ],
          ),
        ),
      ),
    );
  }
}

class _CopilotPanelHeader extends StatelessWidget {
  const _CopilotPanelHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.12),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SkillForge Copilot',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Zero-cost assistant - navigation, guidance, safe summaries',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close Copilot',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _CopilotMessageBubble extends StatelessWidget {
  const _CopilotMessageBubble({required this.message});

  final CopilotMessageModel message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isUser = message.sender == CopilotMessageSender.user;
    final isLoading = message.metadata['loading'] == true;
    final isGuided = message.metadata['guidedAction'] == true;
    final isAi = message.metadata['aiResponse'] == true;
    final isBlocked =
        message.actionStatus == CopilotActionStatus.blocked ||
        message.actionStatus == CopilotActionStatus.unsupported ||
        message.actionStatus == CopilotActionStatus.needsConfirmation;
    final bubbleColor = isUser
        ? colorScheme.primary
        : isBlocked
        ? colorScheme.errorContainer.withValues(alpha: 0.72)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.78);
    final textColor = isUser
        ? colorScheme.onPrimary
        : isBlocked
        ? colorScheme.onErrorContainer
        : colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 330),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 18),
          ),
          border: Border.all(
            color: isUser
                ? Colors.transparent
                : colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      message.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            : isGuided
            ? _GuidedActionCard(message: message, textColor: textColor)
            : isAi
            ? _AiResponseCard(message: message, textColor: textColor)
            : Text(
                message.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _AiResponseCard extends StatelessWidget {
  const _AiResponseCard({required this.message, required this.textColor});

  final CopilotMessageModel message;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = _stringMeta(message.metadata['title'], 'AI Draft');
    final provider = _stringMeta(message.metadata['provider'], 'mock');
    final actionLevel = _stringMeta(message.metadata['actionLevel'], 'aiDraft');
    final structuredData = _mapMeta(message.metadata['structuredData']);
    final safetyNotes = _stringListMeta(message.metadata['safetyNotes']);
    final suggestions = _stringListMeta(message.metadata['suggestions']);
    final proposedAction = _stringMeta(message.metadata['proposedAction'], '');
    final blockedReason = _stringMeta(message.metadata['blockedReason'], '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 18, color: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _MiniBadge(
              label: _badgeFor(actionLevel),
              color: colorScheme.primary,
            ),
            _MiniBadge(
              label: 'Provider: $provider',
              color: colorScheme.secondary,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          message.text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: textColor,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (structuredData.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._structuredWidgets(context, structuredData, textColor),
        ],
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Suggested structure: ${suggestions.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (proposedAction.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Proposed next step: $proposedAction',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Text(
            [
              'Review before applying. AI can make mistakes.',
              ...safetyNotes,
              if (blockedReason.isNotEmpty) blockedReason,
            ].join('\n'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _GuidedActionCard extends StatelessWidget {
  const _GuidedActionCard({required this.message, required this.textColor});

  final CopilotMessageModel message;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = _stringMeta(message.metadata['title'], 'Guided workflow');
    final description = _stringMeta(
      message.metadata['description'],
      message.text,
    );
    final safety = _stringMeta(
      message.metadata['safetyMessage'],
      'You must review and submit manually.',
    );
    final blockedReason = _stringMeta(message.metadata['blockedReason'], '');
    final nextSteps = _stringListMeta(message.metadata['nextSteps']);
    final prefill = _prefillText(message.metadata['prefillData']);
    final navigated = message.metadata['navigated'] == true;
    final routePath = _stringMeta(message.metadata['targetRoutePath'], '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.assistant_direction_rounded, size: 18, color: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: textColor,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Text(
            blockedReason.isEmpty ? safety : '$safety\n$blockedReason',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (prefill.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Copyable note: $prefill',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (nextSteps.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Next steps',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          for (var index = 0; index < nextSteps.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${index + 1}. ${nextSteps[index]}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
        if (routePath.isNotEmpty) ...[
          const SizedBox(height: 8),
          Chip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(
              navigated
                  ? Icons.check_circle_rounded
                  : Icons.open_in_new_rounded,
              size: 16,
            ),
            label: Text(navigated ? 'Page opened' : 'Open related page'),
          ),
        ],
      ],
    );
  }
}

class _CopilotInputBar extends StatelessWidget {
  const _CopilotInputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        14 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): _SendIntent(),
        },
        child: Actions(
          actions: {
            _SendIntent: CallbackAction<_SendIntent>(
              onInvoke: (_) {
                onSend();
                return null;
              },
            ),
          },
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Ask Copilot... e.g. wallet balance kitna hai',
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.62,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: 'Send',
                onPressed: onSend,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendIntent extends Intent {
  const _SendIntent();
}

String _stringMeta(Object? value, String fallback) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}

List<String> _stringListMeta(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString() ?? '')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

String _prefillText(Object? value) {
  if (value is Map && value.isNotEmpty) {
    final first = value.values.first;
    if (first is String) return first.trim();
    return first?.toString().trim() ?? '';
  }
  return '';
}

Map<String, dynamic> _mapMeta(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<Widget> _structuredWidgets(
  BuildContext context,
  Map<String, dynamic> data,
  Color textColor,
) {
  final widgets = <Widget>[];
  final sections = data['sections'];
  if (sections is Iterable) {
    for (final section in sections) {
      if (section is! Map) continue;
      final title = _stringMeta(section['title'], 'Section');
      final items = _stringListMeta(section['items']);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Text(
            '$title: ${items.isEmpty ? '' : items.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
  }
  if (widgets.isEmpty) {
    widgets.add(
      Text(
        data.entries.map((entry) => '${entry.key}: ${entry.value}').join('\n'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: textColor,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
  return widgets;
}

String _badgeFor(String actionLevel) {
  return switch (actionLevel) {
    'aiExplain' => 'AI Explanation',
    'aiSummarize' => 'AI Summary',
    'aiRecommend' => 'AI Recommendation',
    _ => 'AI Draft',
  };
}
