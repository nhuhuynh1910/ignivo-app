import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class PtzControl extends StatelessWidget {
  const PtzControl({
    super.key,
    required this.onDirectionPressed,
  });

  final ValueChanged<String> onDirectionPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_drop_up_rounded, size: 36),
          color: AppColors.primary,
          onPressed: () => onDirectionPressed('UP'),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_left_rounded, size: 36),
              color: AppColors.primary,
              onPressed: () => onDirectionPressed('LEFT'),
            ),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.backgroundBlueSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.center_focus_strong_rounded, color: AppColors.primary),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_right_rounded, size: 36),
              color: AppColors.primary,
              onPressed: () => onDirectionPressed('RIGHT'),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 36),
          color: AppColors.primary,
          onPressed: () => onDirectionPressed('DOWN'),
        ),
      ],
    );
  }
}
