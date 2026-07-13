# Кофе — Stitch screen map

Project: `projects/3138235047997111615` (Кофе Mobile App)
Refs: `docs/stitch/refs/*.png` + `*.html`

## Navigation contract

`Splash → City → Pickup venue → Promo → AppShell(Menu)`

The AppShell branches to Profile, Menu, Cart and Venues. PDP and sheets are temporary routes over the current flow. Preserve cart, selected city/venue and user session while switching tabs.

**Menu Home is Flutter-owned** — do not replace with Stitch «Меню».

## Master screens (live Stitch IDs)

| # | Canvas screen | Stitch screen ID | Flutter source | Action |
|---|---|---|---|---|
| 1 | Splash | `eb795bd8c9224757b743497b0aeef201` | `features/splash` | Redesign |
| 2 | City picker | `5321dc453cd7434f9493f7e8790124f6` | `features/onboarding/city_screen` | Redesign |
| 3 | Pickup venue | — (no Stitch UI) | `features/onboarding/venue_screen` | Token align only |
| 4 | Promo | `29c344b45cdf4fe78ee78a4231a5ed9e` | `features/promo` | Redesign shell; keep 4 TZ slides |
| 5 | Menu Home | `0911e588190445e0a247206e27ecd4c8` | `features/menu` | **SKIP — keep current** |
| 6 | Category (Лимонады) | `e9bc6813613a43a3a0eb0fde581b5c7e` | `features/menu/category_screen` | New |
| 7 | PDP | `1c4387c35ab94af8a1d13131186540f8` | `features/product` | Redesign |
| 8 | Modifier milk | `433d68317ca9485a8191fe760625e861` | product sheet | Redesign |
| 9 | Cart filled | `073f8790ba5f433e936f7b275643c62f` | `features/cart` | Redesign |
| 10 | Cart empty | `a70b2d42be86425c8193a56f8f1b8890` | `features/cart` | Redesign |
| 11 | Promo code sheet | `c0ea013c513042f9a41319f470521cdf` | cart sheet | Redesign |
| 12 | Comment sheet | `d57a02f246a44c7b9c01106c84ba2739` | cart sheet | Redesign |
| 13 | Time sheet | `07d1229f6e974c86bff9d2c82740b439` | cart sheet | Redesign |
| 14 | Payment | `500cb13a0d574ce8aa06a3cd875ae8e1` | `features/cart/payment` | New |
| 15 | Profile guest | `9c9dbe51d9a5401d940b3217e099608e` | `features/profile` | Redesign |
| 16 | Profile member | `1d8016ce610044a78cf097ae38781e17` | `features/profile` | Redesign |
| 17 | My data | `270a0780075143bb92ef93dbaa9ee4b1` | `features/profile/edit` | New |
| 18 | Order history | `ef892dc914ac446fa10376bb2d2c95f6` | `features/orders` | New |
| 19 | Order detail | `4cff8cef7f28476c9e6a5625da1fe4d3` | `features/orders` | New |
| 20 | Review | `10b02686cba34202a411d42a75bc4ccf` | orders sheet | New |
| 21 | Auth phone | `2d89a11dd98c44e1ba0f9bf7aa907426` | `features/auth` | Redesign |
| 22 | Auth code | `5a21dbe358734562a0a5cb23ee1bd603` | `features/auth` | Redesign |
| 23 | Venues | `28facbc8a6c247d3994212078287c917` | `features/venues` | Redesign |

## Scope boundary

Stitch is the visual/prototype source; it must not redefine data schemas or business logic. Menu Home composition stays as implemented in Flutter.
