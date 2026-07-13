# Figma → Flutter visual system

Source: [Online Groceries App UI](https://www.figma.com/design/SQfQj3BpL0Yu5CjInrOQjU/Online-Groceries-App-UI--Community---Copy-?node-id=1-2&m=dev)  
File key: `SQfQj3BpL0Yu5CjInrOQjU`

## What was transferred

Visual language only. App routes, features and Menu Home composition stay as in the Flutter project.

| Token | Value |
|-------|-------|
| Primary | `#53B175` |
| Ink | `#181725` |
| Muted | `#7C7C7C` |
| Border | `#E2E2E2` |
| Search fill | `#F2F3F2` |
| Canvas | `#FCFCFC` |
| Card radius | `18` |
| CTA radius | `19` |
| Add button | `45×45`, radius `17` |
| Font | Gilroy → Manrope (Cyrillic) |

## Updated surfaces

- `app_colors.dart` / `app_theme.dart` / `app_radii.dart`
- `KofeSurface`, `KofeAddButton`, white bottom bar
- Menu / category product cards (bordered + green «+»)
- Splash (solid primary green)
- PDP qty + CTA, cart brand header
