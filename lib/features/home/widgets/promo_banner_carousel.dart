import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';
import '../models/banner_model.dart';

/// Auto-rotating promo carousel (image / GIF / video) for the home screen.
///
/// Design principles (mirrors the PassiTon promo banner):
///   * The widget asks the model questions (`isVideo`, `isTappable`, ...);
///     it never parses raw fields.
///   * Media-aware timing: images/GIFs use a fixed interval, videos advance on
///     natural completion, and an admin `durationSeconds` override always wins.
///   * Respect device decoder limits: at most three live [VideoPlayerController]s
///     (a sliding window of the current page and its neighbours).
///   * Fail soft: broken media keeps the carousel rotating; a tap error shows a
///     snackbar, never a crash.
class PromoBannerCarousel extends StatefulWidget {
  final List<AppBanner> banners;

  const PromoBannerCarousel({super.key, required this.banners});

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  static const _imageInterval = Duration(seconds: 4);
  static const _gifFallback = Duration(seconds: 5);

  late final PageController _pageController;
  final Map<int, VideoPlayerController> _videoControllers = {};
  Timer? _rotateTimer;
  int _currentPage = 0;

  /// Gotcha #1: guards every async video-init continuation so a late
  /// completion after disposal/teardown is a no-op, never a crash.
  bool _isDisposed = false;

  bool get _isCarousel => widget.banners.length > 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) _syncForPage(0);
    });
  }

  @override
  void didUpdateWidget(covariant PromoBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A genuinely different banner set (e.g. pull-to-refresh) -> full reset.
    if (!_sameOrder(oldWidget.banners, widget.banners)) {
      _rotateTimer?.cancel();
      _rotateTimer = null;
      _disposeAllVideos();
      _currentPage = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) _syncForPage(0);
      });
      setState(() {});
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _rotateTimer?.cancel();
    _disposeAllVideos();
    _pageController.dispose();
    super.dispose();
  }

  bool _sameOrder(List<AppBanner> a, List<AppBanner> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].mediaUrl != b[i].mediaUrl) return false;
    }
    return true;
  }

  void _disposeAllVideos() {
    for (final c in _videoControllers.values) {
      c.dispose();
    }
    _videoControllers.clear();
  }

  // --- Orchestration core -------------------------------------------------

  /// Reconciles all state for the page that just became visible:
  /// (1) keep video decoders only for {page-1, page, page+1};
  /// (2) pre-initialize the window's videos;
  /// (3) play the visible video, pause + rewind neighbours;
  /// (4) arm the auto-rotate timer (cancelling any in-flight timer first).
  void _syncForPage(int page) {
    if (_isDisposed) return;
    _currentPage = page;

    // (1) Decoder safety: dispose any video controller outside the window.
    final window = <int>{};
    for (final i in [page - 1, page, page + 1]) {
      if (i >= 0 && i < widget.banners.length && widget.banners[i].isVideo) {
        window.add(i);
      }
    }
    final stale =
        _videoControllers.keys.where((k) => !window.contains(k)).toList();
    for (final k in stale) {
      _videoControllers.remove(k)?.dispose();
    }

    // (2) Pre-initialize the visible + adjacent videos.
    for (final i in window) {
      _ensureVideo(i);
    }

    // (3) Play the visible video; pause + rewind the neighbours.
    for (final entry in _videoControllers.entries) {
      final c = entry.value;
      if (!c.value.isInitialized) continue;
      if (entry.key == page) {
        c.play();
      } else {
        c.pause();
        c.seekTo(Duration.zero);
      }
    }

    // (4) Arm the media-aware auto-rotate timer.
    _armTimer(page);

    if (mounted) setState(() {});
  }

  void _ensureVideo(int index) {
    if (_videoControllers.containsKey(index)) return;
    final banner = widget.banners[index];
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(banner.mediaUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _videoControllers[index] = controller;

    controller.initialize().then((_) {
      // Gotcha #1: the widget may have been disposed, or this controller may
      // have been superseded (and already disposed) by a fast swipe, while
      // initialize() was in flight.
      if (!mounted || _isDisposed) return;
      if (_videoControllers[index] != controller) return;
      controller.setVolume(0); // muted: never steal audio focus
      controller.setLooping(_shouldLoop(banner));
      controller.addListener(() => _onVideoTick(index, controller));
      if (index == _currentPage) controller.play();
      setState(() {});
    }).catchError((Object _) {
      if (!mounted || _isDisposed) return;
      // Fail soft: drop the broken controller and keep the carousel moving.
      if (_videoControllers[index] == controller) {
        _videoControllers.remove(index);
        controller.dispose();
      }
      if (index == _currentPage && _isCarousel && _rotateTimer == null) {
        _rotateTimer = Timer(_gifFallback, _advance);
      }
    });
  }

  /// Loop only a lone video or an admin-fixed-duration video; in a multi-banner
  /// carousel a video plays once and then advances.
  bool _shouldLoop(AppBanner b) => !_isCarousel || b.durationSeconds != null;

  /// Advance a finished video (only when it owns its own timing).
  void _onVideoTick(int index, VideoPlayerController c) {
    if (!mounted || _isDisposed || index != _currentPage) return;
    final banner = widget.banners[index];
    if (banner.durationSeconds != null) return; // timer owns advancement
    final v = c.value;
    if (v.isInitialized &&
        !v.isLooping &&
        v.duration > Duration.zero &&
        v.position >= v.duration) {
      _advance();
    }
  }

  /// Media-aware advance precedence: admin override > video completion >
  /// fixed GIF interval > fixed image interval.
  void _armTimer(int page) {
    _rotateTimer?.cancel();
    _rotateTimer = null;
    if (!_isCarousel) return;

    final banner = widget.banners[page];
    Duration? interval;
    if (banner.durationSeconds != null) {
      interval = Duration(seconds: banner.durationSeconds!);
    } else if (banner.isVideo) {
      interval = null; // advances on natural completion (_onVideoTick)
    } else if (banner.isGif) {
      interval = _gifFallback; // Gotcha #2: fixed, no main-thread frame summing
    } else {
      interval = _imageInterval;
    }

    if (interval != null) {
      _rotateTimer = Timer(interval, _advance);
    }
  }

  void _advance() {
    if (!mounted || _isDisposed || !_isCarousel) return;
    final next = (_currentPage + 1) % widget.banners.length;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  // --- Tap routing --------------------------------------------------------

  Future<void> _onTap(AppBanner banner) async {
    try {
      if (banner.isRoute) {
        context.push(banner.actionTarget!);
      } else if (banner.isScan) {
        context.push('/scanner');
      } else if (banner.actionType == 'link' && banner.hasLink) {
        final ok = await launchUrl(
          Uri.parse(banner.linkUrl!),
          mode: LaunchMode.externalApplication,
        );
        if (!ok && mounted) {
          AppFeedback.showError(context, 'Could not open the link.');
        }
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e);
    }
  }

  // --- Rendering ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: AspectRatio(
        aspectRatio: 2.0, // matches the 1080x540 admin preview
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: _isCarousel ? _buildCarousel() : _buildPage(0),
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.banners.length,
          onPageChanged: _syncForPage,
          itemBuilder: (_, i) => _buildPage(i),
        ),
        _buildDots(),
      ],
    );
  }

  Widget _buildPage(int index) {
    final banner = widget.banners[index];
    final media = _buildMedia(banner, index);
    if (!banner.isTappable) return media;
    return GestureDetector(
      onTap: () => _onTap(banner),
      child: media,
    );
  }

  Widget _buildMedia(AppBanner banner, int index) {
    if (banner.isVideo) {
      final c = _videoControllers[index];
      final ready = c != null && c.value.isInitialized;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: ready
            ? FittedBox(
                key: ValueKey('video-$index'),
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              )
            : _placeholder(key: ValueKey('video-ph-$index')),
      );
    }
    // Image and GIF both go through CachedNetworkImage (GIFs animate natively).
    return CachedNetworkImage(
      imageUrl: banner.mediaUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, _) => _placeholder(),
      errorWidget: (_, _, _) => _errorTile(),
    );
  }

  Widget _placeholder({Key? key}) =>
      Container(key: key, color: AppColors.borderLight);

  Widget _errorTile() => Container(
        color: AppColors.primaryBlue.withAlpha(30),
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: AppColors.primaryBlue.withAlpha(120),
          ),
        ),
      );

  Widget _buildDots() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.banners.length, (i) {
          final active = i == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(active ? 235 : 120),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
            ),
          );
        }),
      ),
    );
  }
}
