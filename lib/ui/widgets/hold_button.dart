import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// The big circular "Hold for 5s to check in" control. A ring fills over the
/// hold duration; releasing early cancels. Completing fires [onComplete].
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    required this.label,
    required this.icon,
    required this.hold,
    required this.onComplete,
    this.color = AppTheme.accent,
  });

  final String label;
  final IconData icon;
  final Duration hold;
  final VoidCallback onComplete;
  final Color color;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.hold,
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        widget.onComplete();
        _ctrl.reset();
      }
    });

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _down(_) => _ctrl.forward();
  void _up([_]) {
    if (_ctrl.status != AnimationStatus.completed) _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _up,
      child: SizedBox(
        width: 230,
        height: 230,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 230,
                height: 230,
                child: CircularProgressIndicator(
                  value: _ctrl.value == 0 ? null : _ctrl.value,
                  strokeWidth: 8,
                  backgroundColor: const Color(0xFF3A3B40),
                  valueColor: AlwaysStoppedAnimation(widget.color),
                ),
              ),
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, size: 34, color: Colors.white),
                    const SizedBox(height: 10),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
