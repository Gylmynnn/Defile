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
  FileExplorerController(this.fileSystemService);

  final FileSystemService fileSystemService;

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
  final RxList<rust.FileEntry> clipboardEntries = <rust.FileEntry>[].obs;
  final RxBool clipboardIsCut = false.obs;

  final Rxn<rust.FileEntry> previewFile = Rxn();

  final RxList<String> pathHistory = <String>[].obs;
  final RxList<String> forwardHistory = <String>[].obs;

  final FocusNode searchFocusNode = FocusNode();

  @override
  void onInit() {
    super.onInit();
    ever(entries, (_) => _entriesRevision++);
    ever(
      selection,
      (_) => selectedPaths.assignAll(selection.map((e) => e.path)),
    );
    ever(places, (_) {
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
    });
    _bootstrap();
  }

  @override
  void onClose() {
    searchFocusNode.dispose();
    super.onClose();
  }

  Future<void> _bootstrap() async {
    try {
      homePath.value = rust_system.getHomeDirectory();
    } catch (_) {
      homePath.value = '/';
    }

    await Future.wait([loadDirectory(homePath.value), _loadPlaces()]);
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
