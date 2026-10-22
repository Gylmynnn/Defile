part of 'settings_dialog.dart';

class _SidebarItemWidget extends StatelessWidget {
  const _SidebarItemWidget({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverRegion(
      builder: (context, hovered) {
        final Color bgColor = active
            ? context.colors.rowSelected
            : (hovered ? context.colors.rowHover : Colors.transparent);

        final Color contentColor = active
            ? context.colors.textStrong
            : (hovered
                  ? context.colors.textLabel
                  : context.colors.textSecondary);

        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: 31,
            margin: const EdgeInsets.symmetric(vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                Icon(icon, size: 15, color: contentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                      color: contentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CustomSectionCard extends StatelessWidget {
  const _CustomSectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _CustomDivider extends StatelessWidget {
  const _CustomDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: context.colors.chip);
  }
}

class _CustomSettingRow extends StatelessWidget {
  const _CustomSettingRow({
    required this.title,
    this.subtitle,
    this.linkText,
    this.onLinkTap,
    required this.control,
  });

  final String title;
  final String? subtitle;
  final String? linkText;
  final VoidCallback? onLinkTap;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textStrong,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.colors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
                if (linkText != null && linkText!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: onLinkTap,
                      child: Text(
                        linkText!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.colors.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          control,
        ],
      ),
    );
  }
}

class _CustomButton extends StatelessWidget {
  const _CustomButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppButton(label: label, onTap: onTap, fontWeight: FontWeight.w400);
  }
}

class _CustomSwitch extends StatelessWidget {
  const _CustomSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeInOut,
          width: 34,
          height: 19,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: value ? context.colors.accent : context.colors.switchTrack,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: value
                  ? context.colors.selectionBorder
                  : context.colors.chipBorder,
              width: 1,
            ),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? Colors.white : context.colors.textFaint,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomDropdown<T> extends StatefulWidget {
  const _CustomDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  State<_CustomDropdown<T>> createState() => _CustomDropdownState<T>();
}

class _CustomDropdownState<T> extends State<_CustomDropdown<T>> {
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final DropdownMenuItem<T> selectedItem = widget.items.firstWhere(
      (item) => item.value == widget.value,
      orElse: () => widget.items.first,
    );

    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(context.colors.menu),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: 0.5),
        ),
        elevation: const WidgetStatePropertyAll(10),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(248, 0)),
        maximumSize: const WidgetStatePropertyAll(Size(248, 360)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: context.colors.menuBorder),
        ),
      ),
      menuChildren: [
        for (final item in widget.items)
          MenuItemButton(
            onPressed: item.enabled
                ? () {
                    _menuController.close();
                    widget.onChanged(item.value);
                  }
                : null,
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              minimumSize: const WidgetStatePropertyAll(Size(0, 30)),
              maximumSize: const WidgetStatePropertyAll(
                Size(double.infinity, 30),
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return context.colors.surfaceHigh;
                }
                return Colors.transparent;
              }),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    child: item.value == widget.value
                        ? Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: context.colors.accent,
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: 12.5,
                        color: item.enabled
                            ? context.colors.menuLabel
                            : context.colors.textFaint.withValues(alpha: 0.5),
                      ),
                      child: item.child,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      builder: (context, controller, child) {
        return GestureDetector(
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: context.colors.elevated,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: context.colors.elevatedBorder,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textLabel,
                  ),
                  child: selectedItem.child,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.unfold_more,
                    size: 14,
                    color: context.colors.textFaint,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverRegion(
      builder: (context, hovered) {
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: hovered
                  ? context.colors.elevatedHover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.close,
              size: 15,
              color: hovered
                  ? context.colors.textStrong
                  : context.colors.textFaint,
            ),
          ),
        );
      },
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? context.colors.textStrong
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Theme & Font Option Rows
// =====================================================================

class _ThemeChoice {
  _ThemeChoice({required this.name, required this.path});

  final String name;
  final String? path;
}

class _CustomThemeRow extends StatelessWidget {
  const _CustomThemeRow({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final _ThemeChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDefault = choice.name.isEmpty;

    final Widget preview = isDefault
        ? const Center(child: FolderGlyph(width: 20, height: 16))
        : ThemedIcon(
            iconNames: const ['folder', 'inode-directory'],
            size: 18,
            theme: choice.name,
            fallback: Icon(
              Icons.folder,
              size: 16,
              color: context.colors.textFaint,
            ),
          );

    return HoverRegion(
      builder: (context, hovered) {
        final Widget row = Container(
          height: 30,
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? context.colors.rowSelected
                : hovered
                ? context.colors.rowHover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              SizedBox(width: 22, child: preview),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isDefault ? 'Application default' : choice.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected
                        ? context.colors.textStrong
                        : context.colors.textLabel,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check, size: 14, color: context.colors.accent),
            ],
          ),
        );

        return GestureDetector(
          onTap: onTap,
          child: choice.path == null
              ? row
              : Tooltip(message: choice.path!, child: row),
        );
      },
    );
  }
}

class _CustomFontRow extends StatefulWidget {
  const _CustomFontRow({
    required this.fontName,
    required this.isDefault,
    required this.selected,
    required this.onTap,
  });

  final String fontName;
  final bool isDefault;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CustomFontRow> createState() => _CustomFontRowState();
}

class _CustomFontRowState extends State<_CustomFontRow> {
  bool _previewReady = false;

  @override
  void initState() {
    super.initState();
    // Paint the row immediately with the default font, then swap in the
    // preview typeface next frame. Avoids a visible stall on first open while
    // the engine loads each font.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _previewReady = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final String label = widget.isDefault
        ? 'Application default'
        : widget.fontName;
    final String? previewFamily = widget.isDefault || !_previewReady
        ? null
        : widget.fontName;

    return HoverRegion(
      builder: (context, hovered) {
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: 30,
            margin: const EdgeInsets.symmetric(vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: widget.selected
                  ? context.colors.rowSelected
                  : hovered
                  ? context.colors.rowHover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colors.chip,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Aa',
                    style: TextStyle(
                      fontFamily: previewFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: widget.selected
                          ? context.colors.accent
                          : context.colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: previewFamily,
                      fontSize: 12,
                      color: widget.selected
                          ? context.colors.textStrong
                          : context.colors.textLabel,
                      fontWeight: widget.selected
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (widget.selected)
                  Icon(Icons.check, size: 14, color: context.colors.accent),
              ],
            ),
          ),
        );
      },
    );
  }
}
