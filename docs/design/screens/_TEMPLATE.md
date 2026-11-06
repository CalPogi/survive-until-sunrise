# Screen: <name>

Exported image: `docs/design/screens/<name>.png` (desktop) and `<name>-phone.png`.

## Layout tree
```
ScreenGui
  Frame Root (Size 1,0,1,0)
    ...
```
Note sizes as UDim2 scale, anchor points, aspect-ratio constraints and 9-slice centers.

## States
Default, hover, pressed, disabled, loading, empty, error.

## Motion
| Element | Trigger | Property | Tokens (duration, easing) |
|---|---|---|---|

## Copy
Every visible string, exactly.

## Assets needed
PNG only (no SVG). Size in px and 9-slice margins. Add rows to `docs/ASSETS.md`.

## Accuracy check
- [ ] Matches the export at desktop size
- [ ] Matches the export at phone size
