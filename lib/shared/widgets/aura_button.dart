import 'package:flutter/material.dart';
import '../../core/theme/aura_colors.dart';
import '../../core/theme/aura_dimensions.dart';
import '../../core/theme/aura_typography.dart';

enum AuraButtonVariant {
  primary,
  secondary,
  danger,
}

class AuraButton extends StatefulWidget {
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
  State<AuraButton> createState() => _AuraButtonState();
}

class _AuraButtonState extends State<AuraButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = widget.onPressed != null && !widget.isLoading;
    final btnHeight = widget.height ?? AuraDimensions.buttonHeight;

    final (Color bg, Color fg, Color? border) = switch (widget.variant) {
      AuraButtonVariant.primary => (
          enabled ? AuraColors.primary(isDark) : AuraColors.disabled(isDark),
          isDark
              ? (enabled ? const Color(0xFF171D15) : AuraColors.darkTextPrimary)
              : AuraColors.white,
          null,
        ),
      AuraButtonVariant.secondary => (
          AuraColors.card(isDark),
          enabled ? AuraColors.textPrimary(isDark) : AuraColors.disabled(isDark),
          AuraColors.divider(isDark),
        ),
      AuraButtonVariant.danger => (
          AuraColors.error(isDark).withValues(alpha: enabled ? 0.14 : 0.06),
          AuraColors.error(isDark),
          AuraColors.error(isDark).withValues(alpha: 0.35),
        ),
    };

    return Listener(
      onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onPointerUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onPointerCancel: enabled ? (_) => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled || widget.isLoading ? 1.0 : 0.55,
          child: SizedBox(
            height: btnHeight,
            width: double.infinity,
            child: Material(
              color: bg,
              borderRadius: AuraDimensions.radiusMedium,
              child: InkWell(
                onTap: enabled ? widget.onPressed : null,
                borderRadius: AuraDimensions.radiusMedium,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: AuraDimensions.radiusMedium,
                    border: border != null
                        ? Border.all(color: border, width: 1)
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraDimensions.space5,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.isLoading) ...[
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: fg,
                          ),
                        ),
                        const SizedBox(width: AuraDimensions.space3),
                      ] else if (widget.icon != null) ...[
                        Icon(widget.icon, size: 20, color: fg),
                        const SizedBox(width: AuraDimensions.space2),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AuraTypography.button.copyWith(color: fg),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
