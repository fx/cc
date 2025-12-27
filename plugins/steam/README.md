# Steam Plugin

Steam management for Linux - shortcuts, Proton configuration, and VDF file manipulation.

## Installation

```
/plugin install steam
```

## Skills

### steam-linux

Auto-invoked when working with Steam on Linux:
- Managing non-Steam game shortcuts
- Configuring Proton/Wine compatibility
- Parsing binary and text VDF files
- Finding Steam paths and Proton prefixes

## Usage Examples

**Adding a non-Steam game:**
> "Add Battle.net as a non-Steam game with Proton"

**Finding a game's Wine prefix:**
> "Find where Steam installed the Proton prefix for Battle.net"

**Configuring Proton:**
> "Set this shortcut to use Proton Experimental"

**Sharing prefixes:**
> "Make this shortcut use the same Wine prefix as another game"

## Reference Files

The skill includes a complete Python VDF parser at:
`skills/steam-linux/references/vdf-parser.py`

This can be used directly or as reference for implementing Steam shortcut management.

## Notes

- Close Steam before modifying configuration files
- Restart Steam after adding/modifying shortcuts
- Non-Steam shortcuts require CRC32-based app ID generation
- Always quote paths in Exe and StartDir fields
