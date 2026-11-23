import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;
import 'package:material_ui/material_ui.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.selected = false,
  }) : primary = false,
       plain = false;
  const AppButton.primary({
    super.key,
    required this.onPressed,
    required this.child,
  }) : primary = true,
       plain = false,
       selected = false;
  const AppButton.plain({
    super.key,
    required this.onPressed,
    required this.child,
    this.selected = false,
  }) : primary = false,
       plain = true;
  AppButton.icon({
    super.key,
    required this.onPressed,
    required Widget icon,
    required Widget label,
    this.primary = false,
    this.plain = false,
  }) : selected = false,
       child = Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           icon,
           const SizedBox(width: 8),
           Flexible(child: label),
         ],
       );

  final VoidCallback? onPressed;
  final Widget child;
  final bool primary, plain, selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = primary ? colors.onPrimary : colors.onSurface;
    return glass.GlassButton.custom(
      surfaceStyle: glass.GlassSurfaceStyle.glass,
      onTap: onPressed ?? () {},
      enabled: onPressed != null,
      height: 44,
      isSelected: selected,
      stretch: .12,
      style: primary
          ? glass.GlassButtonStyle.prominent
          : plain && !selected
          ? glass.GlassButtonStyle.transparent
          : glass.GlassButtonStyle.filled,
      tintColor: primary
          ? colors.primary
          : selected
          ? colors.primary.withValues(alpha: .14)
          : null,
      shape: const glass.LiquidRoundedSuperellipse(borderRadius: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: IconTheme.merge(
          data: IconThemeData(color: foreground, size: 19),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontFamily: Theme.of(context).textTheme.labelLarge?.fontFamily,
              color: foreground,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = glass.GlassIconButton(
      surfaceStyle: glass.GlassSurfaceStyle.glass,
      icon: icon,
      onPressed: onPressed,
      semanticLabel: tooltip,
      iconColor: Theme.of(context).colorScheme.primary,
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class AppDialog extends StatelessWidget {
  const AppDialog({super.key, this.title, this.content, this.actions});
  final Widget? title, content;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: glass.GlassContainer.card(
      useOwnLayer: true,
      settings:
          (Theme.of(context).brightness == Brightness.dark
                  ? glass.LiquidGlassSettings.ios27Dark
                  : glass.LiquidGlassSettings.ios27Light)
              .copyWith(
                glassColor: Theme.of(context).colorScheme.surface
                    .withValues(alpha: .88),
                blur: 18,
              ),
      padding: const EdgeInsets.all(24),
      shape: const glass.LiquidRoundedSuperellipse(borderRadius: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight:
              (MediaQuery.sizeOf(context).height -
                      MediaQuery.viewInsetsOf(context).bottom -
                      104)
                  .clamp(160, 900),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  child: title!,
                ),
              ),
            if (content != null) Flexible(child: content!),
            if (actions != null)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions!,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.contentPadding = EdgeInsets.zero,
  });
  final Widget title;
  final Widget? subtitle, leading, trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry contentPadding;
  @override
  Widget build(BuildContext context) => glass.GlassListTile(
    title: title,
    subtitle: subtitle,
    leading: leading,
    trailing: trailing,
    onTap: onTap,
    contentPadding: contentPadding,
    titleStyle: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
    subtitleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
  );
}

class AppSwitchTile extends StatelessWidget {
  const AppSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.contentPadding = EdgeInsets.zero,
  });
  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) => AppListTile(
    contentPadding: contentPadding,
    title: title,
    subtitle: subtitle,
    trailing: glass.GlassSwitch(
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).colorScheme.primary,
    ),
    onTap: onChanged == null ? null : () => onChanged!(!value),
  );
}

class AppChoice extends StatelessWidget {
  const AppChoice({
    super.key,
    required this.label,
    required this.options,
    required this.onChanged,
    this.value,
  });
  final String label;
  final Map<String, String> options;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 8),
      glass.GlassPicker(
        textStyle: Theme.of(context).textTheme.bodyMedium,
        value: options[value],
        placeholder: '请选择',
        semanticLabel: label,
        surfaceStyle: glass.GlassSurfaceStyle.solid,
        onTap: () async {
          final picked = await showDialog<String>(
            context: context,
            builder: (c) => AppDialog(
              title: Text(label),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in options.entries)
                      AppListTile(
                        title: Text(
                          option.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: option.key == value
                            ? const Icon(Icons.check_rounded)
                            : null,
                        onTap: () => Navigator.pop(c, option.key),
                      ),
                  ],
                ),
              ),
              actions: [
                AppButton.plain(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('取消'),
                ),
              ],
            ),
          );
          if (picked != null && context.mounted) onChanged(picked);
        },
      ),
    ],
  );
}

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xff17191e), Color(0xff22262e)]
              : const [Color(0xffedf1f7), Color(0xfffafafa)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -140,
            right: -100,
            width: 480,
            height: 480,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(dark ? 0xff667b9d : 0xffb2c2db)
                        .withValues(alpha: dark ? .2 : .38),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -180,
            left: -160,
            width: 560,
            height: 560,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Color(dark ? 0xff938f88 : 0xffddd7ce)
                        .withValues(alpha: .18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
