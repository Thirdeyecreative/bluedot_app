import 'package:flutter_test/flutter_test.dart';
import 'package:bluedot_app/features/home/models/banner_model.dart';

void main() {
  group('AppBanner campaign redirection tests', () {
    test('Campaign action with linked_campaign_id produces correct route', () {
      final banner = AppBanner.fromJson({
        'id': 'banner-1',
        'media_url': 'https://example.com/banner.jpg',
        'action_type': 'campaign',
        'linked_campaign_id': '550e8400-e29b-41d4-a716-446655440000',
      });

      expect(banner.isCampaign, isTrue);
      expect(banner.isRoute, isTrue);
      expect(banner.isTappable, isTrue);
      expect(banner.effectiveActionTarget,
          equals('/action-hub/campaign/550e8400-e29b-41d4-a716-446655440000'));
    });

    test('Campaign action with action_target already formatted', () {
      final banner = AppBanner.fromJson({
        'id': 'banner-2',
        'media_url': 'https://example.com/banner.jpg',
        'action_type': 'campaign',
        'action_target': '/action-hub/campaign/custom-campaign-id',
      });

      expect(banner.isCampaign, isTrue);
      expect(banner.isRoute, isTrue);
      expect(banner.isTappable, isTrue);
      expect(banner.effectiveActionTarget,
          equals('/action-hub/campaign/custom-campaign-id'));
    });

    test('Banner with linked_campaign_id even if action_type is missing/none', () {
      final banner = AppBanner.fromJson({
        'id': 'banner-3',
        'media_url': 'https://example.com/banner.jpg',
        'action_type': 'none',
        'linked_campaign_id': 'campaign-xyz',
      });

      expect(banner.isCampaign, isTrue);
      expect(banner.isRoute, isTrue);
      expect(banner.isTappable, isTrue);
      expect(banner.effectiveActionTarget,
          equals('/action-hub/campaign/campaign-xyz'));
    });

    test('Standard route banner works as expected', () {
      final banner = AppBanner.fromJson({
        'id': 'banner-4',
        'media_url': 'https://example.com/banner.jpg',
        'action_type': 'route',
        'action_target': '/map',
      });

      expect(banner.isCampaign, isFalse);
      expect(banner.isRoute, isTrue);
      expect(banner.isTappable, isTrue);
      expect(banner.effectiveActionTarget, equals('/map'));
    });

    test('Link banner works as expected', () {
      final banner = AppBanner.fromJson({
        'id': 'banner-5',
        'media_url': 'https://example.com/banner.jpg',
        'action_type': 'link',
        'link_url': 'https://bluedot.eco',
      });

      expect(banner.actionType, equals('link'));
      expect(banner.hasLink, isTrue);
      expect(banner.isRoute, isFalse);
      expect(banner.isTappable, isTrue);
    });

    test('Display-only banner (none) is not tappable', () {
      final banner = AppBanner.fromJson({
        'id': 'banner-6',
        'media_url': 'https://example.com/banner.jpg',
        'action_type': 'none',
      });

      expect(banner.isTappable, isFalse);
      expect(banner.isRoute, isFalse);
    });
  });
}
