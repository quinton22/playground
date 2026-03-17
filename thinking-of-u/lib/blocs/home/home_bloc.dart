import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/match_model.dart';
import '../../models/submission_model.dart';
import '../../models/user_model.dart';
import '../../services/submission_service.dart';
import '../../services/user_service.dart';
import '../../utils/crypto_utils.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class HomeEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class HomeLoadRequested extends HomeEvent {
  final UserModel user;
  const HomeLoadRequested(this.user);
  @override
  List<Object?> get props => [user];
}

class HomePhoneAdded extends HomeEvent {
  final String targetPhone;
  const HomePhoneAdded(this.targetPhone);
  @override
  List<Object?> get props => [targetPhone];
}

class HomeTargetRemoved extends HomeEvent {
  final String targetHash;
  const HomeTargetRemoved(this.targetHash);
  @override
  List<Object?> get props => [targetHash];
}

class HomeSubmissionUpdated extends HomeEvent {
  final SubmissionModel? submission;
  const HomeSubmissionUpdated(this.submission);
  @override
  List<Object?> get props => [submission];
}

class HomeMatchesUpdated extends HomeEvent {
  final List<MatchModel> matches;
  const HomeMatchesUpdated(this.matches);
  @override
  List<Object?> get props => [matches];
}

class HomeUserUpdated extends HomeEvent {
  final UserModel user;
  const HomeUserUpdated(this.user);
  @override
  List<Object?> get props => [user];
}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class HomeState extends Equatable {
  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final UserModel user;
  final SubmissionModel? submission;
  final List<MatchModel> todaysMatches;
  final bool isAddingPhone;
  final String? errorMessage;
  final String? successMessage;

  const HomeLoaded({
    required this.user,
    this.submission,
    this.todaysMatches = const [],
    this.isAddingPhone = false,
    this.errorMessage,
    this.successMessage,
  });

  int get remainingSends => user.dailySendsRemaining;
  int get totalSent => submission?.targetHashes.length ?? 0;

  HomeLoaded copyWith({
    UserModel? user,
    SubmissionModel? submission,
    List<MatchModel>? todaysMatches,
    bool? isAddingPhone,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return HomeLoaded(
      user: user ?? this.user,
      submission: submission ?? this.submission,
      todaysMatches: todaysMatches ?? this.todaysMatches,
      isAddingPhone: isAddingPhone ?? this.isAddingPhone,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        user,
        submission,
        todaysMatches,
        isAddingPhone,
        errorMessage,
        successMessage,
      ];
}

class HomeError extends HomeState {
  final String message;
  const HomeError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final SubmissionService _submissionService;
  final UserService _userService;

  StreamSubscription? _submissionSub;
  StreamSubscription? _matchesSub;
  StreamSubscription? _userSub;

  HomeBloc({
    required SubmissionService submissionService,
    required UserService userService,
  })  : _submissionService = submissionService,
        _userService = userService,
        super(HomeInitial()) {
    on<HomeLoadRequested>(_onLoadRequested);
    on<HomePhoneAdded>(_onPhoneAdded);
    on<HomeTargetRemoved>(_onTargetRemoved);
    on<HomeSubmissionUpdated>(_onSubmissionUpdated);
    on<HomeMatchesUpdated>(_onMatchesUpdated);
    on<HomeUserUpdated>(_onUserUpdated);
  }

  Future<void> _onLoadRequested(
    HomeLoadRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(HomeLoading());

    final userHash = event.user.phoneHash;

    // Load initial data
    final submission =
        await _submissionService.getTodaysSubmission(userHash);
    final matches = <MatchModel>[];

    emit(HomeLoaded(
      user: event.user,
      submission: submission,
      todaysMatches: matches,
    ));

    // Subscribe to real-time updates
    _submissionSub?.cancel();
    _submissionSub = _submissionService
        .watchTodaysSubmission(userHash)
        .listen((sub) => add(HomeSubmissionUpdated(sub)));

    _matchesSub?.cancel();
    _matchesSub = _submissionService
        .watchTodaysMatches(userHash)
        .listen((m) => add(HomeMatchesUpdated(m)));

    _userSub?.cancel();
    _userSub = _userService
        .watchUser(userHash)
        .where((u) => u != null)
        .map((u) => u!)
        .listen((u) => add(HomeUserUpdated(u)));
  }

  Future<void> _onPhoneAdded(
    HomePhoneAdded event,
    Emitter<HomeState> emit,
  ) async {
    final current = state;
    if (current is! HomeLoaded) return;

    emit(current.copyWith(isAddingPhone: true, clearMessages: true));

    try {
      // First check if the target is a registered user
      final targetHash = CryptoUtils.hashPhoneNumber(event.targetPhone);
      final targetName = await _userService.getDisplayName(targetHash);

      if (targetName == null) {
        emit(current.copyWith(
          isAddingPhone: false,
          errorMessage:
              'This person isn\'t using Thinking of U yet. Invite them!',
        ));
        return;
      }

      final updated = await _submissionService.addTarget(
        submitterHash: current.user.phoneHash,
        targetPhone: event.targetPhone,
        maxTargets: current.user.dailyLimit,
      );

      // Decrement user's remaining sends
      await _userService.decrementDailySends(current.user.phoneHash);

      emit(current.copyWith(
        isAddingPhone: false,
        submission: updated,
        successMessage: '💌 Thinking of $targetName!',
      ));
    } catch (e) {
      emit(current.copyWith(
        isAddingPhone: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onTargetRemoved(
    HomeTargetRemoved event,
    Emitter<HomeState> emit,
  ) async {
    final current = state;
    if (current is! HomeLoaded) return;

    try {
      final updated = await _submissionService.removeTarget(
        submitterHash: current.user.phoneHash,
        targetHash: event.targetHash,
      );

      // Re-increment user's remaining sends
      // (We just update the user's remaining from the watch stream)
      emit(current.copyWith(submission: updated, clearMessages: true));
    } catch (e) {
      emit(current.copyWith(
        errorMessage: 'Could not remove. Please try again.',
      ));
    }
  }

  void _onSubmissionUpdated(
    HomeSubmissionUpdated event,
    Emitter<HomeState> emit,
  ) {
    final current = state;
    if (current is! HomeLoaded) return;
    emit(current.copyWith(submission: event.submission));
  }

  void _onMatchesUpdated(
    HomeMatchesUpdated event,
    Emitter<HomeState> emit,
  ) {
    final current = state;
    if (current is! HomeLoaded) return;
    emit(current.copyWith(todaysMatches: event.matches));
  }

  void _onUserUpdated(
    HomeUserUpdated event,
    Emitter<HomeState> emit,
  ) {
    final current = state;
    if (current is! HomeLoaded) return;
    emit(current.copyWith(user: event.user));
  }

  @override
  Future<void> close() {
    _submissionSub?.cancel();
    _matchesSub?.cancel();
    _userSub?.cancel();
    return super.close();
  }
}
