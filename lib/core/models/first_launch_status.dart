class FirstLaunchStatus {
  final bool isFirstLaunch;
  final bool needsUpdate;
  final String? error;
  final Map<String, dynamic>? existingGame;

  FirstLaunchStatus({
    required this.isFirstLaunch,
    this.needsUpdate = false,
    this.error,
    this.existingGame,
  });
}
