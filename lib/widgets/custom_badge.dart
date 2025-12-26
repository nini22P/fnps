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

    final (Color bgColor, Color textColor) = useMemoized(() {
      if (primary) {
        return (colorScheme.primaryContainer, colorScheme.onPrimaryContainer);
      } else if (tertiary) {
        return (colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer);
      } else {
        return (
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant,
        );
      }
    }, [primary, tertiary, colorScheme]);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
