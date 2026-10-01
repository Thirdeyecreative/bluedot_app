import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';
import '../models/banner_model.dart';

class _VideoResource {
  final Player player;
  final VideoController controller;
  bool isReady = false;
  _VideoResource(this.player, this.controller);
}

/// Auto-rotating promo carousel (image / GIF / video) for the home screen.
///
/// Design principles:
///   * The widget asks the model questions (`isVideo`, `isTappable`, ...);
///     it never parses raw fields.
///   * Media-aware timing: images/GIFs use a fixed interval, videos advance on
///     natural completion, and an admin `durationSeconds` override always wins.
///   * Respect device decoder limits: at most three live [Player]s
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
  final Map<int, _VideoResource> _videoResources = {};
  Timer? _rotateTimer;
  int _currentPage = 0;

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
    for (final res in _videoResources.values) {
      res.player.dispose();
    }
    _videoResources.clear();
  }

  // --- Orchestration core -------------------------------------------------

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
    final stale = _videoResources.keys.where((k) => !window.contains(k)).toList();
    for (final k in stale) {
      _videoResources.remove(k)?.player.dispose();
    }

    // (2) Pre-initialize the visible + adjacent videos.
    for (final i in window) {
      _ensureVideo(i);
    }

    // (3) Play the visible video; pause + rewind the neighbours.
    for (final entry in _videoResources.entries) {
      final res = entry.value;
      if (!res.isReady) continue;
      if (entry.key == page) {
        res.player.play();
      } else {
        res.player.pause();
        res.player.seek(Duration.zero);
      }
    }

    // (4) Arm the media-aware auto-rotate timer.
    _armTimer(page);

    if (mounted) setState(() {});
  }

  Future<void> _ensureVideo(int index) async {
    if (_videoResources.containsKey(index)) return;
    final banner = widget.banners[index];
    
    final player = Player();
    final controller = VideoController(player);
    final res = _VideoResource(player, controller);
    _videoResources[index] = res;

    try {
      await player.setVolume(0.0);
      await player.setPlaylistMode(_shouldLoop(banner) ? PlaylistMode.single : PlaylistMode.none);

      player.stream.completed.listen((completed) {
        if (completed) _onVideoTick(index);
      });

      await player.open(Media(banner.mediaUrl), play: index == _currentPage);

      if (!mounted || _isDisposed || _videoResources[index] != res) {
        player.dispose();
        return;
      }

      res.isReady = true;
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted || _isDisposed) return;
      if (_videoResources[index] == res) {
        _videoResources.remove(index);
        player.dispose();
      }
      if (index == _currentPage && _isCarousel && _rotateTimer == null) {
        _rotateTimer = Timer(_gifFallback, _advance);
      }
    }
  }

  bool _shouldLoop(AppBanner b) => !_isCarousel || b.durationSeconds != null;

  void _onVideoTick(int index) {
    if (!mounted || _isDisposed || index != _currentPage) return;
    final banner = widget.banners[index];
    if (banner.durationSeconds != null) return; // timer owns advancement
    _advance();
  }

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
      interval = _gifFallback; 
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
      final res = _videoResources[index];
      final ready = res != null && res.isReady;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: ready
            ? SizedBox.expand(
                key: ValueKey('video-$index'),
                child: Video(
                  controller: res.controller,
                  controls: NoVideoControls, // No playback controls on promo banners
                  fit: BoxFit.cover,
                  fill: Colors.transparent,
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
