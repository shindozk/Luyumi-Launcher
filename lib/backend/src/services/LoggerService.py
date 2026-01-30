from typing import List
import builtins
import logging
import sys
import os

class LoggerService:
    _logger = None
    _logs = []
    _max_logs = 1000
    _original_print = None

    @classmethod
    def initialize(cls):
        if cls._logger:
            return
        cls._logger = logging.getLogger("LuyumiBackend")
        cls._logger.setLevel(logging.INFO)
        
        # Stream handler for stdout
        handler = logging.StreamHandler()
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        cls._logger.addHandler(handler)
        
        # File handler for persistence
        try:
            log_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'backend.log')
            file_handler = logging.FileHandler(log_path, encoding='utf-8')
            file_handler.setFormatter(formatter)
            cls._logger.addHandler(file_handler)
        except Exception as e:
            print(f"Failed to initialize file logger: {e}")
        
        # Add custom handler to capture logs in memory
        class MemoryHandler(logging.Handler):
            def emit(self, record):
                cls.log_entry(record.levelname.lower(), record.getMessage())
        
        cls._logger.addHandler(MemoryHandler())

        if cls._original_print is None:
            cls._original_print = builtins.print

            def patched_print(*args, **kwargs):
                sep = kwargs.get("sep", " ")
                message = sep.join(str(a) for a in args)
                target = kwargs.get("file", sys.stdout)
                level = "error" if target in (sys.stderr, getattr(sys, "__stderr__", None)) else "info"
                cls.log_entry(level, message)
                cls._original_print(*args, **kwargs)

            builtins.print = patched_print

    @classmethod
    def log_entry(cls, level, message):
        import datetime
        if level == "warning":
            level = "warn"
        entry = {
            "timestamp": datetime.datetime.now().isoformat(),
            "level": level,
            "message": message
        }
        cls._logs.append(entry)
        if len(cls._logs) > cls._max_logs:
            cls._logs = cls._logs[-cls._max_logs:]

    @classmethod
    def info(cls, message):
        if cls._logger: cls._logger.info(message)
        else: print(message)

    @classmethod
    def error(cls, message):
        if cls._logger: cls._logger.error(message)
        else: print(message)

    @classmethod
    def warning(cls, message):
        if cls._logger: cls._logger.warning(message)
        else: print(message)

    @classmethod
    def get_logs(cls, limit=None):
        if limit:
            return cls._logs[-limit:]
        return cls._logs

    @classmethod
    def get_logs_since(cls, timestamp):
        return [log for log in cls._logs if log["timestamp"] > timestamp]

    @classmethod
    def clear_logs(cls):
        cls._logs = []

    @classmethod
    def get_logs_by_level(cls, level):
        return [log for log in cls._logs if log["level"] == level]
