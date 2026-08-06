import 'dart:ui';

import 'package:flutter/material.dart';

import 'copilot_chat_panel.dart';

class CopilotFloatingButton extends StatefulWidget {
  const CopilotFloatingButton({super.key});

  @override
  State<CopilotFloatingButton> createState() => _CopilotFloatingButtonState();
}

class _CopilotFloatingButtonState extends State<CopilotFloatingButton> {
  bool _open = false;

  void _toggle() => setState(() => _open = !_open);

  void _close() {
    if (!_open) return;
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 700;
    final colorScheme = Theme.of(context).colorScheme;
    final panelWidth = isMobile ? 280.0 : 360.0;

    return SizedBox.expand(
      child: Stack(
        children: [
          if (_open)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
                child: const SizedBox.expand(),
              ),
            ),
          // Chat Panel
          Positioned(
            right: _open ? 0 : -panelWidth,
            top: 0,
            bottom: 0,
            width: panelWidth,
            child: IgnorePointer(
              ignoring: !_open,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _open ? 1.0 : 0.0,
                child: _open
                    ? CopilotChatPanel(
                        key: const ValueKey('panel'),
                        onClose: _close,
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),
            ),
          ),
          // Toggle Button
          Positioned(
            right: _open ? panelWidth : 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Tooltip(
                message: _open ? 'Close Copilot' : 'Open Copilot',
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      width: 52,
                      height: 120,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.92,
                        ),
                        border: Border(
                          left: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _toggle,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Icon(
                                  _open
                                      ? Icons.chevron_right_rounded
                                      : Icons.auto_awesome_rounded,
                                  color: colorScheme.onPrimaryContainer,
                                  key: ValueKey(_open),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _open ? 'Close' : 'Ask',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
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
  }
}
