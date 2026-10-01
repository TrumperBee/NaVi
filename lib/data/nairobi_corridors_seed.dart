import 'package:latlong2/latlong.dart';
import 'package:navi_app/models/fare_estimate.dart';

class CorridorData {
  final String id;
  final String name;
  final List<LatLng> polyline;
  final String primaryDirection;
  final FareTier fareTier;
  final List<String> routeNumbers;

  const CorridorData({
    required this.id,
    required this.name,
    required this.polyline,
    required this.primaryDirection,
    required this.fareTier,
    required this.routeNumbers,
  });
}

const Map<int, CorridorData> nairobiCorridors = {
  1: CorridorData(
    id: 'ngong_road',
    name: 'Ngong Road',
    primaryDirection: 'north-south',
    fareTier: FareTier.medium,
    routeNumbers: ['111', '24', '110', '125', '126', '5'],
    polyline: [
      LatLng(-1.2833, 36.8167), // CBD Kencom
      LatLng(-1.2860, 36.8120), // Nyayo House
      LatLng(-1.2895, 36.8085), // Railways
      LatLng(-1.2930, 36.8050), // Upper Hill
      LatLng(-1.2965, 36.8015), // Community
      LatLng(-1.3000, 36.7980), // Adams Arcade
      LatLng(-1.3035, 36.7945), // Prestige
      LatLng(-1.3070, 36.7910), // Ngong Road Hospital
      LatLng(-1.3105, 36.7875), // Dagoretti Corner
      LatLng(-1.3140, 36.7840), // Karen turnoff
      LatLng(-1.3175, 36.7805), // Langata junction
      LatLng(-1.3210, 36.7770), // Langata
      LatLng(-1.3250, 36.7730), // Bomas
      LatLng(-1.3300, 36.7680), // Hardy
    ],
  ),
  2: CorridorData(
    id: 'thika_road',
    name: 'Thika Road',
    primaryDirection: 'north-south',
    fareTier: FareTier.long,
    routeNumbers: ['44', '45', '145', '146', '147'],
    polyline: [
      LatLng(-1.2833, 36.8167), // CBD Kencom
      LatLng(-1.2780, 36.8220), // Museum Hill
      LatLng(-1.2720, 36.8280), // Pangani
      LatLng(-1.2660, 36.8340), // Muthaiga
      LatLng(-1.2600, 36.8400), // Allsops
      LatLng(-1.2540, 36.8460), // TRM
      LatLng(-1.2480, 36.8520), // Garden City
      LatLng(-1.2420, 36.8580), // Kasarani
      LatLng(-1.2360, 36.8640), // Roysambu
      LatLng(-1.2300, 36.8700), // Zimmerman
      LatLng(-1.2240, 36.8760), // Githurai 44
      LatLng(-1.2180, 36.8820), // Githurai 45
      LatLng(-1.2120, 36.8880), // Mwiki
      LatLng(-1.2060, 36.8940), // Ruiru
    ],
  ),
  3: CorridorData(
    id: 'waiyaki_way',
    name: 'Waiyaki Way',
    primaryDirection: 'northwest-southeast',
    fareTier: FareTier.medium,
    routeNumbers: ['105', '106', '107'],
    polyline: [
      LatLng(-1.2833, 36.8167), // CBD Kencom
      LatLng(-1.2800, 36.8140), // OTC
      LatLng(-1.2765, 36.8115), // Museum Hill
      LatLng(-1.2730, 36.8090), // Westlands Roundabout
      LatLng(-1.2695, 36.8065), // Westlands
      LatLng(-1.2660, 36.8040), // Chiromo
      LatLng(-1.2625, 36.8015), // Deep Sea
      LatLng(-1.2590, 36.7990), // Kangemi
      LatLng(-1.2555, 36.7965), // Kitisuru
      LatLng(-1.2520, 36.7940), // Limuru Road junction
    ],
  ),
  4: CorridorData(
    id: 'jogoo_road',
    name: 'Jogoo Road',
    primaryDirection: 'east-west',
    fareTier: FareTier.short,
    routeNumbers: ['58', '10', '34'],
    polyline: [
      LatLng(-1.2833, 36.8167), // CBD Kencom
      LatLng(-1.2855, 36.8210), // Commercial
      LatLng(-1.2880, 36.8260), // Landhies Road
      LatLng(-1.2905, 36.8310), // Makadara
      LatLng(-1.2930, 36.8360), // Hamza
      LatLng(-1.2955, 36.8410), // Burma
      LatLng(-1.2980, 36.8460), // Jogoo Road / Outering
      LatLng(-1.3005, 36.8510), // Buru Buru
      LatLng(-1.3030, 36.8560), // Umoja
      LatLng(-1.3055, 36.8610), // Embakasi
      LatLng(-1.3080, 36.8660), // Pipeline
      LatLng(-1.3105, 36.8710), // Imara Daima
    ],
  ),
  5: CorridorData(
    id: 'mombasa_road',
    name: 'Mombasa Road',
    primaryDirection: 'east-west',
    fareTier: FareTier.long,
    routeNumbers: ['33', '34', '35'],
    polyline: [
      LatLng(-1.2833, 36.8167), // CBD Kencom
      LatLng(-1.2870, 36.8220), // Nyayo Stadium
      LatLng(-1.2910, 36.8280), // Bellevue
      LatLng(-1.2950, 36.8340), // Airport North
      LatLng(-1.2990, 36.8400), // JKIA
      LatLng(-1.3030, 36.8460), // Imara Daima
      LatLng(-1.3070, 36.8520), // Syokimau turnoff
      LatLng(-1.3110, 36.8580), // Mlolongo
      LatLng(-1.3150, 36.8640), // Athi River
    ],
  ),
  6: CorridorData(
    id: 'langata_road',
    name: "Lang'ata Road",
    primaryDirection: 'southwest',
    fareTier: FareTier.medium,
    routeNumbers: ['125', '126', '5'],
    polyline: [
      LatLng(-1.2950, 36.7950), // Ngong Road / Langata junction
      LatLng(-1.3000, 36.7890), // Bomas
      LatLng(-1.3050, 36.7830), // Langata
      LatLng(-1.3100, 36.7770), // Nairobi National Park gate
      LatLng(-1.3150, 36.7710), // Carnivore
      LatLng(-1.3200, 36.7650), // Wilson Airport
      LatLng(-1.3250, 36.7590), // KWS Headquarters
      LatLng(-1.3300, 36.7530), // Magadi Road junction
    ],
  ),
  7: CorridorData(
    id: 'outering_road',
    name: 'Outering Road',
    primaryDirection: 'north-south',
    fareTier: FareTier.medium,
    routeNumbers: ['147', '44', '58', '34', '35'],
    polyline: [
      LatLng(-1.2600, 36.8800), // Allsops / Thika Road
      LatLng(-1.2660, 36.8780), // Donholm
      LatLng(-1.2720, 36.8760), // Kayole
      LatLng(-1.2780, 36.8740), // Komarock
      LatLng(-1.2840, 36.8720), // Umoja
      LatLng(-1.2900, 36.8700), // Jogoo Road / Outering
      LatLng(-1.2960, 36.8680), // Tassia
      LatLng(-1.3020, 36.8660), // Embakasi
      LatLng(-1.3080, 36.8640), // Imara Daima
    ],
  ),
  8: CorridorData(
    id: 'cbd',
    name: 'Nairobi CBD',
    primaryDirection: 'city-center',
    fareTier: FareTier.short,
    routeNumbers: ['44', '45', '111', '24', '58', '10', '110', '114', '33', '34', '35', '112'],
    polyline: [
      LatLng(-1.2800, 36.8133), // Tea Room
      LatLng(-1.2825, 36.8150), // OTC
      LatLng(-1.2833, 36.8167), // Kencom
      LatLng(-1.2835, 36.8210), // Commercial Terminus
      LatLng(-1.2850, 36.8183), // Ambassadeur
      LatLng(-1.2875, 36.8200), // Railways
      LatLng(-1.2805, 36.8162), // Chiromo Library
      LatLng(-1.2798, 36.8158), // Millennium Hall 2
      LatLng(-1.2795, 36.8155), // Millennium Hall 1
    ],
  ),
};