class ModModel {
  final String id;
  final String name;
  final String version;
  final String description;
  final String author;
  final bool enabled;
  final String fileName;
  final int fileSize;
  final String dateInstalled;
  final String? curseForgeId;
  final String? curseForgeFileId;
  final bool missing;

  ModModel({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.author,
    required this.enabled,
    required this.fileName,
    required this.fileSize,
    required this.dateInstalled,
    this.curseForgeId,
    this.curseForgeFileId,
    required this.missing,
  });

  factory ModModel.fromJson(Map<String, dynamic> json) {
    return ModModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Mod',
      version: json['version'] ?? '1.0.0',
      description: json['description'] ?? '',
      author: json['author'] ?? 'Unknown',
      enabled: json['enabled'] ?? true,
      fileName: json['fileName'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      dateInstalled: json['dateInstalled'] ?? '',
      curseForgeId: json['curseForgeId'],
      curseForgeFileId: json['curseForgeFileId'],
      missing: json['missing'] ?? false,
    );
  }
}
