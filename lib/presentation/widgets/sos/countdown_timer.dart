import 'package:flutter/material.dart';

class CountdownTimer extends StatelessWidget {
  const CountdownTimer({super.key, required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: Container(
        key:    ValueKey(seconds),
        width:  130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
          gradient: const RadialGradient(
            colors: [
              Color(0x33FFFFFF), // white 20%
              Color(0x00FFFFFF),
            ],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$seconds',
          style: const TextStyle(
            color:         Colors.white,
            fontSize:      72,
            fontWeight:    FontWeight.w900,
            letterSpacing: -2,
            height:        1,
          ),
        ),
      ),
    );
  }
}
