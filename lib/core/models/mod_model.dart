class ModModel {
  final String id;
  final String name;
  final String version;
  final String description;
  final String summary;
  final String author;
  final bool enabled;
  final String fileName;
  final int fileSize;
  final String dateInstalled;
  final String? curseForgeId;
  final String? curseForgeFileId;
  final bool missing;
  final String? logoUrl;
  final int downloadCount;
  final List<String> categories;

  ModModel({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    this.summary = '',
    required this.author,
    required this.enabled,
    required this.fileName,
    required this.fileSize,
    required this.dateInstalled,
    this.curseForgeId,
    this.curseForgeFileId,
    required this.missing,
    this.logoUrl,
    this.downloadCount = 0,
    this.categories = const [],
  });

  factory ModModel.fromJson(Map<String, dynamic> json) {
    final cfId = (json['curseForgeId'] ?? json['id'])?.toString();

    return ModModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown Mod',
      version: json['version'] ?? '1.0.0',
      description: json['description'] ?? '',
      summary: json['summary'] ?? '',
      author:
          json['author'] ??
          ((json['authors'] as List?)?.isNotEmpty == true
              ? json['authors']![0]['name']
              : 'Unknown'),
      enabled: json['enabled'] ?? true,
      fileName: json['fileName'] ?? '',
      fileSize:
          json['fileSize'] ??
          (json['latestFiles'] != null &&
                  (json['latestFiles'] as List).isNotEmpty
              ? json['latestFiles'][0]['fileLength']
              : 0),
      dateInstalled: json['dateInstalled'] ?? '',
      curseForgeId: cfId,
      curseForgeFileId:
          json['curseForgeFileId']?.toString() ??
          (json['latestFiles'] != null &&
                  (json['latestFiles'] as List).isNotEmpty
              ? json['latestFiles'][0]['id']?.toString()
              : null),
      missing: json['missing'] ?? false,
      logoUrl:
          json['logoUrl'] ??
          json['logo']?['thumbnailUrl'] ??
          json['logo']?['url'],
      downloadCount: json['downloadCount'] ?? 0,
      categories:
          (json['categories'] as List?)
              ?.map((c) => (c is Map ? (c['name'] ?? c['id']) : c).toString())
              .toList() ??
          [],
    );
  }
}
