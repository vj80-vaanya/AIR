import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding});
  final Widget        child;
  final VoidCallback? onTap;
  final EdgeInsets?   padding;

  @override
  Widget build(BuildContext context) {
    return Card(
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
