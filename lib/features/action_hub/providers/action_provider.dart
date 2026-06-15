import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/action_repository.dart';
import '../models/event_model.dart';

final eventsProvider = FutureProvider<List<PlantationEvent>>((ref) {
  return ref.watch(actionRepositoryProvider).fetchEvents();
});

final eventDetailProvider = FutureProvider.family<PlantationEvent, String>((ref, id) {
  return ref.watch(actionRepositoryProvider).fetchEventById(id);
});

final rsvpStateProvider = NotifierProvider<RsvpNotifier, AsyncValue<bool>>(RsvpNotifier.new);

class RsvpNotifier extends Notifier<AsyncValue<bool>> {
  @override
  AsyncValue<bool> build() => const AsyncValue.data(false);

  Future<void> rsvp(String eventId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(actionRepositoryProvider).rsvpEvent(eventId);
      return true;
    });
  }
}
