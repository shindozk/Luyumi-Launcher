class VersionInfo {
  final String latestVersion;
  final String? downloadUrl;
  final String? formattedVersion;

  VersionInfo({
    required this.latestVersion,
    this.downloadUrl,
    this.formattedVersion,
  });
}
