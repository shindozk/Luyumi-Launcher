import os
import sys
import platform
import subprocess

def get_os():
    return platform.system().lower()

def get_arch():
    # Map x86_64 to amd64 to match legacy expectation
    arch = platform.machine().lower()
    if arch in ['x86_64', 'amd64', 'x64']:
        return 'amd64'
    if arch in ['aarch64', 'arm64']:
        return 'arm64'
    return arch

def is_windows():
    return get_os() == 'windows'

def is_mac():
    return get_os() == 'darwin'

def is_linux():
    return get_os() == 'linux'

def is_wayland_session():
    if not is_linux():
        return False
    
    session_type = os.environ.get('XDG_SESSION_TYPE', '').lower()
    if session_type == 'wayland':
        return True
        
    if os.environ.get('WAYLAND_DISPLAY'):
        return True
        
    try:
        session_id = os.environ.get('XDG_SESSION_ID')
        if session_id:
            output = subprocess.check_output(f'loginctl show-session {session_id} -p Type', shell=True, text=True)
            if 'wayland' in output.lower():
                return True
    except:
        pass
        
    return False

def setup_wayland_environment():
    if not is_linux():
        return {}
        
    if not is_wayland_session():
        return {}
        
    print('[Platform] Detected Wayland session, configuring environment...')
    env_vars = {
        'SDL_VIDEODRIVER': 'wayland',
        'GDK_BACKEND': 'wayland',
        'QT_QPA_PLATFORM': 'wayland',
        'MOZ_ENABLE_WAYLAND': '1',
        '_JAVA_AWT_WM_NONREPARENTING': '1',
        'ELECTRON_OZONE_PLATFORM_HINT': 'wayland'
    }
    return env_vars

def detect_gpu():
    os_name = get_os()
    try:
        if os_name == 'linux':
            return detect_gpu_linux()
        elif os_name == 'windows':
            return detect_gpu_windows()
        elif os_name == 'darwin':
            return detect_gpu_mac()
    except Exception as e:
        print(f"GPU detection failed: {e}")
    
    return {'mode': 'integrated', 'vendor': 'intel', 'integratedName': 'Unknown', 'dedicatedName': None}

def detect_gpu_linux():
    try:
        output = subprocess.check_output("lspci -nn | grep 'VGA\\|3D'", shell=True, text=True)
        lines = output.strip().split('\n')
        
        integrated_name = None
        dedicated_name = None
        has_nvidia = False
        has_amd = False
        
        for line in lines:
            if '10de:' in line or 'nvidia' in line.lower():
                has_nvidia = True
                dedicated_name = "NVIDIA GPU"
            elif '1002:' in line or 'amd' in line.lower() or 'radeon' in line.lower():
                has_amd = True
                dedicated_name = "AMD GPU"
            elif '8086:' in line or 'intel' in line.lower():
                integrated_name = "Intel GPU"
                
        if has_nvidia:
            return {'mode': 'dedicated', 'vendor': 'nvidia', 'integratedName': integrated_name, 'dedicatedName': dedicated_name}
        elif has_amd:
            return {'mode': 'dedicated', 'vendor': 'amd', 'integratedName': integrated_name, 'dedicatedName': dedicated_name}
        
        return {'mode': 'integrated', 'vendor': 'intel', 'integratedName': integrated_name, 'dedicatedName': None}
    except:
        return {'mode': 'integrated', 'vendor': 'intel', 'integratedName': 'Unknown', 'dedicatedName': None}

def detect_gpu_windows():
    try:
        output = subprocess.check_output('wmic path win32_VideoController get name', shell=True, text=True)
        lines = [line.strip() for line in output.split('\n') if line.strip() and line.strip() != 'Name']
        
        integrated_name = None
        dedicated_name = None
        has_nvidia = False
        has_amd = False
        
        for line in lines:
            lower = line.lower()
            if 'nvidia' in lower:
                has_nvidia = True
                dedicated_name = line
            elif 'amd' in lower or 'radeon' in lower:
                has_amd = True
                dedicated_name = line
            elif 'intel' in lower:
                integrated_name = line
                
        if has_nvidia:
            return {'mode': 'dedicated', 'vendor': 'nvidia', 'integratedName': integrated_name, 'dedicatedName': dedicated_name}
        elif has_amd:
            return {'mode': 'dedicated', 'vendor': 'amd', 'integratedName': integrated_name, 'dedicatedName': dedicated_name}
            
        return {'mode': 'integrated', 'vendor': 'intel', 'integratedName': integrated_name, 'dedicatedName': None}
    except:
        return {'mode': 'integrated', 'vendor': 'intel', 'integratedName': 'Unknown', 'dedicatedName': None}

def detect_gpu_mac():
    try:
        output = subprocess.check_output('system_profiler SPDisplaysDataType', shell=True, text=True)
        lines = output.split('\n')
        
        integrated_name = None
        dedicated_name = None
        has_nvidia = False
        has_amd = False
        
        for line in lines:
            if 'Chipset Model:' in line:
                gpu_name = line.split('Chipset Model:')[1].strip()
                lower = gpu_name.lower()
                
                if 'nvidia' in lower:
                    has_nvidia = True
                    dedicated_name = gpu_name
                elif 'amd' in lower or 'radeon' in lower:
                    has_amd = True
                    dedicated_name = gpu_name
                elif 'intel' in lower or 'iris' in lower or 'uhd' in lower:
                    integrated_name = gpu_name
                elif not dedicated_name and not integrated_name:
                    integrated_name = gpu_name
                    
        if has_nvidia:
            return {'mode': 'dedicated', 'vendor': 'nvidia', 'integratedName': integrated_name, 'dedicatedName': dedicated_name}
        elif has_amd:
            return {'mode': 'dedicated', 'vendor': 'amd', 'integratedName': integrated_name, 'dedicatedName': dedicated_name}
            
        return {'mode': 'integrated', 'vendor': 'intel', 'integratedName': integrated_name, 'dedicatedName': None}
    except:
        return {'mode': 'integrated', 'vendor': 'intel', 'integratedName': 'Unknown', 'dedicatedName': None}

def setup_gpu_environment(gpu_preference='auto'):
    if not is_linux():
        return {}
        
    final_preference = gpu_preference
    detected = detect_gpu()
    
    if gpu_preference == 'auto':
        final_preference = detected['mode']
        
    env_vars = {}
    
    if final_preference == 'dedicated':
        if detected['vendor'] == 'nvidia':
            env_vars['__NV_PRIME_RENDER_OFFLOAD'] = '1'
            env_vars['__GLX_VENDOR_LIBRARY_NAME'] = 'nvidia'
        else:
            env_vars['DRI_PRIME'] = '1'
            
    return env_vars
