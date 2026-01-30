#!/usr/bin/env python3
"""
Discover the Real Hytale Game ID from CurseForge API
"""

import os
import sys
import json
import requests

print("="*70)
print("🔍 DISCOVER HYTALE GAME ID FROM CURSEFORGE API")
print("="*70)
print()

# Get API key
api_key = None

if 'CURSEFORGE_API_KEY' in os.environ:
    api_key = os.environ['CURSEFORGE_API_KEY']
    print("✓ API Key found in environment variable")
else:
    try:
        env_file = "../../.env"
        if os.path.exists(env_file):
            with open(env_file, 'r') as f:
                for line in f:
                    if line.startswith('CURSEFORGE_API_KEY='):
                        api_key = line.split('=', 1)[1].strip()
                        print(f"✓ API Key loaded from {env_file}")
                        break
    except:
        pass

if not api_key:
    print("❌ CURSEFORGE_API_KEY not found!")
    print()
    print("Please set one of:")
    print('  $env:CURSEFORGE_API_KEY = "your_key"  # PowerShell')
    print('  set CURSEFORGE_API_KEY=your_key       # CMD')
    print()
    print("Or add to LuyumiLauncher/.env:")
    print("  CURSEFORGE_API_KEY=your_key_here")
    sys.exit(1)

print(f"✓ Using API key (length: {len(api_key)})")
print()
print("="*70)
print("STEP 1: Fetching all games from CurseForge API...")
print("="*70)
print()

headers = {
    'x-api-key': api_key,
    'Accept': 'application/json'
}

try:
    # Get all games
    response = requests.get(
        "https://api.curseforge.com/v1/games",
        headers=headers,
        timeout=15
    )
    
    print(f"Status: {response.status_code}")
    
    if response.status_code == 200:
        games = response.json().get('data', [])
        print(f"✓ Received {len(games)} games from CurseForge")
        print()
        
        # Find Hytale
        hytale = None
        for game in games:
            if game.get('slug', '').lower() == 'hytale':
                hytale = game
                break
            elif game.get('name', '').lower() == 'hytale':
                hytale = game
                break
        
        if hytale:
            print("="*70)
            print("✅ FOUND HYTALE!")
            print("="*70)
            print()
            
            game_id = hytale.get('id')
            name = hytale.get('name')
            slug = hytale.get('slug')
            
            print(f"Game ID: {game_id}")
            print(f"Name: {name}")
            print(f"Slug: {slug}")
            print()
            
            print("="*70)
            print("STEP 2: Testing with discovered Game ID...")
            print("="*70)
            print()
            
            # Test search with discovered ID
            params = {
                'gameId': game_id,
                'pageSize': 10,
                'index': 0,
                'sortField': 6,
                'sortOrder': 'desc'
            }
            
            print(f"Searching for mods with gameId={game_id}...")
            print()
            
            search_response = requests.get(
                "https://api.curseforge.com/v1/mods/search",
                params=params,
                headers=headers,
                timeout=15
            )
            
            print(f"Status: {search_response.status_code}")
            
            if search_response.status_code == 200:
                search_data = search_response.json()
                mods = search_data.get('data', [])
                total = search_data.get('pagination', {}).get('totalCount', 0)
                
                print(f"✅ SUCCESS!")
                print(f"✅ Found {len(mods)} mods (Total available: {total})")
                print()
                
                if mods:
                    print("="*70)
                    print("TOP 5 HYTALE MODS:")
                    print("="*70)
                    print()
                    
                    for i, mod in enumerate(mods[:5], 1):
                        print(f"{i}. {mod.get('name', 'N/A')}")
                        print(f"   ID: {mod.get('id')}")
                        author = mod.get('authors', [{}])
                        if author:
                            print(f"   Author: {author[0].get('name', 'N/A')}")
                        print(f"   Downloads: {mod.get('downloadCount', 0):,}")
                        print()
                
                print("="*70)
                print("🎉 HYTALE GAME ID CONFIRMED!")
                print("="*70)
                print()
                print(f"Update your code with:")
                print(f"  GAME_ID = {game_id}  # Hytale")
                print()
                print(f"In Python:")
                print(f"  class CurseForgeService:")
                print(f"      GAME_ID = {game_id}  # Hytale")
                print()
                print(f"Current code uses: GAME_ID = 432")
                if game_id != 432:
                    print(f"⚠️  THIS IS DIFFERENT! Update it to {game_id}")
                else:
                    print(f"✅ 432 is correct!")
                
            else:
                print(f"❌ Error searching mods: {search_response.status_code}")
                print(search_response.text)
        
        else:
            print("❌ Hytale not found in games list!")
            print()
            print("Available games:")
            for game in games[:10]:
                print(f"  - {game.get('name')} (slug: {game.get('slug')})")
            
    elif response.status_code == 401:
        print("❌ ERROR 401: Unauthorized")
        print("API key is invalid!")
        
    else:
        print(f"❌ ERROR {response.status_code}")
        print(response.text)

except requests.exceptions.ConnectionError:
    print("❌ CONNECTION ERROR: Cannot reach CurseForge API")
    print("Check your internet connection")
    
except Exception as e:
    print(f"❌ ERROR: {e}")
    import traceback
    traceback.print_exc()
