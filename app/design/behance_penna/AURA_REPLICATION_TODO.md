# План переноса

1. Согласовать scope первого прохода: welcome, каталог, PDP и корзина — рекомендованный MVP.
2. Вынести light/dark palette, spacing и radii в `app/lib/core/theme` без изменения сетевых контрактов.
3. Привести `menu_screen.dart` и `category_screen.dart` к header → search → chips → grid → floating cart.
4. Перестроить `product_screen.dart` как image-first PDP с нижним sheet, сохранив размеры и modifier groups.
5. Перестроить `cart_screen.dart` в компактные строки, recommendation rail и отдельный checkout summary.
6. Заменить mock/legacy imagery только на собственные approved Object Storage images или локальные approved assets.
7. Сделать переключатель темы только после того, как light-версия будет совпадать по иерархии.
8. Вручную проверить 375×812, 768×1024, 1440×900, длинные русские названия, пустую корзину и сетевую ошибку.

## Не включать без отдельного решения

- Не заменять Jannat/Кофе брендинг на «пенна».
- Не менять API, модель заказа или цены ради визуального рефакторинга.
- Не использовать фото и логотипы автора в релизе.

