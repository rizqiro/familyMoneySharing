
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Small uppercase eyebrow above a block, with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: colors.inkMuted),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                child: Text(
                  action!,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: colors.ink),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Initial-in-a-circle. Identity is carried by the letter, never by colour
/// alone - the two members get the same neutral treatment.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.initial,
    this.size = 32,
    this.highlighted = false,
  });

  final String initial;
  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlighted ? colors.ink : colors.surfaceSunken,
        shape: BoxShape.circle,
        border: Border.all(color: colors.hairline),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: highlighted ? colors.onAccent : colors.inkSecondary,
        ),
      ),
    );
  }
}

/// Quiet chip for status and metadata.
class Tag extends StatelessWidget {
  const Tag({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.filled = false,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = color ?? colors.inkSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? tone.withValues(alpha: 0.10) : colors.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: tone),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: tone, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Shown where a list would otherwise be blank. Always offers the next step.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: compact ? Insets.xl : Insets.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: colors.inkMuted),
          ),
          const SizedBox(height: Insets.lg),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: Insets.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: colors.inkSecondary),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: Insets.xl),
            SizedBox(
              width: 220,
              child: FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One-line failure with a retry, used in place of a raw exception string.
///
/// [retryLabel] is required whenever [onRetry] is, so the button cannot quietly
/// ship an English word into an app whose default language is Indonesian. Pass
/// `t('common.retry')`.
class ErrorNote extends StatelessWidget {
  const ErrorNote({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
  }) : assert(
          onRetry == null || retryLabel != null,
          'a retry button needs a translated label',
        );

  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: colors.negative.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.field),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: colors.negative),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.negative),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(retryLabel!)),
        ],
      ),
    );
  }
}

/// A labelled figure. The value uses tabular figures when it sits in a column
/// that has to align.
class Stat extends StatelessWidget {
  const Stat({
    super.key,
    required this.label,
    required this.value,
    this.tone,
    this.align = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final Color? tone;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: text.labelSmall?.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: text.titleMedium?.copyWith(
            color: tone ?? colors.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
