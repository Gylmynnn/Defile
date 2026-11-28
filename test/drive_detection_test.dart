import 'package:defile/src/features/file_explorer/services/drive_service.dart';
import 'package:flutter_test/flutter_test.dart';

DetectedVolume _volume({
  required String device,
  String fstype = 'vfat',
  String? mountPoint,
  bool removable = true,
}) {
  return DetectedVolume(
    device: device,
    diskDevice: '/dev/sda',
    label: 'USB',
    fstype: fstype,
    mountPoint: mountPoint,
    removable: removable,
  );
}

void main() {
  group('parseMountEntries', () {
    test('decodes octal escapes in labels and paths', () {
      final List<MountEntry> entries = parseMountEntries(
        'proc /proc proc rw,nosuid 0 0\n'
        '/dev/sda1 /run/media/user/My\\040Disk vfat rw,relatime 0 0\n',
      );

      expect(entries, hasLength(2));
      expect(entries.last.source, '/dev/sda1');
      expect(entries.last.target, '/run/media/user/My Disk');
      expect(entries.last.fstype, 'vfat');
    });

    test('ignores blank and malformed lines', () {
      final List<MountEntry> entries = parseMountEntries(
        '\n'
        'only-one-field\n'
        '/dev/sdb1 /mnt/data ext4 rw 0 0\n',
      );

      expect(entries, hasLength(1));
      expect(entries.single.target, '/mnt/data');
    });

    test('decodes a source path with spaces', () {
      final List<MountEntry> entries = parseMountEntries(
        '/dev/disk/by-label/My\\040Stick /media/usb ext4 rw 0 0\n',
      );

      expect(entries.single.source, '/dev/disk/by-label/My Stick');
    });
  });

  group('autoMountPlan', () {
    test('selects only plugged, unmounted removable filesystems', () {
      final List<DetectedVolume> volumes = <DetectedVolume>[
        _volume(device: '/dev/sda1'),
        _volume(device: '/dev/sdb1', removable: false),
        _volume(device: '/dev/sdc1', mountPoint: '/run/media/user/STICK'),
        _volume(device: '/dev/sdd1'),
        _volume(device: '/dev/sde1'),
        _volume(device: '/dev/sdf1', fstype: 'swap'),
        _volume(device: '/dev/sdg1', fstype: ''),
      ];

      final List<DetectedVolume> plan = DriveService.autoMountPlan(
        volumes: volumes,
        enabled: true,
        attempted: <String>{'/dev/sdd1'},
        mounting: <String>{'/dev/sde1'},
      );

      expect(
        plan.map((DetectedVolume volume) => volume.device),
        <String>['/dev/sda1'],
      );
    });

    test('returns nothing when disabled', () {
      final List<DetectedVolume> plan = DriveService.autoMountPlan(
        volumes: <DetectedVolume>[_volume(device: '/dev/sda1')],
        enabled: false,
        attempted: <String>{},
        mounting: <String>{},
      );

      expect(plan, isEmpty);
    });
  });

  group('MTP helpers', () {
    test('recognizes the Still-Image capture interface', () {
      expect(isMtpInterfaceClass('06', '01'), isTrue);
      expect(isMtpInterfaceClass('06', '02'), isFalse);
      expect(isMtpInterfaceClass('08', '06'), isFalse);
    });

    test('builds a zero-padded gvfs activation URI', () {
      expect(mtpUriFor(3, 5), 'mtp://[usb:003,005]/');
      expect(mtpUriFor(12, 128), 'mtp://[usb:012,128]/');
    });

    test('decodes gvfs mount directory names', () {
      expect(decodeMtpMountName('mtp:host=Pixel_5'), 'Pixel 5');
      expect(
        decodeMtpMountName('mtp:host=SAMSUNG%20Galaxy'),
        'SAMSUNG Galaxy',
      );
      expect(decodeMtpMountName('mtp:host=[usb:003,005]'), '[usb:003,005]');
    });
  });
}
