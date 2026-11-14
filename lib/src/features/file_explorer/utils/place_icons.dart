import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Icon used for a quick-access place (Home, Recents, Trash, Network, ...).
///
/// Shared by the main sidebar and the destination picker so both surfaces stay
/// visually identical.
IconData placeIcon(rust_system.Place place) {
  switch (place.kind) {
    case rust_system.PlaceKind.home:
      return CupertinoIcons.home;
    case rust_system.PlaceKind.recent:
      return CupertinoIcons.time;
    case rust_system.PlaceKind.trash:
      return CupertinoIcons.trash;
    case rust_system.PlaceKind.network:
      return CupertinoIcons.wifi;
    case rust_system.PlaceKind.folder:
      return Icons.folder;
    case rust_system.PlaceKind.drive:
      return Icons.storage;
  }
}

/// Cupertino glyph for a well-known XDG folder, matched on the directory
/// basename so localized homes ("Dokumen", "Unduhan", ...) still resolve.
IconData folderPlaceIcon(rust_system.Place place) {
  final List<String> parts = place.path
      .split('/')
      .where((String segment) => segment.isNotEmpty)
      .toList();
  final String name = parts.isEmpty ? '' : parts.last.toLowerCase();

  switch (name) {
    case 'documents':
    case 'dokumen':
      return Icons.folder_open;
    case 'downloads':
    case 'unduhan':
      return CupertinoIcons.cloud_download;
    case 'pictures':
    case 'gambar':
      return CupertinoIcons.photo;
    case 'music':
    case 'musik':
      return CupertinoIcons.tv_music_note;
    case 'videos':
    case 'video':
      return CupertinoIcons.film;
    case 'desktop':
      return CupertinoIcons.device_laptop;
    case 'public':
    case 'publik':
      return CupertinoIcons.person_2;
    case 'templates':
    case 'templat':
      return CupertinoIcons.doc_on_doc;
    default:
      return CupertinoIcons.folder;
  }
}

/// Glyph shown for a mounted drive/volume tile.
const IconData sidebarDriveIcon = CupertinoIcons.device_desktop;
