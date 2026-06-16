import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/action_repository.dart';
import '../models/event_model.dart';

// ── Event list ────────────────────────────────────────────────────────────────

final eventsProvider = FutureProvider<List<PlantationEvent>>((ref) {
  return ref.watch(actionRepositoryProvider).fetchEvents();
});

final eventDetailProvider = FutureProvider.family<PlantationEvent, String>((ref, id) {
  return ref.watch(actionRepositoryProvider).fetchEventById(id);
});

// ── RSVP notifier ─────────────────────────────────────────────────────────────
// Non-family: event ID is passed through methods. Seeded from eventDetailProvider on page load.

final rsvpStateProvider =
    NotifierProvider<RsvpNotifier, AsyncValue<bool>>(RsvpNotifier.new);

class RsvpNotifier extends Notifier<AsyncValue<bool>> {
  @override
  AsyncValue<bool> build() => const AsyncValue.data(false);

  void seed(bool isRsvped) {
    state = AsyncValue.data(isRsvped);
  }

  Future<void> toggle(String eventId) async {
    final current = switch (state) { AsyncData(:final value) => value, _ => false };
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(actionRepositoryProvider);
      if (current) {
        await repo.cancelRsvp(eventId);
        return false;
      } else {
        await repo.rsvpEvent(eventId);
        return true;
      }
    });
    ref.invalidate(eventDetailProvider(eventId));
  }
}

// ── Volunteer notifier ────────────────────────────────────────────────────────

final volunteerStateProvider =
    NotifierProvider<VolunteerNotifier, AsyncValue<bool>>(VolunteerNotifier.new);

class VolunteerNotifier extends Notifier<AsyncValue<bool>> {
  @override
  AsyncValue<bool> build() => const AsyncValue.data(false);

  void seed(bool isVolunteered) {
    state = AsyncValue.data(isVolunteered);
  }

  Future<void> toggle(String eventId) async {
    final current = switch (state) { AsyncData(:final value) => value, _ => false };
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(actionRepositoryProvider);
      if (current) {
        await repo.cancelVolunteer(eventId);
        return false;
      } else {
        await repo.volunteerForEvent(eventId);
        // Volunteering cancels any attendee RSVP — sync that state too
        ref.read(rsvpStateProvider.notifier).seed(false);
        return true;
      }
    });
    ref.invalidate(eventDetailProvider(eventId));
  }
}

// ── Check-in notifier ─────────────────────────────────────────────────────────

class CheckInResult {
  final String role;
  final int xpAwarded;
  final String message;
  const CheckInResult({required this.role, required this.xpAwarded, required this.message});
}

final checkInProvider =
    NotifierProvider<CheckInNotifier, AsyncValue<CheckInResult?>>(CheckInNotifier.new);

class CheckInNotifier extends Notifier<AsyncValue<CheckInResult?>> {
  @override
  AsyncValue<CheckInResult?> build() => const AsyncValue.data(null);

  Future<void> checkIn(String eventId, String token) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final data = await ref.read(actionRepositoryProvider).checkInEvent(eventId, token);
      return CheckInResult(
        role: data['role'] as String? ?? 'Attendee',
        xpAwarded: data['xp_awarded'] as int? ?? 0,
        message: data['message'] as String? ?? 'Checked in!',
      );
    });
    ref.invalidate(eventDetailProvider(eventId));
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

// ── Check-out notifier ────────────────────────────────────────────────────────

class CheckOutResult {
  final String role;
  final int durationMinutes;
  final String message;
  const CheckOutResult({required this.role, required this.durationMinutes, required this.message});
}

final checkOutProvider =
    NotifierProvider<CheckOutNotifier, AsyncValue<CheckOutResult?>>(CheckOutNotifier.new);

class CheckOutNotifier extends Notifier<AsyncValue<CheckOutResult?>> {
  @override
  AsyncValue<CheckOutResult?> build() => const AsyncValue.data(null);

  Future<void> checkOut(String eventId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final data = await ref.read(actionRepositoryProvider).checkOutEvent(eventId);
      return CheckOutResult(
        role: data['role'] as String? ?? 'Attendee',
        durationMinutes: data['duration_minutes'] as int? ?? 0,
        message: data['message'] as String? ?? 'Checked out!',
      );
    });
    ref.invalidate(eventDetailProvider(eventId));
  }

  void reset() => state = const AsyncValue.data(null);
}
