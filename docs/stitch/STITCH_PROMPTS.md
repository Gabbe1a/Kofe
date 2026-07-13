# Кофе Мама — prompts for Google Stitch

## How to use

1. Create a **MOBILE** project named `Кофе Мама — Mobile App`.
2. Upload the three files from `ref/`, `BAGI/v4-menu-arc-final.png`, then import `DESIGN.md`.
3. Generate screens in the stated order. Do not generate all screens in one request.
4. Keep UI labels in Russian exactly as supplied. Use English only for design instructions.
5. Approve Menu Home and PDP before generating secondary screens; then apply the project design system to every next canvas.

## Project bootstrap prompt

```text
Create a high-fidelity MOBILE design system for “Кофе Мама”, a Russian pickup-only coffee ordering app. Target viewport: 375x812 with iOS and Android safe areas. Import and obey the attached DESIGN.md. Use the attached Jannat coffee-app image as the primary visual reference and the current green-arc menu screenshot as the approved brand expression. UI labels must be Russian. Keep the forest-green arc and central product cutout exclusive to Menu Home and product detail. Build a calm natural premium coffee experience, not a generic food-delivery app. Do not use Starbucks logos, black/cyan, emoji, stock photos, glassmorphism, or transparent primary buttons.
```

## Seed prompts

### 5. Menu Home

```text
Generate the Menu Home screen for “Кофе Мама”. Cream canvas, top label “Кофе Мама”, headline “Сделай день мягче”, search icon. Create a perfect forest-green half-disk with four circular category controls: “Кофе”, “Холодные”, “Чаи”, “Авторские”. Inside it, create a swipeable featured drink carousel with one brand-neutral caramel frappuccino cutout centred and partial neighbour cups visible. Under it: product name, price “349 ₽”, dots, a white pickup card “С собой” with “пр-кт Нагибина, 35а”, horizontal category pills, then a two-column product grid. Use the supplied green arc screenshot as spatial reference. Add the persistent four-tab sage bottom navigation.
```

### 8. PDP

```text
Generate a 375x812 product detail screen for “Карамельный фраппучино”. It must fit without vertical scrolling. Use a centered brand-neutral caramel drink cutout on a forest-green circle, back button, cart button, two-line title, concise Russian description, nutrition summary, size circles S/M/L, two compact modifier-summary rows “Выберите кофе” and “Выберите молоко”, quantity stepper, total price, and a fixed forest pill CTA “В заказ · 389 ₽”. Long description, full nutrition and modifier options are opened by bottom sheets, not shown in the primary frame. No Starbucks logo.
```

## Master-screen prompts

Use this prefix for each request: `Apply the imported Кофе Мама design system. Preserve all documented pickup-only business rules and Russian UI copy.`

1. **Splash:** `Create a cream splash screen with the КОФЕ МАМА wordmark, top arc slogan “заряжен на удачу”, bottom arc slogan “возьми с собой”, quiet coffee pattern, no actions.`
2. **City:** `Create “Выберите город”: search field “Поиск города”, list Ростов-на-Дону, Азов, Сочи, recommended treatment for Ростов-на-Дону.`
3. **Pickup venue:** `Create “Забрать · Ростов-на-Дону”: rounded map with brand pins, pickup-only “С собой”, venue list with radio state, address/hours/phone and CTA “Выбрать”.`
4. **Promo:** `Create a reusable promo carousel frame with image, headline, body, dots, close action and CTA. Show the “100 баллов за сторис” variant.`
5. **Category:** `Create a category/subcategory screen for “Лимонады” with a back action and three visual choices: “Лимонад”, “Айс-ти”, “Мохито”.`
6. **SKU catalog:** `Create a light two-column product grid for “Лимонады” with product cutouts, names, volume and price; include a compact search state.`
7. **Modifier sheet:** `Create a cream bottom sheet “Выберите молоко” with radio options, prices for plant milk and selected regular milk.`
8. **Cart empty:** `Create a Cart tab for a guest with a clear empty state, pickup context and forest CTA “В меню”.`
9. **Cart checkout:** `Create a filled Cart checkout: product card, quantity stepper, “Добавить к заказу?” carousel, grouped pickup/address/time/promo/comment/payment controls, total and a fixed disabled pay CTA when address confirmation is off.`
10. **Checkout sheets:** `Create a compact family of bottom sheets for promo code, order comment, pickup time and saved payment method.`
11. **Profile guest:** `Create guest Profile: forest identity card “Гость”, CTA “Войти”, grouped About/legal/report actions.`
12. **Profile member:** `Create authenticated Profile with customer identity, bonus balance “129”, recent orders, notifications entry and utility settings.`
13. **Account/history:** `Create linked screens for “Мои данные” editable fields and “История заказов” with status, date and price.`
14. **Order detail/review:** `Create order detail with status timeline, ready-in-15-minutes state, receipt, “Повторить заказ”, and a review bottom sheet with food and service ratings.`
15. **Auth:** `Create phone sign-in and OTP states with Russian labels, Telegram, Макс and SMS options; explain that the phone cannot be changed after authorization.`
16. **Venues:** `Create the Venues tab: rounded map scene, selected pin, selected/unselected venue cards with address, hours and call affordance.`
17. **Notifications:** `Create a notification list with order statuses “Подтвержден”, “Готовится”, “Приготовлен”, “Выдан” and a quiet promo entry.`
18. **Utility states:** `Create reusable visual states for legal links, report a problem form, delete-account confirmation and no-saved-card payment method.`

## Iteration prompts

```text
Keep the layout and all Russian content. Refine only visual hierarchy, spacing, typography and component consistency. Do not add new features.
```

```text
Create three variants of this screen using the same DESIGN.md. Explore only layout and whitespace; keep forest/cream palette, pickup-only flow and component set unchanged.
```

```text
Audit this screen against DESIGN.md at 375x812. Fix clipped Russian text, weak contrast, touch targets under 44px, unsafe bottom CTA, decorative drinks outside Menu/PDP, and inconsistent card radii.
```
