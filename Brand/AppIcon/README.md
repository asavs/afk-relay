# AFK Relay app icon

This directory contains the durable composition references, one approved
repository preview, and the checksum manifest for the production app icon.

## Authoritative files

- `../../AFKRelay/AppIcon.icon` is the production Icon Composer package
  compiled by the Xcode target.
- `AFKRelay-AppIcon-Preview.png` is the approved Default-appearance preview.
- `AFKRelay-StudioC-Source-1254.png` preserves the original Studio C master.
- `AFKRelay-StudioC-Reference-1024.png` is the canonical square composition
  reference, resampled once from that master.

The complete Layered 05 study, its deterministic scripts, generated working
assets, verification renders, and earlier experiments are preserved in the
separate `icon-work` design library. They are intentionally not vendored into
the application repository.

## Editing contract

- Treat the production package as immutable until a replacement is explicitly
  approved.
- Do not substitute the pedestrian silhouette or change its angle.
- Keep the baton geometrically straight and behind both hands.
- Keep the pedestrian, baton, and avatar in one parallax-safe foreground group.
- Keep generic foreground shadows, Liquid Glass, translucency, and specular
  treatment disabled.
- Compare replacements at 1024, 60, and 32 pixels in Default and Dark, then
  inspect a circular watch mask before promotion.
- Preserve replaced production packages in the external design archive.

## Production verification

The approved Layered 05 package was compiled by Xcode for a generic iOS
Simulator destination. The asset compiler emitted light, dark, and tintable
1024 px renditions, deployed 120 × 120 iPhone and 152 × 152 iPad icons, and a
layered `Assets.car`. The complete application target built successfully.

## Production checksums

```text
46b834a660b5b2940b777e264fb4babc61ea667e9cc5b34de3eedbf4744bc349  icon.json
1b5ea298008d0c92ed863c945c026b9b3816726bd653a333abb08a5bfc3d2a64  Assets/01-variant-002-shadow-fidelity-1088.png
ad8fb90e5bde548a87198d98f70e82bef0665405c1a364add75b484204a8babf  Assets/01-variant-002-shadow-fidelity-moonlight-1088.png
1d6f601844bdf03fb80548b549c6e250a68533ba0aa239b0c906586eb94eca72  Assets/02-projected-foot-umbra-1088.png
66ab9692151b242a6167c418789a34cec24f878dc61ee0e09e96475454cf582f  Assets/03-pedestrian-variant-002-1088.png
3a97719f16a973c3e0209ce07271f21557aa4fedef4ee0021a2a944d2e12dc77  Assets/04-avatar-baton-1088.png
829de0fcc49d5273e2dee8b5b0bacf7168343d6ebc8391969db1ae0976f910d9  Assets/05-motion-clockwise.png
```
