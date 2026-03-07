import '../models/route_model.dart';
import '../models/stage_model.dart';

class SeedData {
  // Nairobi CBD and Metropolitan area coordinates - 2026 Updated Termini
  static const Map<String, Map<String, double>> nairobiCoordinates = {
    // CBD Core - New 2026 Termini
    "green_park": {"lat": -1.2891, "lng": 36.8166}, // Green Park Terminus (Lunar Park site)
    "desai_road": {"lat": -1.2741, "lng": 36.8322}, // Desai & Park Rd Termini
    "commercial": {"lat": -1.2835, "lng": 36.8210}, // Commercial Terminus
    "otc": {"lat": -1.2825, "lng": 36.8150}, // OTC Terminus
    "tea_room": {"lat": -1.2800, "lng": 36.8133}, // Tea Room Terminus
    "ambassadeur": {"lat": -1.2850, "lng": 36.8183}, // Ambassadeur
    "kencom": {"lat": -1.2833, "lng": 36.8167}, // Kencom
    "railways": {"lat": -1.2875, "lng": 36.8200}, // Railways
    
    // Thika Road Corridor
    "githurai": {"lat": -1.2083, "lng": 36.9000},
    "kasarani": {"lat": -1.2250, "lng": 36.8950},
    "roysambu": {"lat": -1.2333, "lng": 36.8800},
    "zimmerman": {"lat": -1.2150, "lng": 36.9100},
    "kayole": {"lat": -1.2450, "lng": 36.9200},
    
    // Ngong Road / Lang'ata Corridor
    "adam's_arcade": {"lat": -1.3000, "lng": 36.7833},
    "prestige": {"lat": -1.2950, "lng": 36.7850},
    "ngong_road_hospital": {"lat": -1.3100, "lng": 36.7750},
    "kibera": {"lat": -1.3150, "lng": 36.7800},
    "dagoretti": {"lat": -1.3300, "lng": 36.7500},
    "karen": {"lat": -1.3333, "lng": 36.7000},
    "langata": {"lat": -1.3500, "lng": 36.7500},
    
    // Jogoo Road Corridor
    "makadara": {"lat": -1.2900, "lng": 36.8400},
    "hamza": {"lat": -1.2950, "lng": 36.8450},
    "buru_buru": {"lat": -1.2850, "lng": 36.8700},
    "embakasi": {"lat": -1.3150, "lng": 36.8900},
    "eastleigh": {"lat": -1.2650, "lng": 36.8450},
    
    // Mombasa Road Corridor
    "industrial_area": {"lat": -1.3100, "lng": 36.8400},
    "airport": {"lat": -1.3400, "lng": 36.8700},
    "imara_daima": {"lat": -1.3300, "lng": 36.8600},
    
    // Westlands/Waiyaki Way
    "westlands": {"lat": -1.2672, "lng": 36.8128},
    "parklands": {"lat": -1.2600, "lng": 36.8100},
    "kawangware": {"lat": -1.2850, "lng": 36.7450},
    
    // Mt Kenya Region Termini
    "nyeri": {"lat": -0.4167, "lng": 36.9500}, // Nyeri Town
    "embu": {"lat": -0.5333, "lng": 37.4500}, // Embu Town
    "karatina": {"lat": -0.4833, "lng": 37.1167}, // Karatina Town
  };

  // List of all stages (bus stops) - 2026 Updated
  static List<StageModel> getStages() {
    return [
      // NEW 2026 TERMINI
      StageModel(
        id: 'green_park',
        name: 'Green Park Terminus',
        lat: nairobiCoordinates["green_park"]!["lat"]!,
        lng: nairobiCoordinates["green_park"]!["lng"]!,
        corridor: 'Ngong/Langata Rd',
        routes: ['111', '24', '125', '126', '5'],
        area: 'Lunar Park',
      ),
      StageModel(
        id: 'desai_road',
        name: 'Desai & Park Rd Termini',
        lat: nairobiCoordinates["desai_road"]!["lat"]!,
        lng: nairobiCoordinates["desai_road"]!["lng"]!,
        corridor: 'Mt Kenya Region',
        routes: ['Nyeri', 'Embu', 'Karatina', 'Muranga'],
        area: 'Park Road',
      ),
      StageModel(
        id: 'commercial',
        name: 'Commercial Terminus',
        lat: nairobiCoordinates["commercial"]!["lat"]!,
        lng: nairobiCoordinates["commercial"]!["lng"]!,
        corridor: 'CBD',
        routes: ['110', '111', '112', '34', '35'],
        area: 'Commercial Street',
      ),
      
      // Existing CBD Core Stages
      StageModel(
        id: 'stage_kencom',
        name: 'Kencom Bus Station',
        lat: nairobiCoordinates["kencom"]!["lat"]!,
        lng: nairobiCoordinates["kencom"]!["lng"]!,
        corridor: 'CBD',
        routes: ['44', '45', '111', '24', '58', '10', '110', '114', '33'],
        area: 'Nairobi CBD',
      ),
      StageModel(
        id: 'stage_ambassadeur',
        name: 'Ambassadeur Bus Stop',
        lat: nairobiCoordinates["ambassadeur"]!["lat"]!,
        lng: nairobiCoordinates["ambassadeur"]!["lng"]!,
        corridor: 'CBD',
        routes: ['44', '45', '111', '58', '33', '34'],
        area: 'Nairobi CBD',
      ),
      StageModel(
        id: 'stage_railways',
        name: 'Railways Bus Station',
        lat: nairobiCoordinates["railways"]!["lat"]!,
        lng: nairobiCoordinates["railways"]!["lng"]!,
        corridor: 'CBD',
        routes: ['24', '58', '10', '110', '114'],
        area: 'Nairobi CBD',
      ),
      StageModel(
        id: 'stage_otc',
        name: 'OTC Bus Stop',
        lat: nairobiCoordinates["otc"]!["lat"]!,
        lng: nairobiCoordinates["otc"]!["lng"]!,
        corridor: 'CBD',
        routes: ['44', '45', '111', '24', '110'],
        area: 'Nairobi CBD',
      ),
      StageModel(
        id: 'stage_tea_room',
        name: 'Tea Room Bus Stop',
        lat: nairobiCoordinates["tea_room"]!["lat"]!,
        lng: nairobiCoordinates["tea_room"]!["lng"]!,
        corridor: 'CBD',
        routes: ['111', '24', '58', '10'],
        area: 'Nairobi CBD',
      ),

      // Thika Road Corridor Stages
      StageModel(
        id: 'stage_githurai',
        name: 'Githurai 45 Stage',
        lat: nairobiCoordinates["githurai"]!["lat"]!,
        lng: nairobiCoordinates["githurai"]!["lng"]!,
        corridor: 'Thika Road',
        routes: ['44', '45', '145', '146'],
        area: 'Githurai',
      ),
      StageModel(
        id: 'stage_kasarani',
        name: 'Kasarani Mwiki Stage',
        lat: nairobiCoordinates["kasarani"]!["lat"]!,
        lng: nairobiCoordinates["kasarani"]!["lng"]!,
        corridor: 'Thika Road',
        routes: ['44', '45', '145'],
        area: 'Kasarani',
      ),
      StageModel(
        id: 'stage_roysambu',
        name: 'Roysambu Stage',
        lat: nairobiCoordinates["roysambu"]!["lat"]!,
        lng: nairobiCoordinates["roysambu"]!["lng"]!,
        corridor: 'Thika Road',
        routes: ['44', '45', '146'],
        area: 'Roysambu',
      ),
      StageModel(
        id: 'stage_zimmerman',
        name: 'Zimmerman Stage',
        lat: nairobiCoordinates["zimmerman"]!["lat"]!,
        lng: nairobiCoordinates["zimmerman"]!["lng"]!,
        corridor: 'Thika Road',
        routes: ['44', '45', '147'],
        area: 'Zimmerman',
      ),
      StageModel(
        id: 'stage_kayole',
        name: 'Kayole Stage',
        lat: nairobiCoordinates["kayole"]!["lat"]!,
        lng: nairobiCoordinates["kayole"]!["lng"]!,
        corridor: 'Thika Road',
        routes: ['44', '147'],
        area: 'Kayole',
      ),

      // Ngong Road / Lang'ata Corridor Stages
      StageModel(
        id: 'stage_adams_arcade',
        name: "Adam's Arcade Stage",
        lat: nairobiCoordinates["adam's_arcade"]!["lat"]!,
        lng: nairobiCoordinates["adam's_arcade"]!["lng"]!,
        corridor: 'Ngong Road',
        routes: ['111', '24', '110', '125'],
        area: "Adam's Arcade",
      ),
      StageModel(
        id: 'stage_prestige',
        name: 'Prestige Stage',
        lat: nairobiCoordinates["prestige"]!["lat"]!,
        lng: nairobiCoordinates["prestige"]!["lng"]!,
        corridor: 'Ngong Road',
        routes: ['111', '24', '110'],
        area: 'Prestige',
      ),
      StageModel(
        id: 'stage_ngong_hospital',
        name: 'Ngong Road Hospital Stage',
        lat: nairobiCoordinates["ngong_road_hospital"]!["lat"]!,
        lng: nairobiCoordinates["ngong_road_hospital"]!["lng"]!,
        corridor: 'Ngong Road',
        routes: ['111', '24', '125'],
        area: 'Ngong Road',
      ),
      StageModel(
        id: 'stage_kibera',
        name: 'Kibera Stage',
        lat: nairobiCoordinates["kibera"]!["lat"]!,
        lng: nairobiCoordinates["kibera"]!["lng"]!,
        corridor: 'Ngong Road',
        routes: ['24', '110', '125'],
        area: 'Kibera',
      ),
      StageModel(
        id: 'stage_dagoretti',
        name: 'Dagoretti Market Stage',
        lat: nairobiCoordinates["dagoretti"]!["lat"]!,
        lng: nairobiCoordinates["dagoretti"]!["lng"]!,
        corridor: 'Ngong Road',
        routes: ['111', '24', '126'],
        area: 'Dagoretti',
      ),
      StageModel(
        id: 'stage_karen',
        name: 'Karen Shopping Centre',
        lat: nairobiCoordinates["karen"]!["lat"]!,
        lng: nairobiCoordinates["karen"]!["lng"]!,
        corridor: 'Ngong/Langata Rd',
        routes: ['126', '5'],
        area: 'Karen',
      ),
      StageModel(
        id: 'stage_langata',
        name: 'Langata Stage',
        lat: nairobiCoordinates["langata"]!["lat"]!,
        lng: nairobiCoordinates["langata"]!["lng"]!,
        corridor: 'Ngong/Langata Rd',
        routes: ['125', '126'],
        area: 'Langata',
      ),

      // Jogoo Road Corridor Stages
      StageModel(
        id: 'stage_makadara',
        name: 'Makadara Stage',
        lat: nairobiCoordinates["makadara"]!["lat"]!,
        lng: nairobiCoordinates["makadara"]!["lng"]!,
        corridor: 'Jogoo Road',
        routes: ['58', '10', '34'],
        area: 'Makadara',
      ),
      StageModel(
        id: 'stage_hamza',
        name: 'Hamza Stage',
        lat: nairobiCoordinates["hamza"]!["lat"]!,
        lng: nairobiCoordinates["hamza"]!["lng"]!,
        corridor: 'Jogoo Road',
        routes: ['58', '10', '34'],
        area: 'Hamza',
      ),
      StageModel(
        id: 'stage_buru_buru',
        name: 'Buru Buru Market Stage',
        lat: nairobiCoordinates["buru_buru"]!["lat"]!,
        lng: nairobiCoordinates["buru_buru"]!["lng"]!,
        corridor: 'Jogoo Road',
        routes: ['58', '10'],
        area: 'Buru Buru',
      ),
      StageModel(
        id: 'stage_embakasi',
        name: 'Embakasi Village Stage',
        lat: nairobiCoordinates["embakasi"]!["lat"]!,
        lng: nairobiCoordinates["embakasi"]!["lng"]!,
        corridor: 'Jogoo Road',
        routes: ['58', '34'],
        area: 'Embakasi',
      ),
      StageModel(
        id: 'stage_eastleigh',
        name: 'Eastleigh Stage',
        lat: nairobiCoordinates["eastleigh"]!["lat"]!,
        lng: nairobiCoordinates["eastleigh"]!["lng"]!,
        corridor: 'Jogoo Road',
        routes: ['58', '10'],
        area: 'Eastleigh',
      ),

      // Mombasa Road Corridor Stages
      StageModel(
        id: 'stage_industrial_area',
        name: 'Industrial Area Stage',
        lat: nairobiCoordinates["industrial_area"]!["lat"]!,
        lng: nairobiCoordinates["industrial_area"]!["lng"]!,
        corridor: 'Mombasa Road',
        routes: ['33', '34', '35'],
        area: 'Industrial Area',
      ),
      StageModel(
        id: 'stage_imara_daima',
        name: 'Imara Daima Stage',
        lat: nairobiCoordinates["imara_daima"]!["lat"]!,
        lng: nairobiCoordinates["imara_daima"]!["lng"]!,
        corridor: 'Mombasa Road',
        routes: ['33', '34'],
        area: 'Imara Daima',
      ),

      // Westlands/Waiyaki Way
      StageModel(
        id: 'stage_westlands',
        name: 'Westlands Stage',
        lat: nairobiCoordinates["westlands"]!["lat"]!,
        lng: nairobiCoordinates["westlands"]!["lng"]!,
        corridor: 'Waiyaki Way',
        routes: ['105', '106', '107'],
        area: 'Westlands',
      ),
      StageModel(
        id: 'stage_kawangware',
        name: 'Kawangware Stage',
        lat: nairobiCoordinates["kawangware"]!["lat"]!,
        lng: nairobiCoordinates["kawangware"]!["lng"]!,
        corridor: 'Waiyaki Way',
        routes: ['105', '106'],
        area: 'Kawangware',
      ),
      
      // Mt Kenya Region Termini (Long distance)
      StageModel(
        id: 'nyeri_terminal',
        name: 'Nyeri Town Terminal',
        lat: nairobiCoordinates["nyeri"]!["lat"]!,
        lng: nairobiCoordinates["nyeri"]!["lng"]!,
        corridor: 'Mt Kenya Region',
        routes: ['Nyeri', 'Muranga'],
        area: 'Nyeri',
      ),
      StageModel(
        id: 'embu_terminal',
        name: 'Embu Town Terminal',
        lat: nairobiCoordinates["embu"]!["lat"]!,
        lng: nairobiCoordinates["embu"]!["lng"]!,
        corridor: 'Mt Kenya Region',
        routes: ['Embu', 'Meru'],
        area: 'Embu',
      ),
      StageModel(
        id: 'karatina_terminal',
        name: 'Karatina Town Terminal',
        lat: nairobiCoordinates["karatina"]!["lat"]!,
        lng: nairobiCoordinates["karatina"]!["lng"]!,
        corridor: 'Mt Kenya Region',
        routes: ['Karatina', 'Nyeri'],
        area: 'Karatina',
      ),
    ];
  }

  // List of all routes - 2026 Updated
  static List<RouteModel> getRoutes() {
    return [
      // Thika Road Routes
      RouteModel(
        id: 'route_44',
        number: '44',
        name: 'CBD - Githurai 44',
        corridor: 'Thika Road',
        majorStops: ['Kencom', 'OTC', 'Roysambu', 'Kasarani', 'Githurai'],
        sacco: 'Super Metro',
        description: 'CBD to Githurai via Thika Road',
      ),
      RouteModel(
        id: 'route_45',
        number: '45',
        name: 'CBD - Githurai 45',
        corridor: 'Thika Road',
        majorStops: ['Kencom', 'Ambassadeur', 'Roysambu', 'Kasarani', 'Githurai'],
        sacco: 'Double M',
        description: 'CBD to Githurai 45 via Thika Road',
      ),
      RouteModel(
        id: 'route_145',
        number: '145',
        name: 'CBD - Kasarani',
        corridor: 'Thika Road',
        majorStops: ['Kencom', 'Ambassadeur', 'Roysambu', 'Kasarani'],
        sacco: 'Kenya Bus',
        description: 'CBD to Kasarani',
      ),
      RouteModel(
        id: 'route_146',
        number: '146',
        name: 'CBD - Zimmerman',
        corridor: 'Thika Road',
        majorStops: ['OTC', 'Roysambu', 'Zimmerman'],
        sacco: 'Super Metro',
        description: 'CBD to Zimmerman',
      ),
      RouteModel(
        id: 'route_147',
        number: '147',
        name: 'CBD - Kayole',
        corridor: 'Thika Road',
        majorStops: ['Kencom', 'Ambassadeur', 'Kayole'],
        sacco: 'Embassava',
        description: 'CBD to Kayole',
      ),

      // Ngong Road / Lang'ata Routes
      RouteModel(
        id: 'route_111',
        number: '111',
        name: "CBD - Adam's Arcade",
        corridor: 'Ngong Road',
        majorStops: ["Kencom", "Tea Room", "Adam's Arcade", "Prestige"],
        sacco: 'Citi Hoppa',
        description: "CBD to Adam's Arcade via Ngong Road",
      ),
      RouteModel(
        id: 'route_24',
        number: '24',
        name: 'CBD - Kibera',
        corridor: 'Ngong Road',
        majorStops: ['Kencom', 'Railways', 'Ngong Road Hospital', 'Kibera'],
        sacco: 'Rembo Shuttle',
        description: 'CBD to Kibera via Ngong Road',
      ),
      RouteModel(
        id: 'route_110',
        number: '110',
        name: 'CBD - Dagoretti Market',
        corridor: 'Ngong Road',
        majorStops: ['OTC', 'Railways', 'Prestige', 'Dagoretti'],
        sacco: 'Southfield',
        description: 'CBD to Dagoretti Market',
      ),
      RouteModel(
        id: 'route_125',
        number: '125',
        name: 'CBD - Langata',
        corridor: 'Ngong/Langata Rd',
        majorStops: ['Commercial', 'Green Park', 'Kibera', 'Langata'],
        sacco: 'Oxygen',
        description: 'CBD to Langata via Ngong Road',
      ),
      RouteModel(
        id: 'route_126',
        number: '126',
        name: 'CBD - Karen',
        corridor: 'Ngong/Langata Rd',
        majorStops: ['Commercial', 'Green Park', 'Langata', 'Karen'],
        sacco: 'KBS',
        description: 'CBD to Karen Shopping Centre',
      ),
      RouteModel(
        id: 'route_5',
        number: '5',
        name: 'CBD - Karen Hardy',
        corridor: 'Ngong/Langata Rd',
        majorStops: ['Kencom', 'Green Park', 'Langata', 'Karen'],
        sacco: 'Kenya Bus',
        description: 'CBD to Karen Hardy via Langata',
      ),

      // Jogoo Road Routes
      RouteModel(
        id: 'route_58',
        number: '58',
        name: 'CBD - Buru Buru',
        corridor: 'Jogoo Road',
        majorStops: ['Kencom', 'Ambassadeur', 'Makadara', 'Hamza', 'Buru Buru'],
        sacco: 'East Shuttle',
        description: 'CBD to Buru Buru via Jogoo Road',
      ),
      RouteModel(
        id: 'route_10',
        number: '10',
        name: 'CBD - Embakasi',
        corridor: 'Jogoo Road',
        majorStops: ['Tea Room', 'Railways', 'Makadara', 'Embakasi'],
        sacco: 'KBS',
        description: 'CBD to Embakasi via Jogoo Road',
      ),

      // Mombasa Road Routes
      RouteModel(
        id: 'route_33',
        number: '33',
        name: 'CBD - Imara Daima',
        corridor: 'Mombasa Road',
        majorStops: ['Kencom', 'Ambassadeur', 'Industrial Area', 'Imara Daima'],
        sacco: 'Super Metro',
        description: 'CBD to Imara Daima',
      ),
      RouteModel(
        id: 'route_34',
        number: '34',
        name: 'CBD - Airport',
        corridor: 'Mombasa Road',
        majorStops: ['Kencom', 'Ambassadeur', 'Industrial Area', 'Imara Daima', 'Airport'],
        sacco: 'Oxygen',
        description: 'CBD to Jomo Kenyatta International Airport',
      ),
      RouteModel(
        id: 'route_35',
        number: '35',
        name: 'CBD - Syokimau',
        corridor: 'Mombasa Road',
        majorStops: ['Commercial', 'Industrial Area', 'Imara Daima', 'Syokimau'],
        sacco: 'Citi Hoppa',
        description: 'CBD to Syokimau',
      ),

      // Waiyaki Way Routes
      RouteModel(
        id: 'route_105',
        number: '105',
        name: 'CBD - Westlands',
        corridor: 'Waiyaki Way',
        majorStops: ['Kencom', 'OTC', 'Westlands'],
        sacco: 'Citi Hoppa',
        description: 'CBD to Westlands',
      ),
      RouteModel(
        id: 'route_106',
        number: '106',
        name: 'CBD - Parklands',
        corridor: 'Waiyaki Way',
        majorStops: ['Kencom', 'Ambassadeur', 'Parklands'],
        sacco: 'Double M',
        description: 'CBD to Parklands',
      ),

      // Mt Kenya Region Routes (Long distance)
      RouteModel(
        id: 'route_nyeri',
        number: 'Nyeri',
        name: 'Nairobi - Nyeri',
        corridor: 'Mt Kenya Region',
        majorStops: ['Desai Road', 'Karatina', 'Nyeri'],
        sacco: 'Nyeri Express',
        description: 'Long distance to Nyeri Town',
      ),
      RouteModel(
        id: 'route_embu',
        number: 'Embu',
        name: 'Nairobi - Embu',
        corridor: 'Mt Kenya Region',
        majorStops: ['Desai Road', 'Embu'],
        sacco: 'Embu Shuttle',
        description: 'Long distance to Embu Town',
      ),
      RouteModel(
        id: 'route_karatina',
        number: 'Karatina',
        name: 'Nairobi - Karatina',
        corridor: 'Mt Kenya Region',
        majorStops: ['Desai Road', 'Karatina'],
        sacco: 'Karatina Sacco',
        description: 'Long distance to Karatina Town',
      ),
    ];
  }

  // Helper method to get stages by corridor
  static List<StageModel> getStagesByCorridor(String corridor) {
    return getStages().where((stage) => stage.corridor == corridor).toList();
  }

  // Helper method to get routes by corridor
  static List<RouteModel> getRoutesByCorridor(String corridor) {
    return getRoutes().where((route) => route.corridor == corridor).toList();
  }

  // Helper method to get routes serving a specific stage
  static List<RouteModel> getRoutesForStage(String stageId) {
    final stage = getStages().firstWhere((s) => s.id == stageId);
    return getRoutes().where((route) => 
      stage.routes?.contains(route.number) ?? false
    ).toList();
  }
  
  // Helper method to find stage by destination name
  static StageModel? findStageByDestination(String destination) {
    final stages = getStages();
    try {
      return stages.firstWhere(
        (stage) => stage.name.toLowerCase().contains(destination.toLowerCase()) ||
                   stage.area?.toLowerCase().contains(destination.toLowerCase()) == true
      );
    } catch (e) {
      return null;
    }
  }
  
  // Helper method to find route by destination
  static List<RouteModel> findRoutesByDestination(String destination) {
    final routes = getRoutes();
    return routes.where((route) => 
      route.name.toLowerCase().contains(destination.toLowerCase()) ||
      route.majorStops.any((stop) => stop.toLowerCase().contains(destination.toLowerCase()))
    ).toList();
  }
}