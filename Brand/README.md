# AFK Relay visual identity

AFK Relay's product identity is theme-neutral. The icon depicts the product's
central metaphor directly: a real-world pedestrian relays a baton into the hand
of a generic game avatar.

The MVP arena's primitive sci-fi presentation is a temporary gameplay skin,
not a permanent brand requirement.

## Assets

- `AppIcon/AFKRelay-AppIcon-Preview.png` is the approved Default-appearance
  preview used by the repository README.
- `AppIcon/AFKRelay-StudioC-Source-1254.png` preserves the original Studio C
  master.
- `AppIcon/AFKRelay-StudioC-Reference-1024.png` is the canonical square
  composition reference.
- `../AFKRelay/AppIcon.icon` is the production Icon Composer document compiled
  by the Xcode target.

The complete sequence of working studies, generation scripts, masks, alternate
renders, and superseded concepts lives in the separate `icon-work` design
library. Those files are intentionally excluded from the application
repository.

## App-icon composition

The composition has four theme-neutral visual roles:

1. a seafoam-to-deep-teal atmosphere with a curved relay path;
2. one straight orange baton;
3. the rigid black pedestrian silhouette representing activity in real life;
4. the lavender game avatar receiving the relay while running toward the user.

The production Icon Composer document uses two parallax groups. The atmosphere
group owns the appearance-aware environmental plate. The foreground group owns
the projected pedestrian umbra, exact pedestrian, restrained arm-pump echo, and
avatar-plus-baton raster. Keeping the complete relay foreground together
prevents depth from separating either hand from the baton.

Liquid Glass, translucency, added specular treatment, and generic foreground
shadows are disabled so the approved illustration's lighting remains coherent.
Dark mode preserves the same geometry as a radial silver-blue moonlight
treatment.

## Current exploratory palette

These colors describe the current icon and are not a permanent game-theme
restriction.

| Role | Approximate color |
| --- | --- |
| Upper atmosphere | `#80B0B3` |
| Lower atmosphere | `#1F536F` |
| Pedestrian | `#242424` |
| Relay baton | `#F59A35` |
| Avatar | `#9189F3` |

## Verification

The production package contains only assets referenced by `icon.json`. Xcode's
asset compiler has verified its Default, Dark, and Tinted renditions for iPhone
and iPad, including 120 × 120 and 152 × 152 deployed icon files. During
production review, the same sources were checked with square and circular masks
and at 60 px and 32 px.

The production package is identified by the checksums recorded in
`AppIcon/README.md`.
