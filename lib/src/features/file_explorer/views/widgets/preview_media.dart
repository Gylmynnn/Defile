part of 'preview_panel.dart';

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.file});

  final rust.FileEntry file;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Decode at the panel's display size (2x for crispness,
              // capped) instead of the source resolution: a 24 MP photo
              // decoded raw costs ~96 MiB of bitmap that then sits in the
              // image cache long after the file is deselected.
              final double dpr = MediaQuery.devicePixelRatioOf(context);
              final double box = math.max(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              final int cacheWidth = box.isFinite
                  ? math.min((box * dpr).round(), 1024)
                  : 768;
              return Image.file(
                File(file.path),
                cacheWidth: cacheWidth,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image,
                        size: 48,
                        color: context.colors.textFaint,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load image',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.colors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MediaPreview extends StatefulWidget {
  const _MediaPreview({super.key, required this.file, required this.showVideo});

  final rust.FileEntry file;
  final bool showVideo;

  @override
  State<_MediaPreview> createState() => _MediaPreviewState();
}

/// Pooled libmpv instance shared across media previews. Building a [Player]
/// is by far the most expensive part of a video preview (native init), and
/// it currently re-runs on every switch into a media file. Parking the
/// player when a different file kind is selected — and picking it back up
/// later — keeps repeated media previews instant. The video controller
/// travels with its player (it owns the texture); recreating it per
/// selection would pile up native video outputs.
Player? _pooledPlayer;
VideoController? _pooledVideoController;
Timer? _pooledDisposeTimer;

/// A parked player holds live native mpv state (decoder, demuxer cache,
/// video output) worth tens of MB in the long-lived backend process, so it
/// is only worth keeping while another preview is likely to follow. Drop
/// it after this idle time — re-previewing then pays the native init
/// again, which is exactly the tradeoff the pool makes on purpose.
const Duration _poolIdleLifetime = Duration(seconds: 30);

Player _createConfiguredPlayer() {
  final player = Player();
  try {
    (player.platform as dynamic)?.setProperty('demuxer-max-bytes', '8388608');
    (player.platform as dynamic)?.setProperty('demuxer-max-back-bytes', '2097152');
  } catch (_) {}
  return player;
}

void releasePooledMediaPreview() {
  _pooledDisposeTimer?.cancel();
  _pooledDisposeTimer = null;
  _pooledPlayer?.dispose();
  _pooledPlayer = null;
  _pooledVideoController = null;
}

(Player, VideoController?) _takePooled() {
  _pooledDisposeTimer?.cancel();
  _pooledDisposeTimer = null;
  final Player? player = _pooledPlayer;
  final VideoController? controller = _pooledVideoController;
  _pooledPlayer = null;
  _pooledVideoController = null;
  if (player != null) return (player, controller);
  MediaKit.ensureInitialized();
  return (_createConfiguredPlayer(), null);
}

void _parkPlayer(Player player, VideoController? controller) {
  // Stop playback so the current media's demuxer cache and decoded frames
  // are unloaded immediately while the native player and texture context remain warm.
  unawaited(player.stop());

  // Single slot: one live media preview is the normal flow. With two at
  // once (split panes) the surplus player is torn down as before — its
  // controller dies with it.
  if (_pooledPlayer == null) {
    _pooledPlayer = player;
    _pooledVideoController = controller;
    _pooledDisposeTimer?.cancel();
    _pooledDisposeTimer = Timer(_poolIdleLifetime, () {
      _pooledDisposeTimer = null;
      _pooledPlayer?.dispose();
      _pooledPlayer = null;
      _pooledVideoController = null;
    });
    return;
  }
  player.dispose();
}

class _MediaPreviewState extends State<_MediaPreview> {
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<String>? _errorSubscription;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    try {
      final (player, controller) = _takePooled();
      _player = player;
      if (widget.showVideo) {
        _videoController = controller ?? VideoController(player);
      }
      _errorSubscription = player.stream.error.listen((_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = widget.showVideo
              ? 'Failed to load video'
              : 'Failed to load audio';
        });
      });
      _load();
    } catch (_) {
      _loading = false;
      _error = 'Media preview requires mpv (install mpv)';
    }
  }

  @override
  void didUpdateWidget(_MediaPreview old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path) {
      _load();
    }
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    final player = _player;
    if (player != null) _parkPlayer(player, _videoController);
    _player = null;
    _videoController = null;
    super.dispose();
  }

  Future<void> _load() async {
    final player = _player;
    if (player == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await player.open(
        Media(Uri.file(widget.file.path).toString()),
        play: false,
      );
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.showVideo
            ? 'Failed to load video'
            : 'Failed to load audio';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.showVideo ? Icons.videocam_off : Icons.audio_file_outlined,
              size: 48,
              color: context.colors.textFaint,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(fontSize: 12.5, color: context.colors.textFaint),
            ),
          ],
        ),
      );
    }

    final player = _player;
    if (player == null) {
      return const SizedBox.shrink();
    }

    final videoController = _videoController;
    if (widget.showVideo && videoController == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Expanded(
          child: widget.showVideo
              ? Video(
                  controller: videoController!,
                  controls: NoVideoControls,
                  fit: BoxFit.contain,
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          color: context.colors.elevated,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: context.colors.elevatedBorder,
                          ),
                        ),
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          size: 46,
                          color: context.colors.accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          widget.file.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 10),
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border(top: BorderSide(color: context.colors.divider)),
          ),
          child: Row(
            children: [
              StreamBuilder<bool>(
                stream: player.stream.playing,
                builder: (context, snapshot) {
                  final playing = snapshot.data == true;

                  return Tooltip(
                    message: playing ? 'Pause' : 'Play',
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.colors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: context.colors.accent.withValues(alpha: 0.28),
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        iconSize: 21,
                        color: context.colors.accent,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 38,
                          height: 38,
                        ),
                        style: IconButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(9)),
                          ),
                        ),
                        onPressed: player.playOrPause,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: player.stream.position,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;

                    return StreamBuilder<Duration>(
                      stream: player.stream.duration,
                      builder: (context, durationSnapshot) {
                        final duration = durationSnapshot.data ?? Duration.zero;
                        final maxMs = duration.inMilliseconds > 0
                            ? duration.inMilliseconds
                            : 1;
                        final value = position.inMilliseconds
                            .clamp(0, maxMs)
                            .toDouble();

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 22,
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3,
                                  activeTrackColor: context.colors.accent,
                                  inactiveTrackColor: context.colors.elevated,
                                  thumbColor: context.colors.textStrong,
                                  overlayColor: context.colors.accent
                                      .withValues(alpha: 0.12),
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 5,
                                    elevation: 0,
                                    pressedElevation: 0,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 11,
                                  ),
                                  trackShape:
                                      const RoundedRectSliderTrackShape(),
                                  tickMarkShape: SliderTickMarkShape.noTickMark,
                                  showValueIndicator: ShowValueIndicator.never,
                                ),
                                child: Slider(
                                  value: value,
                                  max: maxMs.toDouble(),
                                  padding: EdgeInsets.zero,
                                  onChanged: (next) => player.seek(
                                    Duration(milliseconds: next.round()),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: context.colors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: context.colors.textFaint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
