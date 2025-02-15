import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class CustomBadge extends HookWidget {
  const CustomBadge({super.key, required this.text, this.primary = false});
  final String text;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Badge(
      label: Text(text.toUpperCase()),
      backgroundColor:
          primary ? Theme.of(context).colorScheme.primary : Colors.blueGrey,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }
}
