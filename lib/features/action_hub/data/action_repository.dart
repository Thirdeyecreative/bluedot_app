import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/services/api_client.dart';
import '../models/event_model.dart';

final actionRepositoryProvider = Provider<ActionRepository>((ref) {
  return ActionRepository(ref.watch(apiClientProvider));
});

class ActionRepository {
  final ApiClient _api;

  ActionRepository(this._api);

  // ── Events ──────────────────────────────────────────────────────────────────

  Future<List<PlantationEvent>> fetchEvents() async {
    final data = await _api.get(ApiConfig.appEvents);
    final list = data as List<dynamic>? ?? [];
    return list.map((e) => PlantationEvent.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PlantationEvent> fetchEventById(String id) async {
    final data = await _api.get(ApiConfig.appEventDetail(id));
    return PlantationEvent.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> rsvpEvent(String eventId) async {
    final data = await _api.post(ApiConfig.appEventRsvp(eventId), body: {});
    return (data as Map<String, dynamic>?) ?? {};
  }

  Future<void> cancelRsvp(String eventId) async {
    await _api.delete(ApiConfig.appEventRsvp(eventId));
  }

  Future<Map<String, dynamic>> volunteerForEvent(String eventId) async {
    final data = await _api.post(ApiConfig.appEventVolunteer(eventId), body: {});
    return (data as Map<String, dynamic>?) ?? {};
  }

  Future<void> cancelVolunteer(String eventId) async {
    await _api.delete(ApiConfig.appEventVolunteer(eventId));
  }

  Future<Map<String, dynamic>> checkInEvent(String eventId, String token) async {
    final data = await _api.post(ApiConfig.appEventCheckin, body: {
      'event_id': eventId,
      'token': token,
    });
    return (data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> checkOutEvent(String eventId) async {
    final data = await _api.post(ApiConfig.appEventCheckout, body: {'event_id': eventId});
    return (data as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> donateForEvent(
    String eventId,
    int amount, {
    String? pan,
  }) async {
    final body = <String, dynamic>{'amount': amount};
    if (pan != null && pan.isNotEmpty) body['pan'] = pan;
    final data = await _api.post(ApiConfig.appEventDonate(eventId), body: body);
    return (data as Map<String, dynamic>?) ?? {};
  }

  // ── Site Suggestions ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> suggestSite({
    required String description,
    required double lat,
    required double lng,
    List<File> images = const [],
  }) async {
    final response = await _api.multipartPost(
      ApiConfig.suggestions,
      fields: {
        'description': description,
        'lat': lat.toString(),
        'lng': lng.toString(),
      },
      files: images,
      fileField: 'images',
    );
    return (response as Map<String, dynamic>?) ?? <String, dynamic>{};
  }
}
