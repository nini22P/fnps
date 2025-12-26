import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class CustomBadge extends HookWidget {
  const CustomBadge({
    super.key,
    required this.text,
    this.primary = false,
    this.tertiary = false,
  });

  final String text;
  final bool primary;
  final bool tertiary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (Color bgColor, Color textColor, Color? borderColor) = useMemoized(
      () {
        if (primary) {
          return (
            colorScheme.primaryContainer,
            colorScheme.onPrimaryContainer,
            colorScheme.primaryContainer,
          );
        } else if (tertiary) {
          return (
            colorScheme.tertiaryContainer,
            colorScheme.onTertiaryContainer,
            colorScheme.tertiaryContainer,
          );
        } else {
          return (
            Colors.transparent,
            colorScheme.onSurfaceVariant,
            colorScheme.outlineVariant,
          );
        }
      },
      [primary, tertiary, colorScheme],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: borderColor != null
            ? Border.all(color: borderColor, width: 0.5)
            : null,
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.25,
        ),
      ),
    );
  }
}
