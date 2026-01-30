import os
import json
import uuid
from ..utils.paths import get_resolved_app_dir

class ConfigService:
    @staticmethod
    def get_config_file():
        return os.path.join(get_resolved_app_dir(), 'config.json')

    @classmethod
    def load_config(cls):
        try:
            config_file = cls.get_config_file()
            if os.path.exists(config_file):
                with open(config_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
        except Exception as e:
            print(f"Error loading config: {e}")
        return {}

    @classmethod
    def save_config(cls, update: dict):
        try:
            config_file = cls.get_config_file()
            config_dir = os.path.dirname(config_file)
            
            if not os.path.exists(config_dir):
                os.makedirs(config_dir, exist_ok=True)
                
            current_config = cls.load_config()
            # Deep merge is safer, but shallow update matches original implementation
            current_config.update(update)
            
            with open(config_file, 'w', encoding='utf-8') as f:
                json.dump(current_config, f, indent=2)
        except Exception as e:
            print(f"Error saving config: {e}")

    @classmethod
    def get_auth_domain(cls):
        config = cls.load_config()
        return config.get('authDomain') or os.environ.get('HYTALE_AUTH_DOMAIN') or 'sanasol.ws'

    @classmethod
    def get_or_create_client_uuid(cls):
        """
        Returns a persistent unique ID for this installation.
        If it doesn't exist, it generates one and saves it.
        """
        config = cls.load_config()
        client_uuid = config.get('client_uuid')
        
        if not client_uuid:
            client_uuid = str(uuid.uuid4())
            print(f"[ConfigService] Generated new unique client UUID: {client_uuid}")
            cls.save_config({'client_uuid': client_uuid})
        
        return client_uuid
