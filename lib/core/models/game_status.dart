class GameStatus {
  final bool installed;
  final bool fullyExtracted;
  final bool corrupted;
  final List<String> reasons;
  final String? gameDir;
  final String? clientPath;
  final int? clientSize; // Bytes - se null, não conseguiu detectar
  final bool updateAvailable;
  final String latestVersion;
  final String? installedVersion;
  final GameStatusDetails? details;

  GameStatus({
    required this.installed,
    this.fullyExtracted = false,
    required this.corrupted,
    required this.reasons,
    this.gameDir,
    this.clientPath,
    this.clientSize,
    this.updateAvailable = false,
    this.latestVersion = "1.0.0",
    this.installedVersion,
    this.details,
  });

  /// Factory constructor para JSON da API backend
  factory GameStatus.fromJson(Map<String, dynamic> json) {
    return GameStatus(
      installed: json['installed'] ?? false,
      fullyExtracted: json['fullyExtracted'] ?? false,
      corrupted: json['corrupted'] ?? false,
      reasons: List<String>.from(json['reasons'] ?? []),
      gameDir: json['gameDir'],
      clientPath: json['clientPath'],
      clientSize: json['clientSize'],
      updateAvailable: json['updateAvailable'] ?? false,
      latestVersion: json['latestVersion'] ?? '1.0.0',
      installedVersion: json['installedVersion'],
      details: json['details'] != null
          ? GameStatusDetails.fromJson(json['details'])
          : null,
    );
  }

  /// Converter para JSON (se necessário enviar para backend)
  Map<String, dynamic> toJson() {
    return {
      'installed': installed,
      'fullyExtracted': fullyExtracted,
      'corrupted': corrupted,
      'reasons': reasons,
      'gameDir': gameDir,
      'clientPath': clientPath,
      'clientSize': clientSize,
      'updateAvailable': updateAvailable,
      'latestVersion': latestVersion,
      'installedVersion': installedVersion,
      'details': details?.toJson(),
    };
  }

  /// Helper: Formatar tamanho do cliente para exibição
  String get clientSizeFormatted {
    if (clientSize == null) return 'Unknown';
    final gb = clientSize! / (1024 * 1024 * 1024);
    if (gb > 1) return '${gb.toStringAsFixed(2)}GB';
    final mb = clientSize! / (1024 * 1024);
    return '${mb.toStringAsFixed(0)}MB';
  }

  /// Helper: Mensagem de status amigável
  String get statusMessage {
    if (corrupted) {
      return 'Game Corrupted - Repair recommended';
    }
    if (!installed) {
      return 'Game not installed';
    }
    if (fullyExtracted) {
      return 'Game ready to play';
    }
    return 'Game partially installed';
  }

  /// Helper: Cor para UI (por status)
  String get statusColor {
    if (corrupted) return 'FF0000'; // Vermelho
    if (!installed) return 'FFA500'; // Laranja
    if (fullyExtracted) return '00FF00'; // Verde
    return 'FFFF00'; // Amarelo
  }

  /// Helper: Pode fazer repair?
  bool get canRepair {
    return corrupted && (clientSize != null && clientSize! < 50 * 1024 * 1024);
  }
}

/// Detalhes da detecção de instalação
class GameStatusDetails {
  final String gameDir;
  final bool hasClientDir;
  final bool hasUserDataDir;
  final bool hasClientExecutable;
  final int? diskSpace; // Bytes disponível
  final String timestamp;

  GameStatusDetails({
    required this.gameDir,
    required this.hasClientDir,
    required this.hasUserDataDir,
    required this.hasClientExecutable,
    this.diskSpace,
    required this.timestamp,
  });

  factory GameStatusDetails.fromJson(Map<String, dynamic> json) {
    return GameStatusDetails(
      gameDir: json['gameDir'] ?? '',
      hasClientDir: json['hasClientDir'] ?? false,
      hasUserDataDir: json['hasUserDataDir'] ?? false,
      hasClientExecutable: json['hasClientExecutable'] ?? false,
      diskSpace: json['diskSpace'],
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gameDir': gameDir,
      'hasClientDir': hasClientDir,
      'hasUserDataDir': hasUserDataDir,
      'hasClientExecutable': hasClientExecutable,
      'diskSpace': diskSpace,
      'timestamp': timestamp,
    };
  }

  /// Formatar espaço em disco
  String get diskSpaceFormatted {
    if (diskSpace == null) return 'Unknown';
    final gb = diskSpace! / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)}GB';
  }
}
