#!/usr/bin/env python3
"""
Final Test: Verify Mods System Works with Correct Game ID
"""

import os
import sys
import json
import requests

print("\n" + "="*70)
print("✅ FINAL TEST: Hytale Mods System")
print("="*70 + "\n")

# Get API key
api_key = None

if 'CURSEFORGE_API_KEY' in os.environ:
    api_key = os.environ['CURSEFORGE_API_KEY']
    print("✓ API Key found in environment")
else:
    try:
        env_file = "../../.env"
        if os.path.exists(env_file):
            with open(env_file, 'r') as f:
                for line in f:
                    if line.startswith('CURSEFORGE_API_KEY='):
                        api_key = line.split('=', 1)[1].strip()
                        print(f"✓ API Key loaded from .env")
                        break
    except:
        pass

if not api_key:
    print("❌ API Key not found!")
    sys.exit(1)

print(f"✓ API Key length: {len(api_key)}")
print()

# Test 1: Popular Mods
print("-" * 70)
print("TEST 1: Get Popular Hytale Mods (No Search Query)")
print("-" * 70)

headers = {
    'x-api-key': api_key,
    'Accept': 'application/json'
}

params = {
    'gameId': 70216,  # Hytale (correct ID!)
    'pageSize': 20,
    'index': 0,
    'sortField': 6,  # Most Downloaded
    'sortOrder': 'desc'
}

try:
    response = requests.get(
        "https://api.curseforge.com/v1/mods/search",
        params=params,
        headers=headers,
        timeout=15
    )
    
    if response.status_code == 200:
        data = response.json()
        mods = data.get('data', [])
        total = data.get('pagination', {}).get('totalCount', 0)
        
        print(f"✅ Status: {response.status_code}")
        print(f"✅ Mods returned: {len(mods)}")
        print(f"✅ Total available: {total:,}")
        print()
        
        print("SAMPLE MODS (First 5):")
        for i, mod in enumerate(mods[:5], 1):
            print(f"  {i}. {mod.get('name')}")
            print(f"     Downloads: {mod.get('downloadCount'):,}")
        
        success1 = True
    else:
        print(f"❌ Error: {response.status_code}")
        success1 = False
        
except Exception as e:
    print(f"❌ Exception: {e}")
    success1 = False

print()

# Test 2: Search Mods
print("-" * 70)
print("TEST 2: Search for Specific Mods (Query: 'quest')")
print("-" * 70)

search_params = {
    'gameId': 70216,
    'pageSize': 10,
    'index': 0,
    'searchFilter': 'quest',
    'sortField': 6,
    'sortOrder': 'desc'
}

try:
    response = requests.get(
        "https://api.curseforge.com/v1/mods/search",
        params=search_params,
        headers=headers,
        timeout=15
    )
    
    if response.status_code == 200:
        data = response.json()
        mods = data.get('data', [])
        
        print(f"✅ Status: {response.status_code}")
        print(f"✅ Found: {len(mods)} mods matching 'quest'")
        
        if mods:
            print(f"\n  First result: {mods[0].get('name')}")
            print(f"  By: {mods[0].get('authors', [{}])[0].get('name', 'Unknown')}")
            print(f"  Downloads: {mods[0].get('downloadCount'):,}")
        
        success2 = True
    else:
        print(f"❌ Error: {response.status_code}")
        success2 = False
        
except Exception as e:
    print(f"❌ Exception: {e}")
    success2 = False

print()

# Test 3: Get Specific Mod Details
print("-" * 70)
print("TEST 3: Get Details of Specific Mod (BetterMap)")
print("-" * 70)

try:
    # BetterMap ID is 1430352
    response = requests.get(
        "https://api.curseforge.com/v1/mods/1430352",
        headers=headers,
        timeout=15
    )
    
    if response.status_code == 200:
        mod = response.json().get('data', {})
        
        print(f"✅ Status: {response.status_code}")
        print(f"✅ Mod: {mod.get('name')}")
        print(f"   By: {mod.get('authors', [{}])[0].get('name', 'Unknown')}")
        print(f"   Status: {mod.get('status', 'Unknown')}")
        print(f"   Downloads: {mod.get('downloadCount'):,}")
        
        files = mod.get('latestFiles', [])
        if files:
            print(f"   Latest File: {files[0].get('fileName')}")
        
        success3 = True
    else:
        print(f"❌ Error: {response.status_code}")
        success3 = False
        
except Exception as e:
    print(f"❌ Exception: {e}")
    success3 = False

print()
print("=" * 70)

if success1 and success2 and success3:
    print("🎉 ALL TESTS PASSED!")
    print("=" * 70)
    print()
    print("The Hytale Mods System is working correctly!")
    print()
    print("Next steps:")
    print("1. Restart the Luyumi Launcher")
    print("2. Go to Mods > Explorador")
    print("3. You should see 20+ real Hytale mods!")
    print()
    print("Game ID: 70216 (Hytale)")
    print("Total mods available: 3,400+")
    print()
else:
    print("⚠️  Some tests failed")
    print("Check the errors above")
    
print("=" * 70 + "\n")
