import '../models/city.dart';
import '../models/delivery_task.dart';
import '../models/driver_profile.dart';
import '../models/earnings_summary.dart';
import '../models/vehicle_type.dart';

class DriverMockData {
  static final DriverProfile currentDriver = DriverProfile(
    id: 'DRV-1029',
    name: 'Dawit Tadesse',
    phone: '+251 91 145 6789',
    email: 'dawit.tadesse@amndriver.et',
    avatarUrl:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
    rating: 4.95,
    totalTrips: 342,
    tier: 'Gold Courier',
    vehicle: VehicleInfo(
      type: 'Motorcycle',
      model: 'TVS Apache RTR 160',
      plateNumber: 'ET 3-92814',
      isVerified: true,
    ),
    bankName: 'Commercial Bank of Ethiopia',
    bankAccountNumber: '1000284910294',
    autoAcceptOrders: false,
    navigationApp: 'Google Maps',
  );

  // Active / Primary Delivery (In Progress)
  static final DeliveryTask activeDeliveryTask = DeliveryTask(
    id: 'TSK-9901',
    orderNumber: 'AMN-8492',
    storeName: 'TechHub Express',
    storeCategory: 'Electronics & Gadgets',
    storeAddress: 'Bole Medhanialem Mall, 1st Floor',
    storeDistanceKm: 1.8,
    storePhone: '+251 91 123 4567',
    customerName: 'Abebe Bikila',
    customerPhone: '+251 92 345 6789',
    customerAddress: 'Bole Atlas, Sunshine Bldg Apt 4B',
    customerDistanceKm: 3.5,
    deliveryNotes: 'Leave with building reception/security if not answering.',
    payoutAmount: 280.0,
    tipAmount: 80.0,
    paymentMethod: 'Telebirr',
    items: [
      DeliveryItemCheck(
        name: 'Wireless ANC Earbuds (Midnight Black)',
        quantity: 1,
        unitPrice: 1850.0,
      ),
      DeliveryItemCheck(
        name: 'Braided USB-C Fast Cable 2m',
        quantity: 2,
        unitPrice: 250.0,
      ),
      DeliveryItemCheck(
        name: 'Magnetic Qi2 Fast Car Mount',
        quantity: 1,
        unitPrice: 850.0,
      ),
    ],
    status: DeliveryStatus.headingToStore,
    createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
  );

  // Assigned Deliveries queue
  static List<DeliveryTask> get initialAssignedTasks => [
        activeDeliveryTask,
        DeliveryTask(
          id: 'TSK-9902',
          orderNumber: 'AMN-8504',
          storeName: 'FreshMart Organics',
          storeCategory: 'Grocery & Fresh Foods',
          storeAddress: 'Kazanchis Supermarket, Menelik II Ave',
          storeDistanceKm: 2.4,
          storePhone: '+251 91 234 5678',
          customerName: 'Sara Solomon',
          customerPhone: '+251 91 876 5432',
          customerAddress: 'CMC St. Michael, Palm Residence Block C',
          customerDistanceKm: 5.2,
          deliveryNotes: 'Ring bell twice upon arrival, gated community.',
          payoutAmount: 320.0,
          tipAmount: 90.0,
          paymentMethod: 'Telebirr',
          items: [
            DeliveryItemCheck(
              name: 'Organic Hass Avocado (Pack of 4)',
              quantity: 1,
              unitPrice: 340.0,
            ),
            DeliveryItemCheck(
              name: 'Ethiopian Highland Arabica Roast 500g',
              quantity: 2,
              unitPrice: 310.0,
            ),
            DeliveryItemCheck(
              name: 'Sourdough Artisan Country Loaf',
              quantity: 1,
              unitPrice: 180.0,
            ),
            DeliveryItemCheck(
              name: 'Organic Wildflower Honey Jar 500g',
              quantity: 1,
              unitPrice: 450.0,
            ),
          ],
          status: DeliveryStatus.assigned,
          createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
        DeliveryTask(
          id: 'TSK-9903',
          orderNumber: 'AMN-8519',
          storeName: 'Burger Foundry',
          storeCategory: 'Burgers & Grill',
          storeAddress: 'Sarbet, South Africa Embassy Rd',
          storeDistanceKm: 3.1,
          storePhone: '+251 91 345 6789',
          customerName: 'Yonas Kebede',
          customerPhone: '+251 93 456 7890',
          customerAddress: 'Old Airport, Golf Club Rd Villa 12',
          customerDistanceKm: 4.8,
          deliveryNotes: 'Please request extra napkins from the counter.',
          payoutAmount: 210.0,
          tipAmount: 50.0,
          paymentMethod: 'CBE Birr',
          items: [
            DeliveryItemCheck(
              name: 'Double Smash Bacon Cheeseburger',
              quantity: 2,
              unitPrice: 480.0,
            ),
            DeliveryItemCheck(
              name: 'Truffle Parmesan Crispy Fries',
              quantity: 1,
              unitPrice: 220.0,
            ),
            DeliveryItemCheck(
              name: 'Cold Brew Vanilla Iced Coffee',
              quantity: 2,
              unitPrice: 160.0,
            ),
          ],
          status: DeliveryStatus.assigned,
          createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
        ),
        DeliveryTask(
          id: 'TSK-9904',
          orderNumber: 'AMN-8532',
          storeName: 'CareFirst Pharmacy',
          storeCategory: 'Health & Pharmacy',
          storeAddress: 'Gerji, Imperial Traffic Light area',
          storeDistanceKm: 4.0,
          storePhone: '+251 91 456 7890',
          customerName: 'Selamawit Hailu',
          customerPhone: '+251 94 567 8901',
          customerAddress: 'Bole Bulbula, Mariam Church area',
          customerDistanceKm: 6.1,
          deliveryNotes: 'Fragile medicine pack. Handle with care.',
          payoutAmount: 190.0,
          tipAmount: 40.0,
          paymentMethod: 'Cash on Delivery',
          items: [
            DeliveryItemCheck(
              name: 'Vitamin C + Zinc Effervescent 20s',
              quantity: 2,
              unitPrice: 380.0,
            ),
            DeliveryItemCheck(
              name: 'First Aid Antiseptic Wound Spray 150ml',
              quantity: 1,
              unitPrice: 240.0,
            ),
          ],
          status: DeliveryStatus.assigned,
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ];

  // Complete Past Deliveries History
  static List<DeliveryTask> get completedHistoryTasks => [
        DeliveryTask(
          id: 'TSK-9880',
          orderNumber: 'AMN-8420',
          storeName: 'FreshMart Organics',
          storeCategory: 'Grocery & Fresh Foods',
          storeAddress: 'Kazanchis Supermarket, Menelik II Ave',
          storeDistanceKm: 2.1,
          customerName: 'Kalkidan Tsegaye',
          customerPhone: '+251 91 567 8912',
          customerAddress: 'Kazanchis, UNECA Main Gate',
          customerDistanceKm: 2.8,
          payoutAmount: 320.0,
          tipAmount: 90.0,
          paymentMethod: 'Telebirr',
          items: [
            DeliveryItemCheck(
              name: 'Organic Strawberry 500g',
              quantity: 2,
              unitPrice: 220.0,
              isChecked: true,
            ),
            DeliveryItemCheck(
              name: 'Whole Almond Milk 1L',
              quantity: 2,
              unitPrice: 190.0,
              isChecked: true,
            ),
          ],
          status: DeliveryStatus.delivered,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          completedAt:
              DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
        ),
        DeliveryTask(
          id: 'TSK-9875',
          orderNumber: 'AMN-8399',
          storeName: 'Burger Foundry',
          storeCategory: 'Burgers & Grill',
          storeAddress: 'Sarbet, South Africa Embassy Rd',
          storeDistanceKm: 1.5,
          customerName: 'Blen Assefa',
          customerPhone: '+251 92 678 9123',
          customerAddress: 'Sarbet, South Africa Embassy Rd Apt 2',
          customerDistanceKm: 2.2,
          payoutAmount: 210.0,
          tipAmount: 50.0,
          paymentMethod: 'CBE Birr',
          items: [
            DeliveryItemCheck(
              name: 'Crispy Chicken Burger Meal',
              quantity: 1,
              unitPrice: 380.0,
              isChecked: true,
            ),
            DeliveryItemCheck(
              name: 'Mineral Water 500ml',
              quantity: 1,
              unitPrice: 40.0,
              isChecked: true,
            ),
          ],
          status: DeliveryStatus.delivered,
          createdAt: DateTime.now().subtract(const Duration(hours: 4, minutes: 30)),
          completedAt:
              DateTime.now().subtract(const Duration(hours: 3, minutes: 40)),
        ),
        DeliveryTask(
          id: 'TSK-9870',
          orderNumber: 'AMN-8350',
          storeName: 'CareFirst Pharmacy',
          storeCategory: 'Health & Pharmacy',
          storeAddress: 'Gerji, Imperial Traffic Light',
          storeDistanceKm: 2.9,
          customerName: 'Ermias Desta',
          customerPhone: '+251 93 789 0124',
          customerAddress: 'Gerji, Imperial area, House 42',
          customerDistanceKm: 3.6,
          payoutAmount: 190.0,
          tipAmount: 40.0,
          paymentMethod: 'Telebirr',
          items: [
            DeliveryItemCheck(
              name: 'Multivitamin Formula Capsules 60s',
              quantity: 1,
              unitPrice: 650.0,
              isChecked: true,
            ),
          ],
          status: DeliveryStatus.delivered,
          createdAt: DateTime.now().subtract(const Duration(hours: 6)),
          completedAt:
              DateTime.now().subtract(const Duration(hours: 5, minutes: 10)),
        ),
        DeliveryTask(
          id: 'TSK-9862',
          orderNumber: 'AMN-8310',
          storeName: 'Bloom & Petal Florist',
          storeCategory: 'Gifts & Flowers',
          storeAddress: 'Bole Medhanialem, Edna Mall Rd',
          storeDistanceKm: 3.4,
          customerName: 'Martha Lemma',
          customerPhone: '+251 94 890 1235',
          customerAddress: 'Old Airport, Golf Club Rd Villa 8',
          customerDistanceKm: 6.7,
          payoutAmount: 380.0,
          tipAmount: 120.0,
          paymentMethod: 'Telebirr',
          items: [
            DeliveryItemCheck(
              name: 'Red Roses Deluxe Bouquet (24 stems)',
              quantity: 1,
              unitPrice: 1600.0,
              isChecked: true,
            ),
            DeliveryItemCheck(
              name: 'Handwritten Greeting Note Card',
              quantity: 1,
              unitPrice: 150.0,
              isChecked: true,
            ),
          ],
          status: DeliveryStatus.delivered,
          createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
          completedAt:
              DateTime.now().subtract(const Duration(days: 1, hours: 1)),
        ),
        DeliveryTask(
          id: 'TSK-9855',
          orderNumber: 'AMN-8290',
          storeName: 'TechHub Express',
          storeCategory: 'Electronics & Gadgets',
          storeAddress: 'Bole Medhanialem Mall',
          storeDistanceKm: 1.2,
          customerName: 'Nahom Berhanu',
          customerPhone: '+251 91 901 2346',
          customerAddress: '22 Mazoria, Lex Plaza 3rd Floor',
          customerDistanceKm: 2.9,
          payoutAmount: 260.0,
          tipAmount: 60.0,
          paymentMethod: 'Telebirr',
          items: [
            DeliveryItemCheck(
              name: 'Wireless Bluetooth Mouse',
              quantity: 1,
              unitPrice: 750.0,
              isChecked: true,
            ),
          ],
          status: DeliveryStatus.delivered,
          createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
          completedAt:
              DateTime.now().subtract(const Duration(days: 1, hours: 3, minutes: 15)),
        ),
        DeliveryTask(
          id: 'TSK-9840',
          orderNumber: 'AMN-8245',
          storeName: 'Habesha Coffee Roasters',
          storeCategory: 'Cafe & Beverage',
          storeAddress: 'Meskel Flower, Dreamliner Rd',
          storeDistanceKm: 2.0,
          customerName: 'Fasika Girma',
          customerPhone: '+251 92 012 3457',
          customerAddress: 'Gotera, Condominium Block 18',
          customerDistanceKm: 3.8,
          payoutAmount: 200.0,
          tipAmount: 40.0,
          paymentMethod: 'CBE Birr',
          items: [
            DeliveryItemCheck(
              name: 'Dark Roast Yirgacheffe Beans 1kg',
              quantity: 1,
              unitPrice: 780.0,
              isChecked: true,
            ),
          ],
          status: DeliveryStatus.delivered,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          completedAt:
              DateTime.now().subtract(const Duration(days: 2, hours: -1)),
        ),
      ];

  static final EarningsSummary mockEarnings = EarningsSummary(
    availableBalance: 4850.00,
    todayEarnings: 1420.50,
    todayDeliveries: 8,
    todayOnlineHours: 6.5,
    todayTips: 320.00,
    weeklyBreakdown: [
      DailyEarning(dayName: 'Mon', amount: 1100.00, tripCount: 6),
      DailyEarning(dayName: 'Tue', amount: 1350.00, tripCount: 8),
      DailyEarning(dayName: 'Wed', amount: 980.00, tripCount: 5),
      DailyEarning(dayName: 'Thu', amount: 1600.00, tripCount: 9),
      DailyEarning(dayName: 'Fri', amount: 1950.00, tripCount: 11),
      DailyEarning(dayName: 'Sat', amount: 2200.00, tripCount: 13),
      DailyEarning(dayName: 'Sun', amount: 1420.50, tripCount: 8),
    ],
    recentCompleted: [
      CompletedDeliveryRecord(
        orderNumber: 'AMN-8420',
        storeName: 'FreshMart Organics',
        destinationArea: 'Kazanchis, UNECA Gate',
        payoutAmount: 320.00,
        tipAmount: 90.00,
        completedAt:
            DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
        task: completedHistoryTasks[0],
      ),
      CompletedDeliveryRecord(
        orderNumber: 'AMN-8399',
        storeName: 'Burger Foundry',
        destinationArea: 'Sarbet, South Africa Embassy Rd',
        payoutAmount: 210.00,
        tipAmount: 50.00,
        completedAt:
            DateTime.now().subtract(const Duration(hours: 3, minutes: 40)),
        task: completedHistoryTasks[1],
      ),
      CompletedDeliveryRecord(
        orderNumber: 'AMN-8350',
        storeName: 'CareFirst Pharmacy',
        destinationArea: 'Gerji, Imperial area',
        payoutAmount: 190.00,
        tipAmount: 40.00,
        completedAt:
            DateTime.now().subtract(const Duration(hours: 5, minutes: 10)),
        task: completedHistoryTasks[2],
      ),
      CompletedDeliveryRecord(
        orderNumber: 'AMN-8310',
        storeName: 'Bloom & Petal Florist',
        destinationArea: 'Old Airport, Golf Club Rd',
        payoutAmount: 380.00,
        tipAmount: 120.00,
        completedAt: DateTime.now().subtract(const Duration(days: 1)),
        task: completedHistoryTasks[3],
      ),
    ],
  );

  // Backward compatibility getter
  static DeliveryTask get sampleIncomingOffer => activeDeliveryTask;

  // Fallback vehicle types matching backend
  static final List<VehicleTypeModel> mockVehicleTypes = [
    const VehicleTypeModel(
      id: 1,
      name: 'MoterBick',
      image: 'https://api.amnplc.com/assets/images (78).jpeg',
      status: '1',
    ),
    const VehicleTypeModel(
      id: 2,
      name: 'Car / Van',
      image: 'https://api.amnplc.com/assets/images (79).jpeg',
      status: '1',
    ),
    const VehicleTypeModel(
      id: 3,
      name: 'Bicycle',
      image: 'https://api.amnplc.com/assets/images (80).jpeg',
      status: '1',
    ),
  ];

  // Fallback cities matching backend
  static final List<CityModel> mockCities = [
    const CityModel(id: 1, name: 'Addis Ababa', status: '1'),
    const CityModel(id: 2, name: 'Hawassa', status: '1'),
    const CityModel(id: 4, name: 'Harar', status: '1'),
    const CityModel(id: 5, name: 'Mizan Teferi', status: '1'),
    const CityModel(id: 6, name: 'Dilla', status: '1'),
    const CityModel(id: 7, name: 'united Arab Emirates', status: '1'),
    const CityModel(id: 8, name: 'Turkey', status: '1'),
    const CityModel(id: 9, name: 'Uganda', status: '1'),
    const CityModel(id: 10, name: 'Bahir Dar', status: '1'),
    const CityModel(id: 11, name: 'Debrebirhan', status: '1'),
    const CityModel(id: 12, name: 'shashamene', status: '1'),
    const CityModel(id: 13, name: 'jijiga', status: '1'),
    const CityModel(id: 14, name: 'Dire dewa', status: '1'),
    const CityModel(id: 15, name: 'Adama', status: '1'),
    const CityModel(id: 16, name: 'Bishoftu', status: '1'),
    const CityModel(id: 17, name: 'Djibouti', status: '1'),
  ];
}
