import uuid
import time
from datetime import datetime
from .ConfigService import ConfigService

class ProfileService:
    @classmethod
    def init(cls):
        config = ConfigService.load_config()
        if not config.get('profiles') or len(config.get('profiles', {})) == 0:
            cls.migrate_legacy_config(config)

    @classmethod
    def migrate_legacy_config(cls, config):
        default_profile_id = 'default'
        now = datetime.utcnow().isoformat() + "Z"
        
        default_profile = {
            "id": default_profile_id,
            "name": "Default",
            "created": now,
            "lastUsed": now,
            "mods": config.get('installedMods', []),
            "javaPath": config.get('javaPath', ''),
            "gameOptions": {
                "minMemory": "1G",
                "maxMemory": "4G",
                "args": []
            }
        }

        ConfigService.save_config({
            "profiles": {default_profile_id: default_profile},
            "activeProfileId": default_profile_id
        })

    @classmethod
    def create_profile(cls, name):
        profile_id = str(uuid.uuid4())
        now = datetime.utcnow().isoformat() + "Z"
        
        new_profile = {
            "id": profile_id,
            "name": name,
            "created": now,
            "lastUsed": None,
            "mods": [],
            "javaPath": "",
            "gameOptions": {
                "minMemory": "1G",
                "maxMemory": "4G",
                "args": []
            }
        }

        config = ConfigService.load_config()
        profiles = config.get('profiles', {})
        profiles[profile_id] = new_profile
        
        ConfigService.save_config({"profiles": profiles})
        return new_profile

    @classmethod
    def update_profile(cls, profile_id, updates):
        config = ConfigService.load_config()
        profiles = config.get('profiles', {})
        
        if profile_id in profiles:
            profiles[profile_id].update(updates)
            ConfigService.save_config({"profiles": profiles})
            return profiles[profile_id]
        
        return None

    @classmethod
    def get_profiles(cls):
        config = ConfigService.load_config()
        return config.get('profiles', {})

    @classmethod
    def get_active_profile(cls):
        config = ConfigService.load_config()
        active_id = config.get('activeProfileId', 'default')
        profiles = config.get('profiles', {})
        return profiles.get(active_id)
