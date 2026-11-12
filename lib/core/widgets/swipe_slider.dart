import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SwipeSliderButton extends StatefulWidget {
  final String text;
  final VoidCallback onSwipeCompleted;
  final Color backgroundColor;
  final Color thumbColor;
  final IconData icon;

  const SwipeSliderButton({
    super.key,
    required this.text,
    required this.onSwipeCompleted,
    this.backgroundColor = AppColors.primary,
    this.thumbColor = Colors.white,
    this.icon = Icons.arrow_forward_rounded,
  });

  @override
  State<SwipeSliderButton> createState() => _SwipeSliderButtonState();
}

class _SwipeSliderButtonState extends State<SwipeSliderButton> {
  double _dragPosition = 0.0;
  bool _isCompleted = false;

  @override
  Widget build(BuildContext context) {
    const double height = 56.0;
    const double thumbSize = 48.0;
    const double padding = 4.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - thumbSize - (padding * 2);

        return Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: [
              BoxShadow(
                color: widget.backgroundColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Shimmer / Text Label
              Center(
                child: Text(
                  _isCompleted ? 'Confirmed!' : widget.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),

              // Draggable Thumb
              Positioned(
                left: padding + _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_isCompleted) return;
                    setState(() {
                      _dragPosition = (_dragPosition + details.delta.dx)
                          .clamp(0.0, maxDrag);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_isCompleted) return;
                    if (_dragPosition >= maxDrag * 0.85) {
                      setState(() {
                        _dragPosition = maxDrag;
                        _isCompleted = true;
                      });
                      widget.onSwipeCompleted();
                    } else {
                      setState(() {
                        _dragPosition = 0.0;
                      });
                    }
                  },
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: widget.thumbColor,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isCompleted ? Icons.check_rounded : widget.icon,
                      color: widget.backgroundColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
