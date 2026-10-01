import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../constants/app_colors.dart';

/// Returns true if the URL points to a video file (mp4 or webm).
bool _isVideoUrl(String url) {
  final lower = url.toLowerCase();
  return lower.endsWith('.mp4') || lower.endsWith('.webm');
}

/// A swipeable media carousel that displays a list of image and video URLs.
class MediaCarousel extends StatefulWidget {
  final List<String> mediaUrls;
  final double height;
  final BorderRadius? borderRadius;
  /// If false, video slides start paused.
  final bool autoPlayVideo;
  /// If true, automatically advances to the next slide.
  final bool autoAdvance;
  /// If false, videos are NOT initialized and only show a placeholder. Perfect for list feeds to prevent hardware decoder overload.
  final bool allowVideoInitialization;

  const MediaCarousel({
    super.key,
    required this.mediaUrls,
    this.height = 240,
    this.borderRadius,
    this.autoPlayVideo = true,
    this.autoAdvance = true,
    this.allowVideoInitialization = true,
  });

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.autoAdvance) {
      _startTimerIfNeeded();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    if (!widget.autoAdvance || widget.mediaUrls.length <= 1) return;

    final currentUrl = widget.mediaUrls[_currentIndex];
    if (!_isVideoUrl(currentUrl)) {
      // It's an image, auto-advance after 5 seconds
      _timer = Timer(const Duration(seconds: 5), _advanceToNextSlide);
    }
    // If it's a video, the _VideoSlide will call _advanceToNextSlide via callback when it finishes.
  }

  void _advanceToNextSlide() {
    if (!mounted || widget.mediaUrls.length <= 1) return;

    final nextIndex = (_currentIndex + 1) % widget.mediaUrls.length;
    _pageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.mediaUrls;

    if (urls.isEmpty) {
      return _FallbackPlaceholder(height: widget.height, borderRadius: widget.borderRadius);
    }

    // Single item — skip PageView overhead
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: _isVideoUrl(urls.first)
              ? _VideoSlide(
                  url: urls.first,
                  isVisible: true,
                  autoPlay: widget.autoPlayVideo,
                  allowVideoInitialization: widget.allowVideoInitialization,
                )
              : _ImageSlide(url: urls.first),
        ),
      );
    }

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: urls.length,
              onPageChanged: (i) {
                setState(() => _currentIndex = i);
                if (widget.autoAdvance) {
                  _startTimerIfNeeded();
                }
              },
              itemBuilder: (_, i) {
                final url = urls[i];
                if (_isVideoUrl(url)) {
                  return _VideoSlide(
                    url: url,
                    isVisible: _currentIndex == i,
                    autoPlay: widget.autoPlayVideo,
                    onVideoFinished: widget.autoAdvance ? _advanceToNextSlide : null,
                    allowVideoInitialization: widget.allowVideoInitialization,
                  );
                }
                return _ImageSlide(url: url);
              },
            ),
            // Dot indicator
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(urls.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentIndex == i ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentIndex == i
                          ? Colors.white
                          : Colors.white.withAlpha(120),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Image slide ─────────────────────────────────────────────────────────────

class _ImageSlide extends StatelessWidget {
  final String url;
  const _ImageSlide({required this.url});

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, _) => Container(color: AppColors.borderLight),
        errorWidget: (_, _, _) => Container(
          color: AppColors.primaryBlue.withAlpha(15),
          child: const Center(
            child: Icon(Icons.broken_image_rounded, color: AppColors.textLight, size: 32),
          ),
        ),
      );
}

// ── Video slide ─────────────────────────────────────────────────────────────

class _VideoSlide extends StatefulWidget {
  final String url;
  final bool isVisible;
  final bool autoPlay;
  final bool allowVideoInitialization;
  final VoidCallback? onVideoFinished;
  const _VideoSlide({
    required this.url,
    required this.isVisible,
    this.autoPlay = true,
    this.allowVideoInitialization = true,
    this.onVideoFinished,
  });

  @override
  State<_VideoSlide> createState() => _VideoSlideState();
}

class _VideoSlideState extends State<_VideoSlide> {
  Player? _player;
  VideoController? _videoController;
  bool _hasError = false;
  bool _hasFinished = false;
  int _initId = 0;
  StreamSubscription? _completedSub;

  @override
  void initState() {
    super.initState();
    if (widget.isVisible && widget.allowVideoInitialization) _initVideo();
  }

  @override
  void didUpdateWidget(covariant _VideoSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible && widget.allowVideoInitialization) {
      _initVideo();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _disposeVideo();
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  Future<void> _initVideo() async {
    if (!widget.allowVideoInitialization || _player != null) return;
    _hasError = false;
    _hasFinished = false;
    
    final myInitId = ++_initId;

    try {
      final player = Player();
      final controller = VideoController(player);

      if (!mounted || _initId != myInitId || !widget.isVisible) {
        player.dispose();
        return;
      }
      
      _player = player;
      _videoController = controller;

      // Start muted for respectful UX
      await player.setVolume(0.0);
      
      // If we have a callback to switch slides, don't loop. Otherwise, loop.
      await player.setPlaylistMode(widget.onVideoFinished == null ? PlaylistMode.single : PlaylistMode.none);

      // Listen for video end
      _completedSub = player.stream.completed.listen((completed) {
        if (completed && widget.onVideoFinished != null && !_hasFinished) {
          _hasFinished = true;
          widget.onVideoFinished!();
        }
      });

      // Handle errors
      player.stream.error.listen((error) {
        debugPrint('MediaCarousel media_kit error: $error');
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      });

      await player.open(Media(widget.url), play: widget.autoPlay);
      
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('MediaCarousel: media_kit Video init failed for ${widget.url}: $e');
      _disposeVideo();
      if (mounted) setState(() { _hasError = true; });
    }
  }

  void _disposeVideo() {
    _initId++; // Invalidate any pending initializations
    _completedSub?.cancel();
    _completedSub = null;
    _player?.dispose();
    _player = null;
    _videoController = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.allowVideoInitialization) {
      return Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(
          child: Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 48),
        ),
      );
    }

    if (_hasError) {
      return Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 32),
              SizedBox(height: 6),
              Text('Video unavailable', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_videoController == null) {
      return Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: Colors.white54,
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Video(
        controller: _videoController!,
        controls: MaterialVideoControls,
        fill: Colors.transparent,
      ),
    );
  }
}

// ── Fallback placeholder ────────────────────────────────────────────────────

class _FallbackPlaceholder extends StatelessWidget {
  final double height;
  final BorderRadius? borderRadius;
  const _FallbackPlaceholder({required this.height, this.borderRadius});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: Container(
          height: height,
          width: double.infinity,
          color: AppColors.primaryBlue.withAlpha(15),
          child: const Center(
            child: Icon(Icons.photo_library_rounded, color: AppColors.primaryBlue, size: 44),
          ),
        ),
      );
}
