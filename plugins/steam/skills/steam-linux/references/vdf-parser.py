#!/usr/bin/env python3
"""
Binary VDF parser for Steam shortcuts.vdf

This module provides functions to read and write Steam's binary VDF format
used for non-Steam game shortcuts.
"""

import struct
from pathlib import Path


def read_shortcuts(path: Path) -> dict:
    """Read binary VDF shortcuts file."""
    if not path.exists():
        return {}

    with open(path, 'rb') as f:
        data = f.read()

    shortcuts = {}
    pos = 0

    def read_string():
        nonlocal pos
        end = data.index(b'\x00', pos)
        s = data[pos:end].decode('utf-8', errors='replace')
        pos = end + 1
        return s

    def read_int32():
        nonlocal pos
        val = struct.unpack('<I', data[pos:pos+4])[0]
        pos += 4
        return val

    def parse_object():
        nonlocal pos
        obj = {}
        while pos < len(data):
            type_byte = data[pos]
            pos += 1

            if type_byte == 0x08:  # End of object
                break

            name = read_string()

            if type_byte == 0x00:  # Nested object
                obj[name] = parse_object()
            elif type_byte == 0x01:  # String
                obj[name] = read_string()
            elif type_byte == 0x02:  # Int32
                obj[name] = read_int32()

        return obj

    # Skip initial header
    if data[0:1] == b'\x00':
        pos = 1
        read_string()  # "shortcuts"
        shortcuts = parse_object()

    return shortcuts


def write_shortcuts(path: Path, shortcuts: dict) -> None:
    """Write binary VDF shortcuts file."""

    def write_string(s: str) -> bytes:
        return s.encode('utf-8') + b'\x00'

    def write_int32(val: int) -> bytes:
        return struct.pack('<I', val & 0xFFFFFFFF)

    def write_object(obj: dict) -> bytes:
        result = b''
        for key, val in obj.items():
            if isinstance(val, dict):
                result += b'\x00' + write_string(key) + write_object(val) + b'\x08'
            elif isinstance(val, str):
                result += b'\x01' + write_string(key) + write_string(val)
            elif isinstance(val, int):
                result += b'\x02' + write_string(key) + write_int32(val)
        return result

    data = b'\x00' + write_string('shortcuts') + write_object(shortcuts) + b'\x08\x08'

    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'wb') as f:
        f.write(data)


def generate_app_id(exe_path: str, app_name: str) -> int:
    """Generate Steam shortcut app ID using the same algorithm Steam uses."""
    import zlib
    key = f'"{exe_path}"{app_name}'
    crc = zlib.crc32(key.encode('utf-8')) & 0xFFFFFFFF
    return crc | 0x80000000


def find_shortcut_by_name(shortcuts: dict, name: str) -> tuple:
    """Find a shortcut by AppName, returns (index, entry) or (None, None)."""
    for idx, entry in shortcuts.items():
        if isinstance(entry, dict) and entry.get('AppName') == name:
            return idx, entry
    return None, None


def add_shortcut(shortcuts: dict, app_name: str, exe_path: str,
                 start_dir: str = None, launch_options: str = '',
                 icon: str = '') -> int:
    """Add a new shortcut and return its app ID."""

    # Find next index
    next_idx = 0
    for key in shortcuts:
        if key.isdigit():
            next_idx = max(next_idx, int(key) + 1)

    app_id = generate_app_id(exe_path, app_name)

    if start_dir is None:
        start_dir = str(Path(exe_path).parent)

    shortcuts[str(next_idx)] = {
        'appid': app_id,
        'AppName': app_name,
        'Exe': f'"{exe_path}"',
        'StartDir': f'"{start_dir}"',
        'icon': icon,
        'ShortcutPath': '',
        'LaunchOptions': launch_options,
        'IsHidden': 0,
        'AllowDesktopConfig': 1,
        'AllowOverlay': 1,
        'OpenVR': 0,
        'Devkit': 0,
        'DevkitGameID': '',
        'DevkitOverrideAppID': 0,
        'LastPlayTime': 0,
        'FlatpakAppID': '',
        'tags': {}
    }

    return app_id


def remove_shortcut(shortcuts: dict, app_name: str) -> bool:
    """Remove a shortcut by name, reindex remaining shortcuts."""
    idx, _ = find_shortcut_by_name(shortcuts, app_name)
    if idx is None:
        return False

    # Rebuild without the removed entry
    new_shortcuts = {}
    new_idx = 0
    for key, entry in shortcuts.items():
        if key != idx:
            new_shortcuts[str(new_idx)] = entry
            new_idx += 1

    shortcuts.clear()
    shortcuts.update(new_shortcuts)
    return True


# Example usage
if __name__ == '__main__':
    from pathlib import Path

    STEAM_ROOT = Path.home() / ".local/share/Steam"

    # Find user ID
    userdata = STEAM_ROOT / "userdata"
    user_id = next((d.name for d in userdata.iterdir() if d.is_dir() and d.name.isdigit()), None)

    if user_id:
        shortcuts_path = STEAM_ROOT / f"userdata/{user_id}/config/shortcuts.vdf"
        shortcuts = read_shortcuts(shortcuts_path)

        print(f"Found {len(shortcuts)} shortcuts:")
        for idx, entry in shortcuts.items():
            if isinstance(entry, dict):
                print(f"  [{idx}] {entry.get('AppName', 'Unknown')}")
