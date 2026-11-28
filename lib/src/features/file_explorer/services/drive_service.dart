import 'dart:async';
import 'dart:io';

import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

/// One entry of `/proc/self/mounts`, with octal escapes already decoded.
class MountEntry {
  const MountEntry({
    required this.source,
    required this.target,
    required this.fstype,
  });

  final String source;
  final String target;
  final String fstype;
}

/// Parses the mount table. Spaces in labels/paths are written as `\040`, so
/// the fields must be decoded before they can be compared with sysfs names.
List<MountEntry> parseMountEntries(String contents) {
  final List<MountEntry> entries = <MountEntry>[];

  for (final String line in contents.split('\n')) {
    if (line.trim().isEmpty) continue;

    final List<String> fields = line.split(' ');
    if (fields.length < 3) continue;

    final String source = _decodeMountField(fields[0]);
    final String target = _decodeMountField(fields[1]);
    final String fstype = fields[2];

    if (source.isEmpty || target.isEmpty) continue;
    entries.add(MountEntry(source: source, target: target, fstype: fstype));
  }

  return entries;
}

String _decodeMountField(String value) {
  if (!value.contains(r'\')) return value;

  return value.replaceAllMapped(
    RegExp(r'\\([0-7]{3})'),
    (Match match) => String.fromCharCode(int.parse(match[1]!, radix: 8)),
  );
}

/// A block-device volume discovered through sysfs + udev.
class DetectedVolume {
  const DetectedVolume({
    required this.device,
    required this.diskDevice,
    required this.label,
    required this.fstype,
    required this.mountPoint,
    required this.removable,
  });

  final String device;
  final String diskDevice;
  final String label;
  final String fstype;
  final String? mountPoint;
  final bool removable;

  bool get mounted => mountPoint != null && mountPoint!.isNotEmpty;

  bool get hasFilesystem =>
      fstype.isNotEmpty && fstype != 'swap' && fstype != 'crypto_LUKS';
}

/// Result of an unmount/eject command, ready to be shown in a toast.
class DriveCommandResult {
  const DriveCommandResult({required this.ok, required this.message});

  final bool ok;
  final String message;
}

/// A phone/camera exposing the USB Still-Image (PTP/MTP) interface class.
///
/// Such devices carry no filesystem and never appear in `/sys/class/block`, so
/// they are outside udisks2's reach. They are browsed through gvfs instead.
class MtpDevice {
  const MtpDevice({
    required this.bus,
    required this.device,
    required this.label,
    required this.uri,
  });

  final int bus;
  final int device;
  final String label;

  /// gvfs activation URI, e.g. `mtp://[usb:003,005]/`.
  final String uri;
}

/// Whether a USB interface is the Still-Image class (0x06) capture subclass
/// (0x01) that PTP/MTP phones and cameras expose.
bool isMtpInterfaceClass(String interfaceClass, String subClass) =>
    interfaceClass == '06' && subClass == '01';

/// The gvfs activation URI for a device on [bus]/[device].
String mtpUriFor(int bus, int device) =>
    'mtp://[usb:${bus.toString().padLeft(3, '0')},'
    '${device.toString().padLeft(3, '0')}]/';

/// Turns a gvfs MTP mount-directory name (e.g. `mtp:host=Pixel_5`) into a
/// readable label, dropping the scheme and any percent-encoding.
String decodeMtpMountName(String dirName) {
  String value = dirName;
  final int host = value.indexOf('host=');
  if (host >= 0) value = value.substring(host + 5);

  try {
    value = Uri.decodeComponent(value);
  } catch (_) {}

  return value.replaceAll('_', ' ').trim();
}

/// Watches removable drives on Linux and mounts them through udisks2.
///
/// The desktop on this machine (Hyprland) has no file manager to auto-mount
/// removable media, so the explorer does it itself: mount tables and sysfs are
/// polled (cheap, in-memory reads), freshly plugged USB/SD volumes are mounted
/// with `udisksctl`, and every mounted volume is exposed as a [Place] so the
/// sidebar and directory picker can browse it.
class DriveService extends GetxService {
  DriveService({this.autoMountAllowed = true});

  static const String _autoMountSettingKey = 'auto-mount-drives';
  static const Duration _pollInterval = Duration(milliseconds: 1200);

  static bool get supported => Platform.isLinux;

  /// False for the hidden portal-backend process: it can list drives but must
  /// not mount devices behind the user's back.
  final bool autoMountAllowed;

  /// Mounted, browsable volumes (root filesystem plus removable media).
  final RxList<rust_system.Place> drives = <rust_system.Place>[].obs;

  /// Bumped when the drive list changes so open tabs can reload their places.
  final RxInt revision = 0.obs;

  final RxBool autoMount = true.obs;

  Timer? _pollTimer;
  Future<void>? _initializing;
  bool _scanning = false;
  bool _rescanRequested = false;
  bool _disposed = false;

  /// Devices already tried for auto-mount. Cleared when the device disappears,
  /// so re-plugging a stick retries once.
  final Set<String> _attempted = <String>{};
  final Set<String> _mounting = <String>{};

  final Map<String, String> _deviceByMountPath = <String, String>{};
  final Set<String> _removableMountPaths = <String>{};

  /// gvfs (MTP) state: mount path -> activation URI, and the URIs already
  /// tried for auto-mount (pruned on unplug).
  final Map<String, String> _mtpUriByMountPath = <String, String>{};
  final Set<String> _mtpAttempted = <String>{};

  int? _cachedUid;

  String? _signature;

  Future<void> init() => _initializing ??= _init();

  Future<void> _init() async {
    if (!supported) return;

    try {
      final String raw = await rust_system.getViewSetting(
        key: _autoMountSettingKey,
      );
      if (raw.isNotEmpty) autoMount.value = raw == 'true';
    } catch (_) {}

    await _scan();
    if (_disposed) return;

    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) => _requestScan(),
    );
  }

  /// Toggles auto-mount and retries currently plugged, unmounted media.
  void setAutoMount(bool value) {
    if (autoMount.value == value) return;
    autoMount.value = value;

    if (value) {
      _attempted.clear();
      _mtpAttempted.clear();
      _requestScan();
    }

    unawaited(_persistAutoMount(value));
  }

  Future<void> _persistAutoMount(bool value) async {
    try {
      await rust_system.setViewSetting(
        key: _autoMountSettingKey,
        value: '$value',
      );
    } catch (_) {}
  }

  /// Whether [mountPath] is a mounted volume that can be unmounted from the
  /// sidebar (the root filesystem is deliberately excluded).
  bool canUnmount(String mountPath) =>
      _mtpUriByMountPath.containsKey(mountPath) ||
      (mountPath != '/' && _deviceByMountPath.containsKey(mountPath));

  /// Whether the volume at [mountPath] lives on removable media. Only those
  /// expose the Eject action.
  bool isRemovable(String mountPath) =>
      _removableMountPaths.contains(mountPath);

  Future<DriveCommandResult> unmount(String mountPath) async {
    final String? mtpUri = _mtpUriByMountPath[mountPath];
    if (mtpUri != null) return _unmountMtp(mtpUri);

    final String? device = await _deviceForPath(mountPath);
    if (device == null) {
      return const DriveCommandResult(
        ok: false,
        message: 'This drive is no longer connected.',
      );
    }

    try {
      final ProcessResult result = await _runUdisks(<String>[
        'unmount',
        '-b',
        device,
        '--no-user-interaction',
      ]);
      _requestScan();
      return _resultFor(result, 'Unmounted ${p.basename(device)}.');
    } catch (error) {
      return DriveCommandResult(ok: false, message: error.toString());
    }
  }

  Future<DriveCommandResult> _unmountMtp(String uri) async {
    try {
      ProcessResult result = await _runGio(<String>['mount', '-u', uri]);
      if (result.exitCode != 0 && uri.endsWith('/')) {
        result = await _runGio(<String>[
          'mount',
          '-u',
          uri.substring(0, uri.length - 1),
        ]);
      }
      _requestScan();
      return _resultFor(result, 'Disconnected phone.');
    } catch (error) {
      return DriveCommandResult(ok: false, message: error.toString());
    }
  }

  Future<DriveCommandResult> eject(String mountPath) async {
    final String? device = await _deviceForPath(mountPath);
    if (device == null) {
      return const DriveCommandResult(
        ok: false,
        message: 'This drive is no longer connected.',
      );
    }

    final String disk = _diskDeviceFor(device);

    try {
      // A busy filesystem makes power-off fail, so unmount first. The result
      // is ignored: power-off is the authoritative step (it can also fail for
      // a device that was already unmounted).
      await _runUdisks(<String>[
        'unmount',
        '-b',
        device,
        '--no-user-interaction',
      ]);
      final ProcessResult result = await _runUdisks(<String>[
        'power-off',
        '-b',
        disk,
        '--no-user-interaction',
      ]);
      _requestScan();
      return _resultFor(result, 'Ejected ${p.basename(disk)}.');
    } catch (error) {
      return DriveCommandResult(ok: false, message: error.toString());
    }
  }

  void _requestScan() {
    if (_disposed) return;
    if (_scanning) {
      _rescanRequested = true;
      return;
    }
    unawaited(_scan());
  }

  Future<void> _scan() async {
    if (!supported || _disposed) return;
    if (_scanning) {
      _rescanRequested = true;
      return;
    }

    _scanning = true;
    try {
      final String mountTable = await File('/proc/self/mounts').readAsString();
      final List<MountEntry> mounts = parseMountEntries(mountTable);
      final Map<String, String> targets = <String, String>{
        for (final MountEntry mount in mounts) mount.source: mount.target,
      };
      final List<DetectedVolume> volumes = _readVolumes(targets);

      // Phones/cameras expose MTP, not a block device, so they are discovered
      // and mounted through gvfs instead of udisks2.
      final List<MtpDevice> mtpDevices = _readMtpDevices();
      final List<String> mtpMounts = await _readMtpMounts();

      // Forget failed attempts once the media is unplugged, so a re-plug
      // retries with a clean slate.
      final Set<String> present = <String>{
        for (final DetectedVolume volume in volumes) volume.device,
      };
      _attempted.removeWhere((String device) => !present.contains(device));

      final Set<String> presentMtp = <String>{
        for (final MtpDevice device in mtpDevices) device.uri,
      };
      _mtpAttempted.removeWhere((String uri) => !presentMtp.contains(uri));

      if (autoMountAllowed && autoMount.value) {
        final List<DetectedVolume> candidates = autoMountPlan(
          volumes: volumes,
          enabled: true,
          attempted: _attempted,
          mounting: _mounting,
        );

        for (final DetectedVolume volume in candidates) {
          _attempted.add(volume.device);
          _mounting.add(volume.device);
          unawaited(_mount(volume));
        }

        for (final MtpDevice device in mtpDevices) {
          if (_mtpAttempted.contains(device.uri)) continue;
          _mtpAttempted.add(device.uri);
          unawaited(_mountMtp(device));
        }
      }

      _publish(mounts, volumes, mtpDevices, mtpMounts);
    } catch (_) {
      // Keep the last known list on a transient read error.
    } finally {
      _scanning = false;
      if (_rescanRequested && !_disposed) {
        _rescanRequested = false;
        unawaited(_scan());
      }
    }
  }

  /// Pure decision helper: which plugged, unmounted removable volumes should
  /// be mounted now. Kept static so it can be unit-tested.
  static List<DetectedVolume> autoMountPlan({
    required List<DetectedVolume> volumes,
    required bool enabled,
    required Set<String> attempted,
    required Set<String> mounting,
  }) {
    if (!enabled) return const <DetectedVolume>[];

    return volumes
        .where(
          (DetectedVolume volume) =>
              volume.removable &&
              volume.hasFilesystem &&
              !volume.mounted &&
              !attempted.contains(volume.device) &&
              !mounting.contains(volume.device),
        )
        .toList(growable: false);
  }

  Future<void> _mount(DetectedVolume volume) async {
    try {
      final ProcessResult result = await _runUdisks(<String>[
        'mount',
        '-b',
        volume.device,
        '--no-user-interaction',
      ]);
      if (result.exitCode == 0) _requestScan();
    } catch (_) {
      // Leave it unmounted; the attempt is only retried after a re-plug.
    } finally {
      _mounting.remove(volume.device);
    }
  }

  Future<void> _mountMtp(MtpDevice device) async {
    try {
      ProcessResult result = await _runGio(<String>['mount', device.uri]);
      // gvfs accepts the activation root with or without a trailing slash
      // depending on the version; try the other spelling before giving up.
      if (result.exitCode != 0 && device.uri.endsWith('/')) {
        result = await _runGio(<String>[
          'mount',
          device.uri.substring(0, device.uri.length - 1),
        ]);
      }
      if (result.exitCode == 0) _requestScan();
    } catch (_) {
      // Phone locked, busy, or gvfs unavailable: retried after a re-plug.
    }
  }

  /// Scans sysfs for USB devices exposing the MTP/PTP interface. Cheap (a few
  /// tiny file reads) so it can run on every poll.
  List<MtpDevice> _readMtpDevices() {
    final Directory usb = Directory('/sys/bus/usb/devices');
    if (!usb.existsSync()) return const <MtpDevice>[];

    final List<MtpDevice> devices = <MtpDevice>[];
    for (final FileSystemEntity entry in usb.listSync(followLinks: false)) {
      final String name = p.basename(entry.path);
      // Composite interfaces are named `<dev>:<config>.<iface>` and root hubs
      // are named `usbN`; only the bare device dirs (`3-5`) are interesting.
      if (!name.contains('-')) continue;

      final String base = entry.path;
      final String vendor = _readText('$base/idVendor').trim();
      if (vendor.isEmpty) continue;

      final int? bus = int.tryParse(_readText('$base/busnum').trim());
      final int? device = int.tryParse(_readText('$base/devnum').trim());
      if (bus == null || device == null) continue;

      if (!_hasMtpInterface(base, name)) continue;

      final String product = _readText('$base/product').trim();
      final String manufacturer = _readText('$base/manufacturer').trim();
      final String label = product.isNotEmpty
          ? product
          : (manufacturer.isNotEmpty ? manufacturer : 'Phone');

      devices.add(
        MtpDevice(
          bus: bus,
          device: device,
          label: label,
          uri: mtpUriFor(bus, device),
        ),
      );
    }

    return devices;
  }

  bool _hasMtpInterface(String devicePath, String deviceName) {
    try {
      for (final FileSystemEntity child in Directory(
        devicePath,
      ).listSync(followLinks: false)) {
        final String iface = p.basename(child.path);
        if (!iface.startsWith('$deviceName:')) continue;

        final String cls = _readText(
          '${child.path}/bInterfaceClass',
        ).trim().toLowerCase();
        final String sub = _readText(
          '${child.path}/bInterfaceSubClass',
        ).trim().toLowerCase();
        if (isMtpInterfaceClass(cls, sub)) return true;
      }
    } catch (_) {}
    return false;
  }

  /// Directories gvfs currently exposes for active MTP mounts. These are real
  /// filesystem paths (`/run/user/<uid>/gvfs/mtp:...`) that the explorer can
  /// browse like any other folder.
  Future<List<String>> _readMtpMounts() async {
    final String? root = _gvfsRoot();
    if (root == null) return const <String>[];

    final Directory directory = Directory(root);
    if (!directory.existsSync()) return const <String>[];

    final List<String> mounts = <String>[];
    try {
      await for (final FileSystemEntity entity in directory.list(
        followLinks: false,
      )) {
        final String name = p.basename(entity.path);
        if (name.startsWith('mtp:')) mounts.add(entity.path);
      }
    } catch (_) {}
    return mounts;
  }

  String? _gvfsRoot() {
    final String? runtime = Platform.environment['XDG_RUNTIME_DIR'];
    if (runtime != null && runtime.isNotEmpty) return p.join(runtime, 'gvfs');

    final int uid = _cachedUid ??= _currentUid();
    if (uid < 0) return null;
    return '/run/user/$uid/gvfs';
  }

  int _currentUid() {
    try {
      final ProcessResult result = Process.runSync('id', <String>['-u']);
      return int.tryParse('${result.stdout}'.trim()) ?? -1;
    } catch (_) {
      return -1;
    }
  }

  MtpDevice? _matchMtpDevice(String mountPath, List<MtpDevice> devices) {
    final String normalized = decodeMtpMountName(
      p.basename(mountPath),
    ).toLowerCase();

    for (final MtpDevice device in devices) {
      if (normalized.isNotEmpty &&
          normalized.contains(device.label.toLowerCase())) {
        return device;
      }
    }

    return devices.length == 1 ? devices.single : null;
  }

  String _mtpLabel(String mountPath, List<MtpDevice> devices) {
    final MtpDevice? device = _matchMtpDevice(mountPath, devices);
    if (device != null) return device.label;

    final String decoded = decodeMtpMountName(p.basename(mountPath));
    if (decoded.isEmpty ||
        RegExp(r'^\[?usb:', caseSensitive: false).hasMatch(decoded)) {
      return 'Phone';
    }
    return decoded;
  }

  Future<ProcessResult> _runGio(List<String> arguments) {
    Future<ProcessResult> run(String executable) => Process.run(
      executable,
      arguments,
    ).timeout(const Duration(seconds: 30));

    return run('gio').catchError((Object _) async {
      for (final String candidate in const <String>[
        '/usr/bin/gio',
        '/bin/gio',
      ]) {
        if (File(candidate).existsSync()) return run(candidate);
      }
      throw const ProcessException('gio', <String>[]);
    });
  }

  List<DetectedVolume> _readVolumes(Map<String, String> targets) {
    final List<DetectedVolume> volumes = <DetectedVolume>[];
    final Directory blockDirectory = Directory('/sys/class/block');
    if (!blockDirectory.existsSync()) return volumes;

    for (final FileSystemEntity entity in blockDirectory.listSync(
      followLinks: false,
    )) {
      final String name = p.basename(entity.path);
      if (_skipBlockName(name)) continue;

      final String sys = '/sys/class/block/$name';
      final String deviceNumber = _readText('$sys/dev').trim();
      if (deviceNumber.isEmpty) continue;

      final Map<String, String> udev = _readUdevData(deviceNumber);

      // ID_FS_USAGE=filesystem is only set for mountable data volumes, which
      // filters out swap, LUKS containers and unformatted devices for free.
      if (udev['ID_FS_USAGE'] != 'filesystem') continue;

      final String fstype = udev['ID_FS_TYPE'] ?? '';
      if (fstype.isEmpty || fstype == 'swap' || fstype == 'crypto_LUKS') {
        continue;
      }

      final int sizeSectors = int.tryParse(_readText('$sys/size').trim()) ?? 0;
      if (sizeSectors <= 0) continue;

      final String device = '/dev/$name';

      volumes.add(
        DetectedVolume(
          device: device,
          diskDevice: _diskDeviceFor(device),
          label: _labelFor(name, udev),
          fstype: fstype,
          mountPoint: _mountPointFor(name, targets),
          removable: _isRemovable(name, udev),
        ),
      );
    }

    return volumes;
  }

  void _publish(
    List<MountEntry> mounts,
    List<DetectedVolume> volumes,
    List<MtpDevice> mtpDevices,
    List<String> mtpMounts,
  ) {
    final List<rust_system.Place> next = <rust_system.Place>[];
    final Map<String, String> devices = <String, String>{};
    final Set<String> removablePaths = <String>{};
    final Map<String, String> mtpUris = <String, String>{};
    final Set<String> seen = <String>{};

    MountEntry? root;
    for (final MountEntry mount in mounts) {
      if (mount.target == '/') {
        root = mount;
        break;
      }
    }

    if (root != null) {
      String label = _rootLabel();
      for (final DetectedVolume volume in volumes) {
        if (volume.device == root.source) {
          label = volume.label;
          break;
        }
      }

      next.add(
        rust_system.Place(
          label: label,
          path: '/',
          kind: rust_system.PlaceKind.drive,
        ),
      );
      seen.add('/');
    }

    // Removable media, whether mounted by us, the desktop, or manually.
    for (final DetectedVolume volume in volumes) {
      final String? mountPoint = volume.mountPoint;
      if (mountPoint == null || mountPoint == '/') continue;
      if (!volume.removable || !seen.add(mountPoint)) continue;

      next.add(
        rust_system.Place(
          label: volume.label,
          path: mountPoint,
          kind: rust_system.PlaceKind.drive,
        ),
      );
      devices[mountPoint] = volume.device;
      removablePaths.add(mountPoint);
    }

    // External mounts that sysfs/udev did not enumerate (LVM, odd buses, or a
    // manually mounted drive).
    for (final MountEntry mount in mounts) {
      if (mount.target == '/' || seen.contains(mount.target)) continue;
      if (!_isExternalMount(mount.target)) continue;
      if (!mount.source.startsWith('/dev/')) continue;
      if (_pseudoFilesystems.contains(mount.fstype)) continue;

      DetectedVolume? volume;
      for (final DetectedVolume candidate in volumes) {
        if (candidate.device == mount.source) {
          volume = candidate;
          break;
        }
      }

      final String label = volume?.label ?? p.basename(mount.target);
      next.add(
        rust_system.Place(
          label: label,
          path: mount.target,
          kind: rust_system.PlaceKind.drive,
        ),
      );
      seen.add(mount.target);
      devices[mount.target] = mount.source;
      if (volume?.removable ?? false) removablePaths.add(mount.target);
    }

    // Phones/cameras mounted through gvfs. They surface as directories under
    // the user's runtime dir and are browsed like any other local folder.
    for (final String mountPath in mtpMounts) {
      if (!seen.add(mountPath)) continue;

      next.add(
        rust_system.Place(
          label: _mtpLabel(mountPath, mtpDevices),
          path: mountPath,
          kind: rust_system.PlaceKind.drive,
        ),
      );

      final MtpDevice? device = _matchMtpDevice(mountPath, mtpDevices);
      if (device != null) mtpUris[mountPath] = device.uri;
    }

    next.sort((rust_system.Place a, rust_system.Place b) {
      final bool aRoot = a.path == '/';
      final bool bRoot = b.path == '/';
      if (aRoot != bRoot) return aRoot ? -1 : 1;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });

    _deviceByMountPath
      ..clear()
      ..addAll(devices);
    _removableMountPaths
      ..clear()
      ..addAll(removablePaths);
    _mtpUriByMountPath
      ..clear()
      ..addAll(mtpUris);

    final String signature = next
        .map((rust_system.Place place) => '${place.path}\u001f${place.label}')
        .join('\u001e');
    if (signature == _signature) return;

    _signature = signature;
    drives.assignAll(next);
    revision.value++;
  }

  String? _mountPointFor(String name, Map<String, String> targets) {
    final String device = '/dev/$name';
    final String? direct = targets[device];
    if (direct != null) return direct;

    // Some tools write a by-uuid/by-label symlink as the source.
    for (final MapEntry<String, String> entry in targets.entries) {
      if (entry.key.startsWith('/dev/') && p.basename(entry.key) == name) {
        return entry.value;
      }
    }
    return null;
  }

  bool _isRemovable(String name, Map<String, String> udev) {
    final String bus = (udev['ID_BUS'] ?? '').toLowerCase();
    if (bus == 'usb' || bus == 'mmc' || bus == 'firewire' || bus == 'ieee1394') {
      return true;
    }
    if (udev.keys.any((String key) => key.startsWith('ID_DRIVE_'))) return true;

    // Fall back to the parent disk's sysfs flag for unusual transports.
    try {
      final String resolved = Directory(
        '/sys/class/block/$name',
      ).resolveSymbolicLinksSync();
      final File flag = File(p.join(p.dirname(resolved), 'removable'));
      if (flag.existsSync() && flag.readAsStringSync().trim() == '1') {
        return true;
      }
    } catch (_) {}
    return false;
  }

  String _labelFor(String name, Map<String, String> udev) {
    final String label = (udev['ID_FS_LABEL'] ?? '').trim();
    if (label.isNotEmpty) return label;

    final String partLabel = (udev['ID_PART_ENTRY_NAME'] ?? '').trim();
    if (partLabel.isNotEmpty) return partLabel;

    final String model = (udev['ID_MODEL'] ?? '').trim();
    if (model.isNotEmpty) return model;

    return name;
  }

  String _diskDeviceFor(String device) {
    final String name = p.basename(device);
    try {
      final String resolved = Directory(
        '/sys/class/block/$name',
      ).resolveSymbolicLinksSync();
      final String parent = p.basename(p.dirname(resolved));
      if (parent.isNotEmpty && Directory('/sys/class/block/$parent').existsSync()) {
        return '/dev/$parent';
      }
    } catch (_) {}
    return device;
  }

  Future<String?> _deviceForPath(String mountPath) async {
    final String? known = _deviceByMountPath[mountPath];
    if (known != null) return known;

    try {
      final ProcessResult result = await Process.run('findmnt', <String>[
        '-n',
        '-o',
        'SOURCE',
        '--target',
        mountPath,
      ]).timeout(const Duration(seconds: 5));
      if (result.exitCode != 0) return null;

      final String source = (result.stdout as String).trim().split('\n').first;
      return source.startsWith('/dev/') ? source : null;
    } catch (_) {
      return null;
    }
  }

  Future<ProcessResult> _runUdisks(List<String> arguments) {
    Future<ProcessResult> run(String executable) => Process.run(
      executable,
      arguments,
    ).timeout(const Duration(seconds: 15));

    return run('udisksctl').catchError((Object _) async {
      // GUI processes sometimes start with a PATH that misses sbin-style
      // locations; try the absolute paths before giving up.
      for (final String candidate in const <String>[
        '/usr/bin/udisksctl',
        '/bin/udisksctl',
      ]) {
        if (File(candidate).existsSync()) return run(candidate);
      }
      throw const ProcessException('udisksctl', <String>[]);
    });
  }

  DriveCommandResult _resultFor(ProcessResult result, String successMessage) {
    if (result.exitCode == 0) {
      return DriveCommandResult(ok: true, message: successMessage);
    }

    String message = '';
    for (final String line in '${result.stderr}\n${result.stdout}'.split('\n')) {
      if (line.trim().isEmpty) continue;
      message = line.trim();
      break;
    }

    return DriveCommandResult(
      ok: false,
      message: message.isEmpty
          ? 'The operation failed with exit code ${result.exitCode}.'
          : message,
    );
  }

  static bool _skipBlockName(String name) {
    return name.startsWith('loop') ||
        name.startsWith('ram') ||
        name.startsWith('zram') ||
        name.startsWith('dm-') ||
        name.startsWith('md') ||
        name.startsWith('nbd') ||
        name.startsWith('rbd');
  }

  static bool _isExternalMount(String path) {
    return path.startsWith('/run/media/') ||
        path.startsWith('/media/') ||
        path.startsWith('/mnt/');
  }

  static const Set<String> _pseudoFilesystems = <String>{
    'proc',
    'sysfs',
    'devtmpfs',
    'devpts',
    'tmpfs',
    'cgroup',
    'cgroup2',
    'securityfs',
    'pstore',
    'autofs',
    'mqueue',
    'hugetlbfs',
    'debugfs',
    'tracefs',
    'configfs',
    'fusectl',
    'binfmt_misc',
    'efivarfs',
    'ramfs',
    'overlay',
    'squashfs',
    'rpc_pipefs',
    'nsfs',
  };

  String _rootLabel() {
    try {
      for (final String line in File('/etc/os-release').readAsLinesSync()) {
        if (!line.startsWith('ID=')) continue;
        final String id = line.substring(3).replaceAll('"', '').trim();
        if (id.isNotEmpty) return id.toLowerCase();
      }
    } catch (_) {}
    return 'Filesystem';
  }

  Map<String, String> _readUdevData(String deviceNumber) {
    final File file = File('/run/udev/data/b$deviceNumber');
    if (!file.existsSync()) return const <String, String>{};

    final Map<String, String> values = <String, String>{};
    try {
      for (final String line in file.readAsLinesSync()) {
        if (!line.startsWith('E:')) continue;
        final int equals = line.indexOf('=');
        if (equals <= 2) continue;
        values[line.substring(2, equals)] = line.substring(equals + 1);
      }
    } catch (_) {}
    return values;
  }

  String _readText(String path) {
    try {
      return File(path).readAsStringSync();
    } catch (_) {
      return '';
    }
  }

  @override
  void onClose() {
    _disposed = true;
    _pollTimer?.cancel();
    drives.close();
    revision.close();
    autoMount.close();
    super.onClose();
  }
}