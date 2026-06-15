import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/api_config.dart';
import '../../../core/demo/demo_data.dart';
import '../../../core/services/api_client.dart';
import '../models/event_model.dart';

final actionRepositoryProvider = Provider<ActionRepository>((ref) {
  return ActionRepository(ref.watch(apiClientProvider));
});

class ActionRepository {
  final ApiClient _api;

  ActionRepository(this._api);

  Future<void> _demoDelay() => Future<void>.delayed(const Duration(milliseconds: 250));

  Future<List<PlantationEvent>> fetchEvents() async {
    await _demoDelay();
    return DemoData.events;
  }

  Future<PlantationEvent> fetchEventById(String id) async {
    await _demoDelay();
    return DemoData.events.firstWhere(
      (event) => event.id == id,
      orElse: () => DemoData.events.first,
    );
  }

  Future<void> rsvpEvent(String eventId) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  /// Submits a crowdsourced site suggestion as multipart form data
  /// (description + GPS coords + optional photo).
  ///
  /// Returns the API response, which includes a user-facing `message`
  /// and the XP awarded.
  Future<Map<String, dynamic>> suggestSite({
    required String description,
    required double lat,
    required double lng,
    File? image,
  }) async {
    final response = await _api.multipartPost(
      ApiConfig.suggestions,
      fields: {
        'description': description,
        'lat': lat.toString(),
        'lng': lng.toString(),
      },
      imageFile: image,
    );
    return (response as Map<String, dynamic>?) ?? <String, dynamic>{};
  }
}
