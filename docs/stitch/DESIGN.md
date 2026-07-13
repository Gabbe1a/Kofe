# Кофе Мама — Stitch design system

## Project brief

Create a high-fidelity **mobile** UI system for the Russian coffee-chain app “Кофе Мама”. The app supports one ordering mode only: pickup (`С собой`). Do not introduce delivery, dine-in, a multi-choice fulfilment toggle, Starbucks branding, or a web dashboard.

Design for a 375 × 812 mobile viewport with safe areas. Keep every primary action usable with one hand. UI copy must be in Russian; design instructions and component names may be in English.

## Reference priority

1. `ref/Creative & Modern UI design of App __ Jannat Design.jpg` — primary: the forest-green arc, centered drink cutout, soft cream canvas, circular size choices and rounded CTA.
2. `BAGI/v4-menu-arc-final.png` — current approved application expression of the arc.
3. `ref/ui web app.jpg` — secondary: product-card depth and intentional featured items.
4. `ref/UpCUP coffee mobile app.jpg` — catalog rhythm only: light two-column product grid and compact category tabs.

Preserve the menu arc and centered drink as signature composition on **Menu Home** and **PDP only**. Secondary screens inherit the palette, soft surfaces, curves, typography and rhythm but must not repeat a decorative hero drink.

## Foundation tokens

| Token | Value | Use |
|---|---:|---|
| `forest` | `#1B4D3E` | primary CTA, Menu arc, selected states |
| `forest-deep` | `#0F3D32` | active icon/text on navigation |
| `emerald` | `#2D6A4F` | secondary green |
| `sage` | `#A8C5B0` | bottom navigation and soft accents |
| `sage-soft` | `#C8D9CC` | icon wells, selected cards |
| `cream` | `#F7F2E9` | application background |
| `cream-warm` | `#FBF7F0` | quiet warm surface |
| `caramel` | `#C4A574` | product and reward accent |
| `ink` | `#1A1A1A` | primary text |
| `ink-muted` | `#5C5C5C` | secondary text |
| `surface` | `#FFFFFF` | cards and sheets |
| `danger` | `#C45C4A` | destructive/error state |

Typography: **Manrope** for display and headings, **Nunito Sans** for body/UI. Both must support Cyrillic. Use strong display headlines with tight tracking; do not use Inter as a fallback design choice. Use 12/14/16/18/24/28/34 px text scale. Apply 1.25–1.4 line height for body copy.

Geometry: 20 px persistent side gutter, 4 px base spacing unit, 12/16/24 px card radii, 42 px circular icon wells, 44 px minimum tap targets, 56 px primary CTA height. Shadows are low-opacity forest ambient shadows only; no hard black offset shadows.

## Components

- `AppShell`: cream canvas, status safe area, persistent four-tab sage bottom bar: `Профиль`, `Меню`, `Корзина`, `Заведения`; active item forest-deep; cart has a numeric badge.
- `PrimaryCTA`: full-width forest pill with cream text. Never use transparent primary CTA.
- `SoftSurface`: white or cream-warm rounded card, 16–24 px radius, optional subtle forest shadow.
- `IconWell`: 42 px sage/sage-soft circle with a forest line icon. Use SVG/line icons, never emoji.
- `SelectionChip`: circular size button or pill category tab; selected state uses forest plus text/icon contrast, not color alone.
- `CheckoutRow`: label, helpful current value, recognisable line icon, chevron or control.
- `ProductCard`: intentional product cutout, title, volume, price; no stock placeholder or random image.
- `BottomSheet`: cream surface, rounded top corners, drag handle; use it for modifiers, comments, promo code, payment method and extended PDP information.

## Screen rules

- Menu Home: a perfect forest half-disk/arc with four circular category controls, a horizontally swipeable product hero and visible neighbouring cups.
- PDP: no vertical scroll at 375 × 812. Main frame contains hero, title, short description, nutrition summary, sizes, modifier summaries, quantity and fixed CTA. Long details and complete option lists move to sheets.
- Cart: preserve 20 px horizontal safe-area padding for both scrolling content and pay CTA. Group checkout controls in a SoftSurface; keep the upsell carousel separate.
- Profile: support guest and authenticated states. Authenticated state includes identity, bonus balance, order history and utility actions.
- Venues: map is a clipped rounded scene; cards provide selected state, address, hours and call action.

## Accessibility and content

- Contrast text and controls to WCAG AA: normally 4.5:1 for body text.
- Do not encode selection by colour only. Use checkmarks, selected labels or weight changes.
- Preserve Russian labels from `docs/TZ-Kofe-Mama-Flutter.md`; do not shorten required business fields into generic placeholder text.
- Support long Russian strings without clipping key controls. Use two-line labels where needed.

## Prohibitions

- No black-and-cyan legacy theme, purple gradients, generic SaaS cards, glassmorphism, emoji icons, Starbucks logos, random stock product images, or broken assets.
- Do not replace the Menu arc with a plain text tab row.
- Do not put a drink hero on Profile, Cart, or Venues.
- Do not add delivery, dine-in, loyalty mechanics beyond the documented bonus balance, or new backend flows.
