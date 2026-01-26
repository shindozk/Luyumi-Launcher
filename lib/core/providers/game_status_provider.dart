import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/game_status.dart';
import '../services/backend_service.dart';
import '../utils/logger.dart';

/// GameStatusProvider - Gerencia estado do game no frontend
///
/// Responsabilidades:
/// 1. Buscar status do backend periodicamente
/// 2. Atualizar estado local com detalhes da detecção
/// 3. Expor helpers para UI tomar decisões
/// 4. Gerenciar repair flow
/// 5. Cache de status para performance
class GameStatusProvider extends ChangeNotifier {
  GameStatus? _status;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastStatusCheck;
  bool _isRepairing = false;
  double _repairProgress = 0.0;
  String _repairMessage = '';

  // Install/Update progress
  bool _isInstalling = false;
  double _installProgress = 0.0;
  String _installMessage = '';
  Timer? _progressPollTimer;

  // Cache timeout: 5 segundos
  static const _cacheTimeout = Duration(seconds: 5);
  static const _pollInterval = Duration(milliseconds: 500); // Poll a cada 500ms

  // Getters
  GameStatus? get status => _status;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isRepairing => _isRepairing;
  double get repairProgress => _repairProgress;
  String get repairMessage => _repairMessage;

  // Install getters
  bool get isInstalling => _isInstalling;
  double get installProgress => _installProgress;
  String get installMessage => _installMessage;

  /// Status amigável para exibição
  String get statusDisplay {
    if (_isRepairing) return 'Repairing...';
    return _status?.statusMessage ?? 'Checking...';
  }

  /// Pode fazer repair?
  bool get canRepair {
    return _status?.canRepair ?? false;
  }

  /// Está corrompido?
  bool get isCorrupted {
    return _status?.corrupted ?? false;
  }

  /// Está instalado?
  bool get isInstalled {
    return _status?.installed ?? false;
  }

  /// Está totalmente extraído?
  bool get isFullyExtracted {
    return _status?.fullyExtracted ?? false;
  }

  /// Buscar status do backend
  /// [forceRefresh] ignora cache
  Future<void> checkGameStatus({bool forceRefresh = false}) async {
    try {
      // Verificar cache
      if (!forceRefresh && _lastStatusCheck != null) {
        final elapsed = DateTime.now().difference(_lastStatusCheck!);
        if (elapsed < _cacheTimeout) {
          Logger.info(
            '[GameStatusProvider] Using cached status (${elapsed.inMilliseconds}ms old)',
          );
          return;
        }
      }

      _isLoading = true;
      _error = null;
      notifyListeners();

      Logger.info('[GameStatusProvider] Fetching game status from backend...');

      final response = await BackendService.get('/api/game/status');

      if (response == null) {
        throw Exception('No response from backend');
      }

      _status = GameStatus.fromJson(response as Map<String, dynamic>);
      _lastStatusCheck = DateTime.now();

      Logger.info(
        '[GameStatusProvider] Status: '
        'installed=${_status?.installed}, '
        'corrupted=${_status?.corrupted}, '
        'fullyExtracted=${_status?.fullyExtracted}, '
        'clientSize=${_status?.clientSize}',
      );

      if (_status?.corrupted == true) {
        Logger.warning(
          '[GameStatusProvider] Game is corrupted! Issues: ${_status?.reasons}',
        );
      }
    } catch (err) {
      _error = err.toString();
      Logger.error('[GameStatusProvider] Error checking status: $err');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Iniciar instalação do game
  /// Retorna true se iniciou com sucesso
  Future<bool> startInstall({String? version}) async {
    _isInstalling = true;
    _installProgress = 0.0;
    _installMessage = 'Preparing installation...';
    notifyListeners();

    try {
      Logger.info('[GameStatusProvider] Starting game installation...');

      // Iniciar polling em background
      _startProgressPolling();

      // Chamar API de install
      final response = await BackendService.post('/api/game/install', {
        if (version != null) 'version': version,
      });

      if (response != null && response['success'] == true) {
        _installProgress = 100.0;
        _installMessage = 'Installation completed!';
        notifyListeners();

        // Aguardar 2 segundos antes de limpar
        await Future.delayed(const Duration(seconds: 2));

        // Parar polling
        _stopProgressPolling();

        // Atualizar status do game
        await checkGameStatus(forceRefresh: true);

        Logger.info('[GameStatusProvider] Installation completed successfully');
        return true;
      } else {
        throw Exception(response?['message'] ?? 'Unknown error');
      }
    } catch (err) {
      _installMessage = 'Installation failed: $err';
      Logger.error('[GameStatusProvider] Installation failed: $err');
      _stopProgressPolling();
      notifyListeners();
      return false;
    } finally {
      _isInstalling = false;
    }
  }

  /// Iniciar polling automático de progresso
  void _startProgressPolling() {
    _stopProgressPolling(); // Limpar timer anterior se houver

    _progressPollTimer = Timer.periodic(_pollInterval, (_) async {
      await _pollProgress();
    });

    Logger.info('[GameStatusProvider] Progress polling started');
  }

  /// Parar polling automático
  void _stopProgressPolling() {
    _progressPollTimer?.cancel();
    _progressPollTimer = null;
    Logger.info('[GameStatusProvider] Progress polling stopped');
  }

  /// Poll progresso de install/repair/update
  Future<void> _pollProgress() async {
    if (!_isInstalling && !_isRepairing) return;

    try {
      final response = await BackendService.get('/api/game/install/progress');

      if (response != null) {
        final percent = ((response['percent'] ?? 0) as num).toDouble();
        final message = response['message'] ?? 'Processing...';

        if (_isInstalling) {
          _installProgress = percent / 100.0;
          _installMessage = message;
        } else if (_isRepairing) {
          _repairProgress = percent / 100.0;
          _repairMessage = message;
        }

        notifyListeners();
      }
    } catch (err) {
      Logger.debug('[GameStatusProvider] Error polling progress: $err');
    }
  }

  /// Iniciar repair automático
  /// Monitora progresso via polling
  Future<bool> startRepair() async {
    if (!canRepair) {
      Logger.warning(
        '[GameStatusProvider] Repair not available for current status',
      );
      return false;
    }

    _isRepairing = true;
    _repairProgress = 0.0;
    _repairMessage = 'Starting repair...';
    notifyListeners();

    try {
      Logger.info('[GameStatusProvider] Starting game repair...');

      // Iniciar polling em background
      _startProgressPolling();

      final response = await BackendService.post('/api/game/repair', {});

      if (response != null && response['success'] == true) {
        _repairProgress = 100.0;
        _repairMessage = 'Repair completed!';
        notifyListeners();

        // Aguardar 2 segundos antes de limpar
        await Future.delayed(const Duration(seconds: 2));

        // Parar polling
        _stopProgressPolling();

        // Atualizar status do game
        await checkGameStatus(forceRefresh: true);

        Logger.info('[GameStatusProvider] Repair completed successfully');
        return true;
      } else {
        throw Exception(response?['message'] ?? 'Unknown error');
      }
    } catch (err) {
      _repairMessage = 'Repair failed: $err';
      Logger.error('[GameStatusProvider] Repair failed: $err');
      _stopProgressPolling();
      notifyListeners();
      return false;
    } finally {
      _isRepairing = false;
    }
  }

  /// Obter lista de issues/razões formatadas
  List<String> get issuesList {
    return _status?.reasons ?? [];
  }

  /// Obter recomendação de ação
  String get actionRecommendation {
    if (_status == null) {
      return 'Checking game status...';
    }

    if (_status!.corrupted) {
      if (canRepair) {
        return 'Game is corrupted. Click "Repair Game" to fix automatically.';
      } else {
        return 'Game is corrupted and cannot be auto-repaired. Reinstall required.';
      }
    }

    if (!_status!.installed) {
      return 'Game not installed. Click "Install" to begin.';
    }

    if (!_status!.fullyExtracted) {
      return 'Game installation incomplete. Click "Install" to resume.';
    }

    return 'Game is ready to play!';
  }

  /// Cor para indicador visual
  /// Retorna hex color sem #
  String get statusColor {
    return _status?.statusColor ?? 'CCCCCC'; // Cinza default
  }

  /// Limpar cache forçando refresh no próximo check
  void invalidateCache() {
    _lastStatusCheck = null;
    Logger.info('[GameStatusProvider] Cache invalidated');
  }

  /// Reset completo do provider
  void reset() {
    _status = null;
    _isLoading = false;
    _error = null;
    _lastStatusCheck = null;
    _isRepairing = false;
    _repairProgress = 0.0;
    _repairMessage = '';
    _isInstalling = false;
    _installProgress = 0.0;
    _installMessage = '';
    _stopProgressPolling();
    notifyListeners();
    Logger.info('[GameStatusProvider] Provider reset');
  }

  /// Cleanup
  @override
  void dispose() {
    _stopProgressPolling();
    super.dispose();
  }
}
