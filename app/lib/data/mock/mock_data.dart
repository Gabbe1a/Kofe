import '../models/models.dart';

abstract final class MockData {
  static const cities = [
    City(id: 'rnd', name: 'Ростов-на-Дону'),
    City(id: 'azov', name: 'Азов'),
    City(id: 'sochi', name: 'Сочи'),
  ];

  static final venues = [
    Venue(
      id: 'v1',
      cityId: 'rnd',
      shortName: 'пр-кт Нагибина, 35а',
      fullAddress: 'Ростов-на-Дону, пр-кт Михаила Нагибина, д. 35а',
      phone: '+7 (995) 549-80-83',
      lat: 47.2593653,
      lng: 39.7170379,
      hours: const [
        VenueHours(daysLabel: 'пн-пт', open: '07:00', close: '00:00'),
        VenueHours(daysLabel: 'сб-вс', open: '08:00', close: '00:00'),
      ],
    ),
    Venue(
      id: 'v2',
      cityId: 'rnd',
      shortName: 'ул. Борко, 3/1',
      fullAddress: 'Ростов-на-Дону, ул. Борко, д. 3/1',
      phone: '+7 (928) 778-49-26',
      lat: 47.2806583,
      lng: 39.7059767,
      hours: const [
        VenueHours(daysLabel: 'пн-вс', open: '07:00', close: '23:00'),
      ],
    ),
    Venue(
      id: 'v3',
      cityId: 'rnd',
      shortName: 'Добровольского, 15',
      fullAddress: 'Ростов-на-Дону, ул. Добровольского, д. 15',
      phone: '+7 (952) 573-94-58',
      lat: 47.2935105,
      lng: 39.7023244,
      hours: const [
        VenueHours(daysLabel: 'пн-пт', open: '07:00', close: '00:00'),
        VenueHours(daysLabel: 'сб-вс', open: '08:00', close: '00:00'),
      ],
    ),
    Venue(
      id: 'v4',
      cityId: 'azov',
      shortName: 'Петровский бульвар, 4',
      fullAddress: 'Азов, Петровский бульвар, д. 4кГ',
      phone: '+7 (960) 466-88-87',
      lat: 47.1119008,
      lng: 39.4222864,
      hours: const [
        VenueHours(daysLabel: 'пн-вс', open: '08:00', close: '22:00'),
      ],
    ),
    Venue(
      id: 'v5',
      cityId: 'sochi',
      shortName: 'ул. Навагинская, 9Д',
      fullAddress: 'Сочи, ул. Навагинская, д. 9Д',
      phone: '+7 (961) 430-77-77',
      lat: 43.5882194,
      lng: 39.7234692,
      hours: const [
        VenueHours(daysLabel: 'пн-вс', open: '08:00', close: '23:00'),
      ],
    ),
  ];

  static const categories = [
    Category(id: 'coffee', title: 'Классический кофе'),
    Category(id: 'signature_cold', title: 'Холодные фирменные'),
    Category(id: 'signature_hot', title: 'Горячие фирменные'),
    Category(id: 'lemonades', title: 'Лимонады'),
    Category(id: 'tea', title: 'Чаи и чайные напитки'),
    Category(id: 'kids', title: 'Детское меню'),
    Category(id: 'goods', title: 'Кофе и товары'),
  ];

  /// Home category chord — coffee-only IA (no bakery).
  static const arcCategories = [
    ('coffee', 'Кофе'),
    ('signature_cold', 'Холодные'),
    ('tea', 'Чаи'),
    ('signature_hot', 'Авторские'),
  ];

  static final coffeeMods = [
    ModifierGroup(
      id: 'coffee_blend',
      title: 'Выберите кофе',
      options: const [
        ModifierOption(id: 'decaf', title: 'Без кофеина'),
        ModifierOption(id: 'strong', title: 'Крепкий (70% арабика / 30% робуста)'),
        ModifierOption(id: 'mild', title: 'Мягкий (100% арабика)', isDefault: true),
      ],
    ),
    ModifierGroup(
      id: 'milk',
      title: 'Выберите молоко',
      options: const [
        ModifierOption(id: 'almond', title: 'Молоко миндальное', priceDelta: 79),
        ModifierOption(id: 'coconut', title: 'Молоко кокосовое', priceDelta: 79),
        ModifierOption(id: 'lactose_free', title: 'Молоко безлактозное', priceDelta: 79),
        ModifierOption(id: 'banana', title: 'Молоко банановое', priceDelta: 79),
        ModifierOption(id: 'regular', title: 'Молоко', isDefault: true),
        ModifierOption(id: 'pistachio', title: 'Молоко фисташковое', priceDelta: 79),
      ],
    ),
    ModifierGroup(
      id: 'syrup',
      title: 'Выберите сироп',
      required: false,
      options: const [
        ModifierOption(id: 'banana', title: 'Банан', priceDelta: 40),
        ModifierOption(id: 'vanilla', title: 'Ваниль', priceDelta: 40),
        ModifierOption(id: 'caramel', title: 'Карамель', priceDelta: 40),
        ModifierOption(id: 'coconut', title: 'Кокос', priceDelta: 40),
        ModifierOption(id: 'cherry', title: 'Вишня', priceDelta: 40),
      ],
    ),
  ];

  static final products = [
    Product(
      id: 'p_caramel',
      categoryId: 'signature_cold',
      title: 'Карамельный фраппучино',
      description:
          'Холодный кофе со взбитыми сливками и карамельным топпингом. Фирменный вкус «Кофе Мама».',
      price: 349,
      imageAsset: 'assets/images/products/caramel_frappe_cutout.png',
      weightLabel: '400 мл',
      featured: true,
      sizes: const [
        ProductSize(id: 's', label: 'S', ml: 300),
        ProductSize(id: 'm', label: 'M', ml: 400, priceDelta: 40),
        ProductSize(id: 'l', label: 'L', ml: 500, priceDelta: 80),
      ],
      nutrition: const Nutrition(
        weightG: 400,
        proteins: 2.1,
        fats: 8.4,
        carbs: 42,
        kcal: 248,
      ),
      modifierGroups: coffeeMods,
    ),
    Product(
      id: 'p_bottle',
      categoryId: 'signature_cold',
      title: 'Айс-латте в бутылке',
      description: 'Холодный латте со слоями молока и эспрессо. Удобно взять с собой.',
      price: 289,
      imageAsset: 'assets/images/products/iced_latte_cutout.png',
      weightLabel: '350 мл',
      featured: true,
      sizes: const [
        ProductSize(id: 'm', label: 'M', ml: 350),
      ],
      modifierGroups: coffeeMods,
    ),
    Product(
      id: 'p_matcha',
      categoryId: 'tea',
      title: 'Ледяная матча латте',
      description: 'Матча на молоке со льдом. Мягкий зелёный вкус без горечи.',
      price: 329,
      imageAsset: 'assets/images/products/matcha_latte_cutout.png',
      weightLabel: '400 мл',
      featured: true,
      sizes: const [
        ProductSize(id: 'm', label: 'M', ml: 400),
        ProductSize(id: 'l', label: 'L', ml: 500, priceDelta: 50),
      ],
    ),
    Product(
      id: 'p_lemon',
      categoryId: 'lemonades',
      title: 'Лимонад Классический',
      description:
          'Освежающий напиток со льдом на основе газировки «Лимон-лайм».',
      price: 250,
      imageAsset: 'assets/images/products/lemonade_cutout.png',
      weightLabel: '400 мл',
      featured: true,
    ),
    Product(
      id: 'p_peach_tea',
      categoryId: 'lemonades',
      title: 'Айс-ти Персик',
      description: 'Холодный чай с персиком и мятой.',
      price: 270,
      imageAsset: 'assets/images/products/peach_tea_cutout.png',
      weightLabel: '400 мл',
    ),
    Product(
      id: 'p_mojito',
      categoryId: 'lemonades',
      title: 'Мохито б/а',
      description: 'Безалкогольный мохито с лаймом и мятой.',
      price: 290,
      imageAsset: 'assets/images/products/mojito_cutout.png',
      weightLabel: '400 мл',
    ),
    Product(
      id: 'p_berry_mix',
      categoryId: 'lemonades',
      title: 'Ягодный микс',
      description: 'Ягодный лимонад со свежими ягодами.',
      price: 280,
      imageAsset: 'assets/images/products/lemonade_cutout.png',
      weightLabel: '400 мл',
    ),
    Product(
      id: 'p_capp',
      categoryId: 'coffee',
      title: 'Капучино',
      description: 'Классический капучино на эспрессо с молочной пеной.',
      price: 259,
      imageAsset: 'assets/images/products/cappuccino_cutout.png',
      weightLabel: '300 мл',
      sizes: const [
        ProductSize(id: 's', label: 'S', ml: 250),
        ProductSize(id: 'm', label: 'M', ml: 300, priceDelta: 30),
        ProductSize(id: 'l', label: 'L', ml: 400, priceDelta: 60),
      ],
      nutrition: const Nutrition(
        weightG: 300,
        proteins: 1.3,
        fats: 1.3,
        carbs: 16.8,
        kcal: 84,
      ),
      modifierGroups: coffeeMods,
    ),
    Product(
      id: 'p_raf',
      categoryId: 'signature_hot',
      title: 'Авторский раф',
      description:
          'Горячий фирменный раф на эспрессо со сливками и ванилью. Мягкий сливочный вкус.',
      price: 319,
      imageAsset: 'assets/images/products/cappuccino_cutout.png',
      weightLabel: '300 мл',
      featured: true,
      sizes: const [
        ProductSize(id: 's', label: 'S', ml: 250),
        ProductSize(id: 'm', label: 'M', ml: 300, priceDelta: 30),
        ProductSize(id: 'l', label: 'L', ml: 400, priceDelta: 60),
      ],
      modifierGroups: coffeeMods,
    ),
    Product(
      id: 'p_croissant',
      categoryId: 'goods',
      title: 'Круассан шоколадный',
      description: 'Свежая выпечка к кофе. Хрустящий круассан с шоколадом.',
      price: 149,
      imageAsset: 'assets/images/products/croissant_cutout.png',
      weightLabel: '80 г',
    ),
  ];

  static final promoSlides = [
    const PromoSlide(
      id: '1',
      title: 'Франшиза кофейни',
      body:
          'Станьте партнёром сети «Кофе Мама». Форматы: остров от 1,3 млн ₽, киоск от 1,4 млн ₽, кофейня с посадкой от 2,3 млн ₽.',
      ctaUrl: 'https://forms.gle/wswAJZ7mwcumbE5e7',
      imageAsset: 'assets/images/promo/promo_01.png',
    ),
    const PromoSlide(
      id: '2',
      title: '100 баллов за сторис',
      body:
          'Купите напиток, отметьте @coffee_mama_rus в сторис, отправьте скрин в VK — получите 100 бонусов. До 3 раз в неделю.',
      imageAsset: 'assets/images/promo/promo_02.png',
    ),
    const PromoSlide(
      id: '3',
      title: 'Стань амбассадором',
      body: 'Делитесь франшизой и получайте до 55 000 ₽ за сделку.',
      ctaUrl: 'https://ambass.pro/p/729994',
      imageAsset: 'assets/images/promo/promo_03.png',
    ),
    const PromoSlide(
      id: '4',
      title: 'Мы в соцсетях',
      body: 'Меню, сезонные напитки и новости сети — VK и Instagram.',
      ctaUrl: 'https://vk.com/coffeemama161',
      imageAsset: 'assets/images/promo/promo_04.png',
    ),
  ];

  static final notifications = [
    AppNotification(
      id: 'n1',
      type: 'order',
      title: 'Заказ 55743',
      body: 'Табунщиков, Ваш заказ №55743 приготовлен.',
      createdAt: DateTime(2026, 6, 27, 8, 45),
      orderId: '55743',
    ),
    AppNotification(
      id: 'n2',
      type: 'order',
      title: 'Заказ 55743',
      body: 'Табунщиков, Ваш заказ №55743 готовится.',
      createdAt: DateTime(2026, 6, 27, 8, 42),
      orderId: '55743',
    ),
    AppNotification(
      id: 'n3',
      type: 'promo',
      title: 'Оставь машину',
      body: 'Гуляй! Пей кофе. Наслаждайся жизнью.',
      createdAt: DateTime(2026, 6, 26, 20, 2),
    ),
    AppNotification(
      id: 'n4',
      type: 'order',
      title: 'Заказ 18206',
      body: 'Заказ №18206 выдан.',
      createdAt: DateTime(2026, 6, 25, 9, 58),
      orderId: '18206',
    ),
  ];

  static final orders = [
    OrderSummary(
      id: '55743',
      status: 'Выполнен',
      total: 349,
      createdAt: DateTime(2026, 6, 27, 8, 57),
      summaryLine: 'Карамельный фраппучино',
      venueId: 'v2',
    ),
    OrderSummary(
      id: '18206',
      status: 'Выполнен',
      total: 289,
      createdAt: DateTime(2026, 6, 25, 9, 10),
      summaryLine: 'Капучино 300мл',
      venueId: 'v1',
    ),
  ];

  static final demoUser = UserProfile(
    name: 'Табунщиков Михаил',
    phone: '+7 (988) 342-99-00',
    birthDate: DateTime(2004, 3, 9),
    bonusBalance: 129,
  );

  static Product productById(String id) =>
      products.firstWhere((p) => p.id == id);

  static List<Venue> venuesForCity(String cityId) =>
      venues.where((v) => v.cityId == cityId).toList();

  static List<Product> productsForCategory(String categoryId) =>
      products.where((p) => p.categoryId == categoryId).toList();

  static List<Product> featured() =>
      products.where((p) => p.featured).toList();

  static List<Product> search(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return products;
    return products
        .where(
          (p) =>
              p.title.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query),
        )
        .toList();
  }
}
