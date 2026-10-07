import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/constants.dart';
import '../models/catalog.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.request});

  final PlaybackRequest request;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  AppState? _app;
  bool _busy = true;
  bool _showUi = true;
  bool _live = false;
  String? _error;
  String? _activeUrl;
  Timer? _hide;
  int _urlIndex = 0;
  List<Uri> _urls = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    WakelockPlus.enable();
    _live = widget.request.kind == MediaKind.live;
    _app = context.read<AppState>();
    final xtream = _app?.xtream;
    if (xtream == null) {
      _error = 'Sesión no disponible.';
      _busy = false;
    } else {
      _urls = xtream.playbackUrls(
        kind: widget.request.kind,
        streamId: widget.request.streamId,
        extension: widget.request.extension,
      );
      _tryPlay();
    }
  }

  Future<void> _tryPlay() async {
    if (_urlIndex >= _urls.length) {
      setState(() {
        _busy = false;
        _error = 'No se pudo reproducir (HLS y TS fallaron).';
      });
      return;
    }
    final url = _urls[_urlIndex];
    setState(() {
      _busy = true;
      _error = null;
      _activeUrl = url.toString();
    });
    await _controller?.dispose();
    final controller = VideoPlayerController.networkUrl(
      url,
      httpHeaders: const {'User-Agent': AppConstants.userAgent},
    );
    _controller = controller;
    controller.addListener(_onTick);
    try {
      await controller.initialize().timeout(AppConstants.playerInitTimeout);
      if (widget.request.startAtMs > 0 && controller.value.duration.inMilliseconds > 0) {
        await controller.seekTo(Duration(milliseconds: widget.request.startAtMs));
      }
      await controller.play();
      if (!mounted) return;
      setState(() => _busy = false);
      _scheduleHide();
    } catch (_) {
      _urlIndex += 1;
      await _tryPlay();
    }
  }

  void _onTick() {
    if (!mounted) return;
    final value = _controller?.value;
    if (value == null) return;
    if (value.hasError && !_busy) {
      _urlIndex += 1;
      _tryPlay();
      return;
    }
    setState(() {});
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _showUi = false);
      }
    });
  }

  void _toggleUi() {
    setState(() => _showUi = !_showUi);
    if (_showUi) _scheduleHide();
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    _scheduleHide();
    setState(() {});
  }

  Future<void> _saveProgress() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final req = widget.request;
    await _app?.upsertHistory(
          WatchEntry(
            key: '${req.kind.name}:${req.streamId}',
            kind: req.kind,
            streamId: req.streamId,
            title: req.title,
            posterUrl: req.posterUrl,
            positionMs: controller.value.position.inMilliseconds,
            durationMs: controller.value.duration.inMilliseconds,
            extension: req.extension,
            seriesId: req.seriesId,
            season: req.season,
            episode: req.episode,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  @override
  void dispose() {
    _hide?.cancel();
    _saveProgress();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final value = controller?.value;
    final initialized = value?.isInitialized ?? false;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.goBack): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.keyF): _FullscreenIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            _togglePlay();
            return null;
          }),
          DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) {
            Navigator.of(context).maybePop();
            return null;
          }),
          _FullscreenIntent: CallbackAction<_FullscreenIntent>(onInvoke: (_) {
            _toggleUi();
            return null;
          }),
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Focus(
            autofocus: true,
            child: GestureDetector(
              onTap: _toggleUi,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: initialized
                        ? AspectRatio(
                            aspectRatio: value!.aspectRatio == 0
                                ? 16 / 9
                                : value.aspectRatio,
                            child: VideoPlayer(controller!),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (_busy)
                    const Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  if (_error != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  if (_showUi) _buildChrome(value),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChrome(VideoPlayerValue? value) {
    final position = value?.position ?? Duration.zero;
    final duration = value?.duration ?? Duration.zero;
    final playing = value?.isPlaying ?? false;
    final volume = value?.volume ?? 1;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xDD000000),
          ],
          stops: [0, 0.22, 0.7, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    autofocus: true,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.request.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        if (_activeUrl != null)
                          Text(
                            _live
                                ? 'En vivo · ${_urlIndex == 0 ? 'HLS' : 'TS'}'
                                : _urlIndex == 0
                                    ? 'HLS'
                                    : widget.request.extension.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Column(
                children: [
                  if (!_live && duration.inMilliseconds > 0)
                    Slider(
                      value: position.inMilliseconds
                          .clamp(0, duration.inMilliseconds)
                          .toDouble(),
                      max: duration.inMilliseconds.toDouble(),
                      onChanged: (v) {
                        _controller?.seekTo(Duration(milliseconds: v.round()));
                        _scheduleHide();
                      },
                    ),
                  Row(
                    children: [
                      IconButton(
                        iconSize: 38,
                        onPressed: _togglePlay,
                        icon: Icon(
                          playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                        ),
                      ),
                      if (!_live)
                        Text(
                          '${_fmt(position)} / ${_fmt(duration)}',
                          style: const TextStyle(fontFeatures: [
                            FontFeature.tabularFigures(),
                          ]),
                        )
                      else
                        const Text(
                          '● EN VIVO',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      const Spacer(),
                      const Icon(Icons.volume_up, size: 20),
                      SizedBox(
                        width: 130,
                        child: Slider(
                          value: volume,
                          onChanged: (v) {
                            _controller?.setVolume(v);
                            _scheduleHide();
                            setState(() {});
                          },
                        ),
                      ),
                      IconButton(
                        tooltip: 'Pantalla completa',
                        onPressed: () {
                          SystemChrome.setEnabledSystemUIMode(
                            SystemUiMode.immersiveSticky,
                          );
                          SystemChrome.setPreferredOrientations(const [
                            DeviceOrientation.landscapeLeft,
                            DeviceOrientation.landscapeRight,
                          ]);
                        },
                        icon: const Icon(Icons.fullscreen),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }
}

class _FullscreenIntent extends Intent {
  const _FullscreenIntent();
}
