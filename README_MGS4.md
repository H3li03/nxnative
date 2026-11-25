# Metal Gear Solid 4 - nxnative

Experimental native macOS compatibility branch for
Metal Gear Solid 4: Guns of the Patriots.

## Target

- Program ID: 0100D0B01C4F4002
- Update: v393216
- Platform: macOS / Apple Silicon
- Backend: Metal

## Implemented changes

- Experimental patch-only BKTR RomFS extraction.
- Standalone program 4002 packaging support.
- Account HLE launcher handoff.
- Offline VPAK v3 shader extraction.
- Dynamic localization based on launcher language.
- Experimental vertex buffer cache range validation.

## Previous development results

- Successful native application startup.
- Game menus rendered.
- Audio playback and controller input working.
- 998 unique shaders extracted offline:
  - 190 vertex shaders.
  - 808 pixel shaders.
- No runtime shader dumping required for the extracted set.
- Launcher-controlled text localization working.

## Known issues

- Rendering flickering.
- Missing or incorrectly rendered 3D geometry.
- Vertex buffer memory pool resolution issues.
- Unimplemented NVN queue memory size function.
- Japanese voice audio with the tested regional assets.
- BKTR reconstruction remains experimental.
- Complete offline shader coverage is not guaranteed.

## Localization

The tested game data uses the Japanese regional layout.
Text localization is dynamically redirected according to
the language selected in the nxnative launcher.

The original regional asset layout remains unchanged.
Voice audio localization is not implemented.

## Development status

This branch is a work in progress, not a finished port.

The changes were migrated from an earlier working
development tree while preserving newer upstream code.
The integrated branch still requires compilation and
runtime regression testing.

## Game data

This repository contains source code changes only.
No game binaries, copyrighted game assets, extracted
shaders, encryption keys or NSP packages are included.

Users must provide their own legally obtained game data.
