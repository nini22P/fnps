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
    return Badge(
      label: Text(text.toUpperCase()),
      textColor: Theme.of(context).colorScheme.surface,
      backgroundColor: primary
          ? Theme.of(context).colorScheme.primary
          : tertiary
              ? Theme.of(context).colorScheme.tertiary
              : Theme.of(context).colorScheme.secondary,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }
}
