import os
import subprocess
import platform

class UIService:
    @staticmethod
    def open_folder(path_to_open):
        try:
            path_to_open = os.path.abspath(path_to_open)
            if not os.path.exists(path_to_open):
                return False

            if platform.system() == 'Windows':
                os.startfile(path_to_open)
            elif platform.system() == 'Darwin':
                subprocess.Popen(['open', path_to_open])
            else:
                subprocess.Popen(['xdg-open', path_to_open])
            return True
        except Exception as e:
            print(f"Error opening folder: {e}")
            return False
