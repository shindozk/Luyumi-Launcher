import os
import shutil
import platform
import logging
from ..utils.paths import get_game_mods_path, get_profiles_dir

class ModManager:
    @staticmethod
    def get_profile_mods_path(profile_id):
        profile_dir = os.path.join(get_profiles_dir(), profile_id)
        mods_dir = os.path.join(profile_dir, 'mods')
        if not os.path.exists(mods_dir):
            os.makedirs(mods_dir, exist_ok=True)
        return mods_dir

    @staticmethod
    def get_global_mods_path():
        return get_game_mods_path()

    @staticmethod
    def sync_mods_for_profile(profile_id):
        try:
            print(f"[ModManager] Syncing mods for profile: {profile_id}")
            
            global_mods_path = ModManager.get_global_mods_path()
            profile_mods_path = ModManager.get_profile_mods_path(profile_id)
            profile_disabled_mods_path = os.path.join(os.path.dirname(profile_mods_path), 'DisabledMods')

            if not os.path.exists(profile_disabled_mods_path):
                os.makedirs(profile_disabled_mods_path, exist_ok=True)

            needs_link = False

            if os.path.exists(global_mods_path):
                # Robust junction/symlink check
                is_junction = False
                if platform.system() == 'Windows':
                    try:
                        # Junctions often report as directories but have different stats
                        # islink() might be False for junctions in some Python versions
                        attr = os.win32_ver()[0] # Just a check, not reliable
                        # Better way: check for reparse point attribute or use islink if Python 3.8+
                        is_junction = os.path.islink(global_mods_path) or (os.path.isdir(global_mods_path) and not os.path.samefile(global_mods_path, os.path.realpath(global_mods_path)))
                    except:
                        pass

                if is_junction or os.path.islink(global_mods_path):
                    try:
                        link_target = os.readlink(global_mods_path)
                        if os.path.abspath(link_target) != os.path.abspath(profile_mods_path):
                            print(f"[ModManager] Updating symlink from {link_target} to {profile_mods_path}")
                            if os.path.isdir(global_mods_path) and platform.system() == 'Windows':
                                os.rmdir(global_mods_path)
                            else:
                                os.remove(global_mods_path)
                            needs_link = True
                    except Exception as e:
                        print(f"[ModManager] Error reading/removing link: {e}")
                        # If it's broken, just remove it anyway if possible
                        try:
                            if os.path.isdir(global_mods_path): os.rmdir(global_mods_path)
                            else: os.remove(global_mods_path)
                        except: pass
                        needs_link = True
                elif os.path.isdir(global_mods_path):
                    # MIGRATION: It's a real directory. Move contents to profile.
                    print('[ModManager] Migrating global mods folder to profile folder...')
                    for item in os.listdir(global_mods_path):
                        src = os.path.join(global_mods_path, item)
                        dest = os.path.join(profile_mods_path, item)
                        if not os.path.exists(dest):
                            try:
                                shutil.move(src, dest)
                            except Exception as e:
                                print(f"[ModManager] Failed to move {item}: {e}")
                    
                    # Also migrate DisabledMods if it exists globally
                    global_disabled_path = os.path.join(os.path.dirname(global_mods_path), 'DisabledMods')
                    if os.path.exists(global_disabled_path) and os.path.isdir(global_disabled_path):
                        for item in os.listdir(global_disabled_path):
                            src = os.path.join(global_disabled_path, item)
                            dest = os.path.join(profile_disabled_mods_path, item)
                            if not os.path.exists(dest):
                                try:
                                    shutil.move(src, dest)
                                except:
                                    pass
                        try:
                            shutil.rmtree(global_disabled_path)
                        except:
                            pass

                    try:
                        shutil.rmtree(global_mods_path)
                        needs_link = True
                    except Exception as e:
                        print(f'[ModManager] Failed to remove global mods dir: {e}')
                        # Fallback for Windows junctions that rmtree might fail on
                        try:
                            os.rmdir(global_mods_path)
                            needs_link = True
                        except:
                            raise Exception(f'Failed to migrate mods directory: {e}')
            else:
                needs_link = True

            if needs_link:
                print(f"[ModManager] Creating symlink: {global_mods_path} -> {profile_mods_path}")
                try:
                    # Create junction on Windows, symlink on Unix
                    if platform.system() == 'Windows':
                        import _winapi
                        _winapi.CreateJunction(profile_mods_path, global_mods_path)
                    else:
                        os.symlink(profile_mods_path, global_mods_path, target_is_directory=True)
                except Exception as err:
                    print(f'[ModManager] Failed to create symlink: {err}')
                    # Fallback: create dir (sync won't work but prevents crash)
                    if not os.path.exists(global_mods_path):
                        os.makedirs(global_mods_path, exist_ok=True)
            
            return {"success": True}
        except Exception as error:
            print(f'[ModManager] Error syncing mods: {error}')
            return {"success": False, "error": str(error)}
