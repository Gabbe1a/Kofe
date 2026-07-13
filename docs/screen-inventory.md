# Кофе Мама — полный inventory экранов

Источник: скриншоты `IMG_1921` … `IMG_1974`  
Дата разбора: 2026-07-09  
Статус: **54 PNG** (39 первичных + 15 досъёмка 1960–1974)

## Сводка

| Метрика | Значение |
|--------|----------|
| Всего скринов | 54 |
| Уникальных экранов/состояний | ~40 |
| Bottom tabs | Профиль · Меню · Корзина · Заведения |
| Тема | Dark, акцент teal/cyan |
| Города | Ростов-на-Дону, Азов, Сочи |
| Тип заказа | **Только самовывоз «С собой»** (доставки/зала нет) |
| Основной flow | Splash → Город → Точка → (Promo) → Tabs |
| Эквайринг | Alfa-Bank WebView (`COFFEE_MAMA*RBCN`) |
| Auth | Телефон → Telegram / Макс / SMS-код |

## Группы экранов

1. **Onboarding** — splash, город, выбор точки (скроллы списка)
2. **Promo carousel** — франшиза, сторис-бонусы, амбассадоры, соцсети
3. **Меню** — корень категорий, скроллы, категория, SKU-лист, карточка товара, модификаторы
4. **Профиль** — хаб, данные, история, детали заказа, уведомления, о приложении, о компании, другое, жалоба, системная почта
5. **Корзина** — чекаут, комментарий
6. **Заведения** — карта + карточка точки

---

## Полная таблица (каждый файл)

| # | Файл | Экран | Тип | Что реализовано | UI / действия | Заметки для Flutter |
|---|------|-------|-----|-----------------|---------------|---------------------|
| 01 | IMG_1921 | Splash / брендовый старт | splash | Показ логотипа «КОФЕ МАМА», слоганы «заряжен на удачу» / «возьми с собой», паттерн кофейных иллюстраций | Автопереход дальше; без кнопок | `SplashScreen` + brand assets; таймер/preload |
| 02 | IMG_1922 | Выбор города | list + search | Список городов сети + поиск | Поиск «Поиск города»; тап по городу (Ростов-на-Дону, Азов, Сочи) | `CitySelectScreen`; persist city |
| 03 | IMG_1923 | Выбор точки самовывоза (верх списка) | map + list | Карта с пинами + список точек; режим «С собой»; radio-выбор; телефон; часы пн–пт / сб–вс | Back; «С собой»; radio; «Выбрать»; звонок | `VenuePickerScreen`; Yandex/Apple Maps; sync pin↔list |
| 04 | IMG_1924 | Выбор точки (скролл: Борко / Космонавтов / Волкова) | map + list (scroll) | Тот же экран, другая позиция списка | То же | Не отдельный экран — scroll state |
| 05 | IMG_1925 | Выбор точки (скролл: Волкова / Буденновский / Комарова) | map + list (scroll) | Продолжение списка точек | То же | Scroll state |
| 06 | IMG_1926 | Выбор точки (скролл: Космонавтов 19А и др.) | map + list (scroll) | Часы могут быть «пн–вс» единым диапазоном | То же | Модель `WorkingHours` гибкая |
| 07 | IMG_1927 | Выбор точки (скролл: Добровольского / Ворошиловский) | map + list (scroll) | Ещё точки сети | То же | Scroll state |
| 08 | IMG_1928 | Выбор точки (скролл: Королева и др.) | map + list (scroll) | Конец/середина списка | То же | Scroll state |
| 09 | IMG_1929 | Promo #1 — Франшиза (верх) | promo carousel | Баннер киоска; форматы остров/киоск/посадка; выгоды; close | Close (X); dots (4); swipe | `PromoCarouselPage` |
| 10 | IMG_1930 | Promo #1 — Франшиза (низ + CTA) | promo carousel (scroll) | CTA-ссылка Google Form `forms.gle/...` | Open URL; close; dots (активна 2-я?) | `url_launcher` |
| 11 | IMG_1931 | Promo #2 — 100 баллов за сторис | promo carousel | Правила акции: купить → сторис @coffee_mama_rus → скрин в VK → 100 баллов; лимит 3/нед; до 50% оплаты | Close; dots; legal fine print | Promo detail content model |
| 12 | IMG_1932 | Promo #3 — Амбассадоры | promo carousel | Рекрутинг амбассадоров; до 55 000 ₽/сделка; ссылка `ambass.pro/...` | Close; open URL; dots | External link CTA |
| 13 | IMG_1933 | Promo #4 — Соцсети | promo carousel | Призыв подписаться; VK + Instagram ссылки | Close; open VK/IG | Social deep links |
| 14 | IMG_1934 | Меню (верх: доставка-баннер) | tab: menu | Заголовок Меню; лого; «С собой» + адрес; promo доставки Delivery/Яндекс Еда; категории Лимонады / Холодные фирменные | Смена типа заказа; смена точки; тап категории; bottom nav | `MenuHomeScreen` + promo banner carousel |
| 15 | IMG_1935 | Меню + системный звонок | tab: menu + system sheet | Тот же меню с баннером бонусной системы; iOS action sheet «Позвонить +7…» / «Отменить» | Call venue; cancel | `url_launcher` tel: |
| 16 | IMG_1936 | Профиль (верх) | tab: profile | Приветствие; бонусы 129; Мои данные; История; Уведомления; карты; город | Навигация в подэкраны; bottom nav Profile active | `ProfileScreen` |
| 17 | IMG_1937 | Профиль (низ) | tab: profile (scroll) | Карты; город; О приложении; Другое; Сообщите об ошибке; Выход; Удалить аккаунт | Logout; delete account; support | Auth + account deletion flow |
| 18 | IMG_1938 | Мои данные | form / modal | Имя*, телефон, email, дата рождения* | Отмена / Готово; edit fields; date picker | `ProfileEditScreen` |
| 19 | IMG_1939 | История заказов | list | Список заказов: №, статус «Выполнен», сумма, дата/время | Back; open order detail | `OrderHistoryScreen` |
| 20 | IMG_1940 | Детали заказа | detail / modal | №55743; статус; Повторить / Оставить отзыв; состав + модификаторы; готовность; тип; адрес; итого | Repeat order; review; close | `OrderDetailScreen` |
| 21 | IMG_1941 | Уведомления | modal list | Транзакционные (заказ готовится/готов/выдан) + маркетинговые | Close; scroll list | `NotificationsScreen`; типы иконок |
| 22 | IMG_1942 | О приложении | list | «О нас»; телефон поддержки | Back; open about; call | `AboutAppScreen` |
| 23 | IMG_1943 | О компании | modal text | Текст бренда; сайт coffee-mama.ru; кнопка Поддержка (email) | Open site; support | `AboutCompanyScreen` |
| 24 | IMG_1944 | Системная Почта iOS | system | Выбор почтового провайдера после «Поддержка» | Native mail compose | Не UI приложения — интеграция mailto |
| 25 | IMG_1945 | Другое | legal list | Пользовательское соглашение; ПДн; Правила оплаты | Back; open legal docs | `LegalLinksScreen` / WebView |
| 26 | IMG_1946 | Сообщить о проблеме | form / sheet | Текст проблемы; «Отправить» (disabled без текста) | Input; submit; dismiss | `ReportProblemScreen` |
| 27 | IMG_1947 | Меню (баннер сторис) | tab: menu | Поиск; «С собой»+адрес; баннер 100 баллов за сторис; категории | Search; category tap | Search на меню |
| 28 | IMG_1948 | Меню (скролл категорий 1) | tab: menu (scroll) | Лимонады; Холодные фирменные; Кофе и товары; Горячие фирменные | Category navigation | Категории каталога |
| 29 | IMG_1949 | Меню (скролл категорий 2) | tab: menu (scroll) | Горячие фирменные; Детское; Классический кофе; Чаи… | То же | Scroll state |
| 30 | IMG_1950 | Меню (скролл категорий 3) | tab: menu (scroll) | Детское; Классический кофе; Чаи и чайные напитки | То же | Scroll state |
| 31 | IMG_1951 | Категория «Лимонады» (типы) | category list | Подтипы: Лимонад / Айс-ти / Мохито с фото | Back to Меню; open subtype | 2-level category |
| 32 | IMG_1952 | SKU-лист «Лимонад» | product list | Карточки: название, описание, фото, вес, кнопка цены в корзину | Back; add from list; open detail | `ProductListScreen` |
| 33 | IMG_1953 | Карточка товара (простая) | product detail | Лимонад Летний: фото, описание, вес; qty ±; «Добавить» | Qty; add to cart | Без модификаторов |
| 34 | IMG_1954 | Карточка товара (с КБЖУ + опции) | product detail | Холодный Карамельный Латте: КБЖУ; выбор кофе/молока; сброс; qty; цена | Open modifiers; reset; add | Полная PDP |
| 35 | IMG_1955 | Модификатор: кофе | single-select sheet | Без кофеина / Крепкий / Мягкий; «Далее» | Select one; next | Radio modifier step |
| 36 | IMG_1956 | Модификатор: молоко | single-select sheet | Обычное (0₽) + альтернативы +79₽; «Добавить» | Select; price delta; add | Paid modifiers |
| 37 | IMG_1957 | Корзина (пустая) | tab: cart | Тип заказа; ресторан; время самовывоза; промокод; confirm address toggle; комментарий; тип оплаты; ошибка «Вы ничего не выбрали»; Оплатить 0₽ disabled | Edit all checkout fields | `CartCheckoutScreen` + validation |
| 38 | IMG_1958 | Комментарий к заказу | form / sheet | Текст комментария; toggle «сохранять для следующих»; Добавить | Save preference; add | `OrderCommentSheet` |
| 39 | IMG_1959 | Заведения | tab: venues | Full-map; пины; locate me; bottom sheet адреса + телефон | Select pin; call; bottom nav | `VenuesMapScreen` |
| 40 | IMG_1960 | Профиль (гость) | tab: profile guest | «Войти»; город; О приложении; Другое; Сообщите об ошибке | Войти → auth | Guest state |
| 41 | IMG_1961 | Auth: телефон (пусто) | auth | Подтвердите номер; +7 (; Telegram/Макс inactive; keypad | Ввод номера | `AuthPhoneScreen` |
| 42 | IMG_1962 | Auth: телефон (warnings) | auth | Те же + ‼️ номер нельзя изменить после auth; «или» SMS | Каналы confirm | |
| 43 | IMG_1963 | Auth: телефон заполнен | auth | Номер +7 (988)…; Telegram solid; Макс outline; SMS link; legal | Отправка кода | |
| 44 | IMG_1964 | Auth: код из СМС | auth | Телефон + поле «Код из СМС» 0000; «Отправить» | Verify OTP | `AuthCodeScreen` |
| 45 | IMG_1965 | Корзина guest + время | tab: cart | «Вы не вошли»; wheel даты/часа/минуты; промокод; pay disabled | Time picker; login gate | |
| 46 | IMG_1966 | Промокод | sheet | Поле кода; green check; «Отправить» | Apply promo | `PromoCodeSheet` |
| 47 | IMG_1967 | Способ оплаты (пусто) | list | «Добавить карту»; «Выбрать» | Add card | `PaymentMethodScreen` |
| 48 | IMG_1968 | Способ оплаты (карта) | list | Добавить карту + «Карта 2056» checkmark; Выбрать | Select card | |
| 49 | IMG_1969 | Alfa-Bank WebView | external pay | 1 ₽; COFFEE_MAMA*RBCN; номер/имя/ММГГ/CVV; Оплатить | Add/pay card | Эквайринг |
| 50 | IMG_1970 | Отзыв о заказе | sheet | Еда 5★ + Сервис 5★; комментарий; Отправить (disabled); Оценить позднее | Review flow | `OrderReviewSheet` |
| 51 | IMG_1971 | Корзина с товаром | tab: cart | Латте+модификаторы; qty; trash; confirm address off; ошибка поля; badge 1 | Non-empty + validation | |
| 52 | IMG_1972 | Корзина + upsell | tab: cart | «Добавить к заказу?» карусель (чай 99₽); те же валидации | Upsell | |
| 53 | IMG_1973 | Поиск меню | search | Запрос «Лат»; результаты по группам; цены; Отмена | Live search | `MenuSearchScreen` |
| 54 | IMG_1974 | Уведомления (статусы) | modal | подтвержден→готовится→приготовлен→выдан + промо | Status chain | |

---

## Каталог категорий (из меню)

1. Лимонады  
2. Холодные фирменные напитки  
3. Кофе и товары  
4. Горячие фирменные напитки  
5. Детское меню  
6. Классический кофе  
7. Чаи и чайные напитки  

(Возможны ещё ниже fold — на скринах видны эти семь.)

Подтипы лимонадов: Лимонад · Айс-ти · Мохито.

---

## Feature backlog (покрытие функционала)

### Must-have (v1)

- [ ] Splash + brand
- [ ] Выбор города + поиск
- [ ] Выбор точки: карта + список + часы + телефон + «Выбрать»
- [ ] Bottom nav: 4 таба
- [ ] Меню: поиск, тип «С собой», адрес точки, promo banners, категории
- [ ] Категория → подтип → SKU list → PDP
- [ ] Модификаторы (single-select, платные)
- [ ] Корзина: тип, точка, время, промокод, confirm address, комментарий, оплата, pay CTA + empty validation
- [ ] Профиль: бонусы, данные, история, уведомления, карты, город, about, legal, report, logout, delete
- [ ] Заведения: карта + sheet + звонок
- [ ] Повтор заказа / отзыв из деталей заказа
- [ ] Deep links: tel, mailto, https (VK/IG/forms)

### Nice-to-have / content

- [ ] Promo carousel (франшиза / сторис / амбассадоры / соцсети)
- [ ] Баннеры доставки (Яндекс Еда / Delivery) — чаще deep link наружу
- [ ] Сохранение комментария между заказами

### Не UI приложения (системное)

- iOS Mail provider picker (IMG_1944)
- iOS Call action sheet (IMG_1935)

---

## Сущности данных

```text
City { id, name }
Venue { id, cityId, shortName, fullAddress, phone, hours[], lat, lng }
User { name, phone, email?, birthDate?, bonusBalance }
PaymentCard { brand, masked }
Category { id, title, image, children? }
Product { id, categoryId, title, description, weight, price, image, nutrition?, modifiers[] }
ModifierGroup { id, title, required, min, max, options[] }
ModifierOption { id, title, priceDelta }
Cart { venueId, orderType, pickupTime, items[], promo?, comment?, paymentMethodId, addressConfirmed }
Order { id, status, total, createdAt, items[], venue, orderType, readyAt }
Notification { id, type: order|promo, title, body, createdAt }
PromoSlide { id, banner, title, body, ctaUrl?, dotsIndex }
```

---

## User flows (кратко)

```text
Splash → City → VenuePicker → [PromoCarousel?] → Menu
Menu → Category → Subtype → ProductList → PDP → Modifiers → Cart
Profile → (Data | History→Detail | Notifications | About | Other | Report)
Cart → Comment / Promo / Payment / Confirm → Pay
Venues → Pin → Call
```

---

## Дизайн-токены текущего приложения (as-is)

| Токен | Значение |
|-------|----------|
| Background | `#000000` / near-black |
| Accent | teal/cyan ~`#48C4C4` |
| Text primary | white |
| Text secondary | grey |
| Cards | dark grey grouped lists |
| Nav active | teal |
| Danger / error | red (empty cart, confirm address) |
| CTA | full-width rounded teal buttons |

Для редизайна: сохранить функциональную IA, заменить визуальный язык на современный бренд «Кофе Мама» без копирования шумного splash-паттерна 1:1 на все экраны.
