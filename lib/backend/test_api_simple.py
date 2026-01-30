#!/usr/bin/env python3
"""
Simple CurseForge API Test - No Dependencies
"""

import os
import sys
import json
import requests

print("="*60)
print("Testing CurseForge API v1 - Hytale Mods")
print("="*60)
print()

# Get API key from command line or .env file manually
api_key = None

# Try environment variable first
if 'CURSEFORGE_API_KEY' in os.environ:
    api_key = os.environ['CURSEFORGE_API_KEY']
    print("✓ API Key found in environment variable")
else:
    # Try to read .env file manually
    try:
        env_file = "../../.env"
        if os.path.exists(env_file):
            print(f"✓ Found .env file at {env_file}")
            with open(env_file, 'r') as f:
                for line in f:
                    if line.startswith('CURSEFORGE_API_KEY='):
                        api_key = line.split('=', 1)[1].strip()
                        print(f"✓ Loaded API key from .env file")
                        break
    except:
        pass

# If still no key, ask user
if not api_key:
    print()
    print("❌ CURSEFORGE_API_KEY not found!")
    print()
    print("Option 1: Add to environment:")
    print('  $env:CURSEFORGE_API_KEY = "your_key_here"  # PowerShell')
    print('  set CURSEFORGE_API_KEY=your_key_here       # CMD')
    print()
    print("Option 2: Create/Edit LuyumiLauncher/.env with:")
    print('  CURSEFORGE_API_KEY=your_key_here')
    print()
    print("Get API key from: https://console.curseforge.com/")
    sys.exit(1)

print(f"✓ Using API key (length: {len(api_key)})")
print()

# API parameters
base_url = 'https://api.curseforge.com/v1'
game_id = 70216  # Hytale (verified via API)

params = {
    'gameId': game_id,
    'pageSize': 20,
    'index': 0,
    'sortField': 6,  # Most Downloaded
    'sortOrder': 'desc'
}

headers = {
    'x-api-key': api_key,
    'Accept': 'application/json'
}

print("Requesting popular Hytale mods...")
print()

try:
    response = requests.get(
        f"{base_url}/mods/search",
        params=params,
        headers=headers,
        timeout=15
    )
    
    print(f"Status Code: {response.status_code}")
    
    if response.status_code == 200:
        data = response.json()
        mods = data.get('data', [])
        pagination = data.get('pagination', {})
        
        print(f"✅ SUCCESS!")
        print(f"✅ Returned: {len(mods)} mods")
        print(f"✅ Total available: {pagination.get('totalCount', 0)} mods")
        print()
        print("="*60)
        print("TOP 5 MOST POPULAR HYTALE MODS")
        print("="*60)
        print()
        
        if mods:
            for i, mod in enumerate(mods[:5], 1):
                print(f"{i}. {mod.get('name', 'N/A')}")
                print(f"   ID: {mod.get('id')}")
                author = mod.get('authors', [{}])
                if author:
                    print(f"   Author: {author[0].get('name', 'N/A')}")
                print(f"   Downloads: {mod.get('downloadCount', 0):,}")
                
                files = mod.get('latestFiles', [])
                if files:
                    print(f"   Latest File: {files[0].get('fileName', 'N/A')}")
                print()
        
        print("="*60)
        print("🎉 API IS WORKING!")
        print("Mods should now appear in the launcher!")
        print("="*60)
        
    elif response.status_code == 401:
        print("❌ ERROR 401: Unauthorized")
        print("The API key is invalid or expired!")
        print()
        print("Solution:")
        print("1. Go to https://console.curseforge.com/")
        print("2. Delete the old API token")
        print("3. Create a new one")
        print("4. Copy the new key")
        print("5. Update .env or set environment variable")
        print("6. Run this test again")
        
    elif response.status_code == 403:
        print("❌ ERROR 403: Forbidden")
        print("The API key does not have permission!")
        
    elif response.status_code == 404:
        print("❌ ERROR 404: Not Found")
        print("The API endpoint or game ID is incorrect!")
        
    else:
        print(f"❌ ERROR {response.status_code}")
        print(response.text)
        
except requests.exceptions.Timeout:
    print("❌ TIMEOUT: The CurseForge API took too long to respond")
    print("Try again in a moment")
    
except requests.exceptions.ConnectionError:
    print("❌ CONNECTION ERROR: Cannot reach CurseForge API")
    print()
    print("Check your:")
    print("1. Internet connection")
    print("2. Firewall settings")
    print("3. VPN/Proxy settings")
    print()
    print("Try: ping api.curseforge.com")
    
except Exception as e:
    print(f"❌ ERROR: {e}")
    import traceback
    traceback.print_exc()
