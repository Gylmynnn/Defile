import 'package:defile/src/features/file_explorer/services/file_system_service.dart';

import '../utils/app_toast.dart';

import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

part 'explorer_navigation.dart';
part 'explorer_operations.dart';
part 'explorer_selection.dart';

enum ExplorerViewMode { grid, list, compact }

enum ExplorerLocation { directory, recent, trash }

class FileExplorerController extends GetxController {
  FileExplorerController(
    this.fileSystemService, {
    this.initialPath,
    this.initialLocation,
  });

  final FileSystemService fileSystemService;

  /// Directory a freshly created tab should open instead of Home.
  final String? initialPath;

  /// Specific view location (e.g. recent or trash).
  final ExplorerLocation? initialLocation;

  final RxString homePath = ''.obs;
  final RxString currentPath = ''.obs;
  final RxList<rust.FileEntry> entries = <rust.FileEntry>[].obs;
  final RxList<rust_system.Place> places = <rust_system.Place>[].obs;
  final RxList<rust_system.Place> quickPlaces = <rust_system.Place>[].obs;
  final RxList<rust_system.Place> folderPlaces = <rust_system.Place>[].obs;
  final RxList<rust_system.Place> drivePlaces = <rust_system.Place>[].obs;
  final RxMap<String, rust_system.DiskUsage> driveUsages =
      <String, rust_system.DiskUsage>{}.obs;
  final Rxn<rust_system.DiskUsage> diskUsage = Rxn();

  int _entriesRevision = 0;
  bool _systemStateSeeded = false;
  List<rust.FileEntry>? _visibleCache;
  int _visibleCacheRevision = -1;
  String? _visibleCacheQuery;

  List<String>? _breadcrumbsCache;
  String? _breadcrumbsKey;

  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();
  final Rx<ExplorerLocation> location = ExplorerLocation.directory.obs;

  final Rx<ExplorerViewMode> viewMode = ExplorerViewMode.grid.obs;
  final RxBool showSidebar = true.obs;
  final RxBool isSearching = false.obs;
  final RxString searchQuery = ''.obs;

  final RxList<rust.FileEntry> selection = <rust.FileEntry>[].obs;
  final RxSet<String> selectedPaths = <String>{}.obs;
  final RxnString selectionAnchor = RxnString();
  List<rust.FileEntry> _selectionSnapshot = const <rust.FileEntry>[];

  List<rust.FileEntry> get selectionSnapshot => _selectionSnapshot;
  final RxList<rust.FileEntry> clipboardEntries = <rust.FileEntry>[].obs;
  final RxBool clipboardIsCut = false.obs;
  final RxString terminal = ''.obs;
  final RxList<String> availableTerminals = <String>[].obs;

  final Rxn<rust.FileEntry> previewFile = Rxn();

  final RxList<String> pathHistory = <String>[].obs;
  final RxList<String> forwardHistory = <String>[].obs;

  final FocusNode searchFocusNode = FocusNode();
  final FocusNode keyboardFocusNode = FocusNode();

  @override
  void onInit() {
    super.onInit();
    ever(entries, (_) => _entriesRevision++);
    ever(selection, (List<rust.FileEntry> selected) {
      _selectionSnapshot = List<rust.FileEntry>.unmodifiable(selected);
      selectedPaths.assignAll(selected.map((entry) => entry.path));
    });
    ever(places, (_) => _splitPlaces());
    _bootstrap();
  }

  @override
  void onClose() {
    searchFocusNode.dispose();
    keyboardFocusNode.dispose();
    super.onClose();
  }

  /// Splits [places] into the sidebar sections (quick access, folders, drives).
  void _splitPlaces() {
    quickPlaces.assignAll(
      places.where(
        (place) =>
            place.kind != rust_system.PlaceKind.folder &&
            place.kind != rust_system.PlaceKind.drive,
      ),
    );
    folderPlaces.assignAll(
      places.where((place) => place.kind == rust_system.PlaceKind.folder),
    );
    drivePlaces.assignAll(
      places.where((place) => place.kind == rust_system.PlaceKind.drive),
    );
  }

  /// Copies shared system data (paths, places, drive usage and terminal
  /// settings) from [source] so a freshly opened tab does not repeat the
  /// expensive filesystem discovery every tab otherwise performs.
  ///
  /// Only seeds when [source] has finished listing its places, otherwise the
  /// new tab loads its own data so the sidebar is never left empty.
  void seedSystemState(FileExplorerController source) {
    if (source.places.isEmpty) return;

    _systemStateSeeded = true;

    if (source.homePath.value.isNotEmpty) {
      homePath.value = source.homePath.value;
    }
    places.assignAll(source.places);
    _splitPlaces();
    driveUsages.assignAll(source.driveUsages);
    availableTerminals.assignAll(source.availableTerminals);
    terminal.value = source.terminal.value;
  }

  /// Loads system-wide data shared by every tab: places (with drive usage)
  /// and terminal settings.
  Future<void> _loadSharedSystemState() {
    return Future.wait([
      _loadPlaces(),
      _loadTerminalSettings(),
    ]);
  }

  Future<void> _bootstrap() async {
    if (homePath.value.isEmpty) {
      try {
        homePath.value = rust_system.getHomeDirectory();
      } catch (_) {
        homePath.value = '/';
      }
    }

    // Seeded tabs reuse the system state of the tab they were opened from.
    final Future<void> systemState = _systemStateSeeded
        ? Future.value()
        : _loadSharedSystemState();

    if (initialLocation == ExplorerLocation.recent) {
      await systemState;
      await showRecent();
    } else if (initialLocation == ExplorerLocation.trash) {
      await systemState;
      await showTrash();
    } else {
      await Future.wait([
        loadDirectory(initialPath ?? homePath.value),
        systemState,
      ]);
    }
  }

  /// Short label shown on the tab strip.
  String get tabTitle {
    switch (location.value) {
      case ExplorerLocation.recent:
        return 'Recents';
      case ExplorerLocation.trash:
        return 'Trash';
      case ExplorerLocation.directory:
        if (currentPath.value.isEmpty) return 'Home';
        if (currentPath.value == homePath.value) return 'Home';

        final String base = p.basename(currentPath.value);
        return base.isEmpty ? currentPath.value : base;
    }
  }

  List<rust.FileEntry> get visibleEntries {
    final String query = searchQuery.value.trim().toLowerCase();

    if (_visibleCache != null &&
        _visibleCacheRevision == _entriesRevision &&
        _visibleCacheQuery == query &&
        _visibleCache!.length == entries.length) {
      return _visibleCache!;
    }

    final List<rust.FileEntry> result = query.isEmpty
        ? entries
        : entries
              .where((entry) => entry.name.toLowerCase().contains(query))
              .toList();

    _visibleCache = result;
    _visibleCacheRevision = _entriesRevision;
    _visibleCacheQuery = query;
    return result;
  }
}
