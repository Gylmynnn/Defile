import 'package:defile/src/features/file_explorer/utils/place_icons.dart';
import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

rust_system.Place _place(rust_system.PlaceKind kind, String path) =>
    rust_system.Place(label: 'x', path: path, kind: kind);

void main() {
  test('quick places share the sidebar glyphs', () {
    expect(
      placeIcon(_place(rust_system.PlaceKind.home, '/home/me')),
      CupertinoIcons.home,
    );
    expect(
      placeIcon(_place(rust_system.PlaceKind.recent, '')),
      CupertinoIcons.time,
    );
    expect(
      placeIcon(_place(rust_system.PlaceKind.trash, '')),
      CupertinoIcons.trash,
    );
    expect(
      placeIcon(_place(rust_system.PlaceKind.drive, '/run/media/me/Disk')),
      Icons.storage,
    );
  });

  test('well-known folders get their own glyph, localized names included', () {
    expect(
      folderPlaceIcon(
        _place(rust_system.PlaceKind.folder, '/home/me/Downloads'),
      ),
      CupertinoIcons.cloud_download,
    );
    expect(
      folderPlaceIcon(_place(rust_system.PlaceKind.folder, '/home/me/Unduhan')),
      CupertinoIcons.cloud_download,
    );
    expect(
      folderPlaceIcon(_place(rust_system.PlaceKind.folder, '/home/me/Music')),
      CupertinoIcons.tv_music_note,
    );
    expect(
      folderPlaceIcon(_place(rust_system.PlaceKind.folder, '/home/me/Musik')),
      CupertinoIcons.tv_music_note,
    );
    expect(
      folderPlaceIcon(_place(rust_system.PlaceKind.folder, '/home/me/random')),
      CupertinoIcons.folder,
    );
  });
}
