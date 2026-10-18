import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../controllers/file_explorer_controller.dart';
import '../../services/theme_service.dart';
import 'themed_icon.dart';

class OpenWithSubmenu extends StatefulWidget {
  const OpenWithSubmenu({
    super.key,
    required this.entry,
    required this.onDismiss,
  });

  final rust.FileEntry entry;
  final VoidCallback onDismiss;

  @override
  State<OpenWithSubmenu> createState() => _OpenWithSubmenuState();
}

class _OpenWithSubmenuState extends State<OpenWithSubmenu> {
  FileExplorerController get _controller => Get.find<FileExplorerController>();

  Duration get _animDuration => Get.isRegistered<ThemeService>()
      ? Get.find<ThemeService>().animationDuration
      : Duration.zero;

  List<rust_system.OpenWithApp> _apps = const [];
  bool _loading = true;
  rust_system.OpenWithApp? _hoveredApp;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<rust_system.OpenWithApp> apps = await _controller
        .listOpenWithApps(widget.entry.path);

    if (!mounted) return;
    setState(() {
      _apps = apps;
      _loading = false;
    });
  }

  void _open(rust_system.OpenWithApp app) {
    _controller.openWith(widget.entry, app);
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 472,
      height: 320,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 220, child: _buildList()),
          Container(width: 1, color: AppColors.divider),
          Expanded(child: _buildDetails()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_apps.isEmpty) {
      return Center(
        child: Text(
          'No applications found',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      itemCount: _apps.length,
      itemBuilder: (context, index) {
        final app = _apps[index];
        return _OpenWithRow(
          name: app.name,
          active: _hoveredApp == app,
          onHoverChanged: (hovered) {
            setState(() => _hoveredApp = hovered ? app : null);
          },
          onTap: () => _open(app),
        );
      },
    );
  }

  Widget _buildDetails() {
    final rust_system.OpenWithApp? app = _hoveredApp;

    return AnimatedSwitcher(
      duration: _animDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: app == null
          ? const _DetailsPlaceholder(key: ValueKey('placeholder'))
          : _Details(
              key: ValueKey(app.id),
              app: app,
              fileName: widget.entry.name,
              filePath: widget.entry.path,
            ),
    );
  }
}

class _OpenWithRow extends StatefulWidget {
  const _OpenWithRow({
    required this.name,
    required this.active,
    required this.onTap,
    required this.onHoverChanged,
  });

  final String name;
  final bool active;
  final VoidCallback onTap;
  final ValueChanged<bool> onHoverChanged;

  @override
  State<_OpenWithRow> createState() => _OpenWithRowState();
}

class _OpenWithRowState extends State<_OpenWithRow> {
  bool _hovered = false;

  void _setHovered(bool value) {
    setState(() => _hovered = value);
    widget.onHoverChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final bool active = _hovered || widget.active;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 34,
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.open_in_new, size: 15, color: AppColors.menuIcon),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 15,
                color: active ? AppColors.textSecondary : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsPlaceholder extends StatelessWidget {
  const _DetailsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apps_outlined, size: 30, color: AppColors.textFaint),
            const SizedBox(height: 10),
            Text(
              'Hover an application to preview it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    super.key,
    required this.app,
    required this.fileName,
    required this.filePath,
  });

  final rust_system.OpenWithApp app;
  final String fileName;
  final String filePath;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.chip,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.chipBorder),
                    ),
                    child: app.icon.isEmpty
                        ? Icon(
                            Icons.open_in_new,
                            size: 21,
                            color: AppColors.accent,
                          )
                        : ThemedIcon(
                            iconNames: [app.icon],
                            size: 23,
                            fallback: Icon(
                              Icons.open_in_new,
                              size: 21,
                              color: AppColors.accent,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    app.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textStrong,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    app.id,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textFaint,
                    ),
                  ),
                  if (app.comment.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      app.comment,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (app.exec.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(height: 1, color: AppColors.divider),
                    const SizedBox(height: 10),
                    _DetailsLabel('Command'),
                    const SizedBox(height: 3),
                    Text(
                      app.exec,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(height: 1, color: AppColors.divider),
                  const SizedBox(height: 10),
                  _DetailsLabel('Opens'),
                  const SizedBox(height: 3),
                  Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    filePath,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.touch_app_outlined, size: 13, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                'Click to open',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailsLabel extends StatelessWidget {
  const _DetailsLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textFaint,
      ),
    );
  }
}
