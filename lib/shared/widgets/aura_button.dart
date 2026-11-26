import 'package:flutter/material.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/theme/aura_dimensions.dart';
import '../../core/theme/aura_typography.dart';

enum AuraButtonVariant {
  primary,
  secondary,
  danger,
}

class AuraButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AuraButtonVariant variant;
  final double? height;

  const AuraButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.variant = AuraButtonVariant.primary,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AuraThemeTokens.of(context);
    final enabled = onPressed != null && !isLoading;
    final btnHeight = height ?? AuraDimensions.buttonHeight;

    final (Color bg, Color fg, Color? border) = switch (variant) {
      AuraButtonVariant.primary => (
          enabled ? tokens.primary : tokens.disabled.withValues(alpha: 0.35),
          enabled ? tokens.onPrimary : tokens.textSecondary,
          null,
        ),
      AuraButtonVariant.secondary => (
          tokens.card,
          enabled ? tokens.textPrimary : tokens.disabled,
          tokens.divider,
        ),
      AuraButtonVariant.danger => (
          tokens.error.withValues(alpha: enabled ? 0.14 : 0.06),
          tokens.error,
          tokens.error.withValues(alpha: 0.35),
        ),
    };

    return SizedBox(
      height: btnHeight,
      width: double.infinity,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: AuraDimensions.radiusMedium,
          side: border != null
              ? BorderSide(color: border, width: 1)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: AuraDimensions.radiusMedium,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraDimensions.space4,
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading) ...[
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: fg,
                      ),
                    ),
                    const SizedBox(width: AuraDimensions.space3),
                  ] else if (icon != null) ...[
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(width: AuraDimensions.space2),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AuraTypography.button.copyWith(color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
