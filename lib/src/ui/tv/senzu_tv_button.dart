import 'package:flutter/material.dart';
import 'senzu_tv_focus_wrapper.dart';

class SenzuTvButton extends StatelessWidget {
  const SenzuTvButton({
    super.key,
    required this.icon,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
    this.iconColor = Colors.white,
    this.iconSize = 22.0,
    this.padding = const EdgeInsets.all(10),
    this.tooltip,
    this.enabled = true,
    this.focusColor,
    this.onKeyEvent,
  });

  final Icon icon;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color iconColor;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final String? tooltip;
  final bool enabled;
  final Color? focusColor;
  final FocusOnKeyEventCallback? onKeyEvent;

  @override
  Widget build(BuildContext context) {
    final c = focusColor ?? Colors.white;
    final btn = SenzuTvFocusWrapper(
      focusNode: focusNode,
      autofocus: autofocus,
      onKeyEvent: onKeyEvent,
      onTap: enabled ? onTap : null,
      enabled: enabled,
      focusedDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(60),
        color: c.withValues(alpha: 0.15),
      ),
      child: Padding(
        padding: padding,
        child: Icon(
          icon.icon,
          color: enabled ? iconColor : iconColor.withValues(alpha: 0.35),
          size: iconSize,
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

class SenzuTvLabelButton extends StatelessWidget {
  const SenzuTvLabelButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
    this.selected = false,
    this.selectedColor = Colors.red,
    this.unselectedColor = Colors.white,
    this.fontSize = 13.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.enabled = true,
  });

  final String label;
  final Icon? icon;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SenzuTvFocusWrapper(
      focusNode: focusNode,
      autofocus: autofocus,
      onTap: enabled ? onTap : null,
      enabled: enabled,
      focusedDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white54, width: 1.5),
      ),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon!.icon,
                  color: selected ? selectedColor : unselectedColor, size: 16),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    color: selected ? selectedColor : unselectedColor,
                    fontSize: fontSize,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  )),
            ),
            if (selected) Icon(Icons.check, color: selectedColor, size: 14),
          ],
        ),
      ),
    );
  }
}