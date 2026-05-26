import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding, this.color});
  final Widget        child;
  final VoidCallback? onTap;
  final EdgeInsets?   padding;
  final Color?        color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: onTap != null
          ? InkWell(
              onTap:        onTap,
              borderRadius: BorderRadius.circular(16),
              child: padding != null ? Padding(padding: padding!, child: child) : child,
            )
          : (padding != null ? Padding(padding: padding!, child: child) : child),
    );
  }
}
