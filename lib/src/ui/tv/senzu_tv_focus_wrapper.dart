import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TV D-pad navigation-д зориулсан Focus wrapper.
class SenzuTvFocusWrapper extends StatefulWidget {
  const SenzuTvFocusWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
    this.focusedDecoration,
    this.unfocusedDecoration,
    this.focusedScale = 1.08,
    this.onFocusChange,
    this.enabled = true,
    this.onKeyEvent,
  });

  final Widget child;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final BoxDecoration? focusedDecoration;
  final BoxDecoration? unfocusedDecoration;
  final double focusedScale;
  final ValueChanged<bool>? onFocusChange;
  final bool enabled;
  final FocusOnKeyEventCallback? onKeyEvent;

  @override
  State<SenzuTvFocusWrapper> createState() => _SenzuTvFocusWrapperState();
}

class _SenzuTvFocusWrapperState extends State<SenzuTvFocusWrapper>
    with SingleTickerProviderStateMixin {
  late final FocusNode _node;
  bool _focused = false;

  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _node = widget.focusNode ?? FocusNode(debugLabel: 'SenzuTvFocus');
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween(begin: 1.0, end: widget.focusedScale)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _node.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onFocus(bool v) {
    if (!mounted) return;
    setState(() => _focused = v);
    widget.onFocusChange?.call(v);
    v ? _ctrl.forward() : _ctrl.reverse();
  }

  void _activate() {
    if (!widget.enabled) return;
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onFocusChange: _onFocus,
      // enter / select → activate
      onKeyEvent: (_, e) {
  final custom = widget.onKeyEvent?.call(_, e);
  if (custom == KeyEventResult.handled) {
    return KeyEventResult.handled;
  }

  if (e is KeyDownEvent &&
      (e.logicalKey == LogicalKeyboardKey.select ||
          e.logicalKey == LogicalKeyboardKey.enter ||
          e.logicalKey == LogicalKeyboardKey.numpadEnter)) {
    _activate();
    return KeyEventResult.handled;
  }

  return KeyEventResult.ignored;
},
      child: GestureDetector(
        onTap: _activate,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, child) =>
              Transform.scale(scale: _scale.value, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: _focused
                ? (widget.focusedDecoration ??
                    BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2.5),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withOpacity(0.12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ))
                : (widget.unfocusedDecoration ?? const BoxDecoration()),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}