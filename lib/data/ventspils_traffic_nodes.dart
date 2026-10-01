// Offline catalog of Ventspils traffic control nodes (traffic signals, give way, stop signs, traffic calming, pedestrian crossings)
// Sourced from OpenStreetMap for instant, offline lookahead safety alerts.

import 'dart:math';
import '../models/lookahead_event.dart';

class TrafficNode {
  final int id;
  final double lat;
  final double lon;
  final LookaheadEventType type;
  final String? direction;

  const TrafficNode({
    required this.id,
    required this.lat,
    required this.lon,
    required this.type,
    this.direction,
  });
}

class VentspilsTrafficNodes {
  static const List<TrafficNode> nodes = [
    TrafficNode(id: 29705222, lat: 57.387816, lon: 21.582507, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 29705226, lat: 57.389709, lon: 21.574120, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 29705229, lat: 57.389651, lon: 21.564548, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 29705231, lat: 57.389621, lon: 21.558811, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 29705232, lat: 57.389643, lon: 21.553943, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 30623642, lat: 57.390331, lon: 21.547180, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 30623649, lat: 57.384111, lon: 21.550297, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 30623650, lat: 57.383205, lon: 21.554462, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 30679326, lat: 57.403843, lon: 21.590470, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 30685042, lat: 57.391123, lon: 21.595946, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 31999624, lat: 57.381777, lon: 21.577291, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 32633336, lat: 57.391652, lon: 21.563378, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 32633337, lat: 57.391623, lon: 21.563900, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 32633368, lat: 57.393767, lon: 21.564715, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 32633610, lat: 57.402986, lon: 21.598185, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 32671958, lat: 57.396711, lon: 21.590064, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 32671959, lat: 57.396807, lon: 21.590523, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 32672998, lat: 57.389641, lon: 21.562751, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 33792730, lat: 57.391839, lon: 21.559915, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 55111128, lat: 57.382402, lon: 21.559988, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 55177145, lat: 57.381989, lon: 21.566497, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 55177555, lat: 57.380514, lon: 21.570439, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 55195191, lat: 57.394944, lon: 21.568983, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 253016497, lat: 57.395069, lon: 21.568886, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 278251646, lat: 57.391171, lon: 21.596150, type: LookaheadEventType.trafficLight, direction: null),
    TrafficNode(id: 12077333541, lat: 57.389492, lon: 21.564601, type: LookaheadEventType.trafficLight, direction: 'forward'),
    TrafficNode(id: 12077349497, lat: 57.393548, lon: 21.564572, type: LookaheadEventType.trafficLight, direction: 'forward'),
    TrafficNode(id: 1109629179, lat: 57.387116, lon: 21.585477, type: LookaheadEventType.giveWay, direction: null),
    TrafficNode(id: 8857668340, lat: 57.386812, lon: 21.586114, type: LookaheadEventType.giveWay, direction: null),
    TrafficNode(id: 12155477275, lat: 57.387227, lon: 21.586184, type: LookaheadEventType.giveWay, direction: null),
    TrafficNode(id: 12470865683, lat: 57.373315, lon: 21.565214, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471085195, lat: 57.377409, lon: 21.557305, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471085196, lat: 57.377963, lon: 21.557855, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471124796, lat: 57.387229, lon: 21.542415, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471124797, lat: 57.387217, lon: 21.541862, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471129280, lat: 57.380849, lon: 21.553266, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471129282, lat: 57.379744, lon: 21.558529, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471129284, lat: 57.380075, lon: 21.556769, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471129285, lat: 57.380178, lon: 21.556822, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471129286, lat: 57.380468, lon: 21.554928, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471129287, lat: 57.380563, lon: 21.554981, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471129288, lat: 57.379188, lon: 21.558531, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471129289, lat: 57.376387, lon: 21.559631, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471129290, lat: 57.374732, lon: 21.562309, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471129291, lat: 57.374020, lon: 21.563336, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471129292, lat: 57.373228, lon: 21.565516, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471138255, lat: 57.390217, lon: 21.542755, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471138256, lat: 57.390112, lon: 21.543370, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471138257, lat: 57.389650, lon: 21.541840, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471138258, lat: 57.389551, lon: 21.541680, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471138259, lat: 57.388545, lon: 21.544038, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471138271, lat: 57.390913, lon: 21.544868, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471138966, lat: 57.390715, lon: 21.542123, type: LookaheadEventType.giveWay, direction: 'forward'),
    TrafficNode(id: 12471138967, lat: 57.391413, lon: 21.543169, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471268737, lat: 57.373442, lon: 21.564464, type: LookaheadEventType.giveWay, direction: 'backward'),
    TrafficNode(id: 12471085197, lat: 57.378028, lon: 21.557290, type: LookaheadEventType.stopSign, direction: 'forward'),
    // --- Ātrumvaļņi un paaugstinātās pārejas (Traffic Calming) ---
    TrafficNode(id: 10226543332, lat: 57.386429, lon: 21.582796, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 10226543333, lat: 57.386841, lon: 21.582055, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 10228124833, lat: 57.380704, lon: 21.568767, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 10228124875, lat: 57.380338, lon: 21.568795, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 12470865684, lat: 57.373642, lon: 21.564089, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 12598058713, lat: 57.389618, lon: 21.537776, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 13359437803, lat: 57.400255, lon: 21.595904, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 13359437804, lat: 57.400460, lon: 21.594555, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 13684912542, lat: 57.387625, lon: 21.576926, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 13698677764, lat: 57.378252, lon: 21.526761, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 13698677765, lat: 57.378761, lon: 21.526106, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 1148002702, lat: 57.390833, lon: 21.570342, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 1148002705, lat: 57.390912, lon: 21.570501, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 1148002706, lat: 57.390854, lon: 21.570500, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 1148002714, lat: 57.390132, lon: 21.570293, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 1148002715, lat: 57.390132, lon: 21.570359, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 1148002716, lat: 57.390047, lon: 21.571410, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 1148876226, lat: 57.390771, lon: 21.571548, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 1149269910, lat: 57.387411, lon: 21.576104, type: LookaheadEventType.trafficCalming),
    TrafficNode(id: 1316952846, lat: 57.397759, lon: 21.570636, type: LookaheadEventType.trafficCalming),
    // --- Taisnvirziena gājēju pārejas (Mid-block Crossings) ---
    TrafficNode(id: 261120449, lat: 57.389660, lon: 21.550446, type: LookaheadEventType.pedestrianCrossing), // Lielais prospekts
    TrafficNode(id: 262290737, lat: 57.389516, lon: 21.562712, type: LookaheadEventType.pedestrianCrossing), // Ganību iela
    TrafficNode(id: 262290757, lat: 57.388408, lon: 21.558114, type: LookaheadEventType.pedestrianCrossing), // Saules iela
    TrafficNode(id: 393669071, lat: 57.384611, lon: 21.586820, type: LookaheadEventType.pedestrianCrossing), // Durbes iela
    TrafficNode(id: 394909324, lat: 57.382057, lon: 21.568515, type: LookaheadEventType.pedestrianCrossing), // Kuldīgas iela
    TrafficNode(id: 715845501, lat: 57.385054, lon: 21.538458, type: LookaheadEventType.pedestrianCrossing), // Riņķa iela
    TrafficNode(id: 848862550, lat: 57.380290, lon: 21.549515, type: LookaheadEventType.pedestrianCrossing), // Aizsaules iela
    TrafficNode(id: 927243554, lat: 57.377904, lon: 21.557481, type: LookaheadEventType.pedestrianCrossing), // Ganību iela
    TrafficNode(id: 927243566, lat: 57.377966, lon: 21.557784, type: LookaheadEventType.pedestrianCrossing), // Riņķa iela
    TrafficNode(id: 1380995178, lat: 57.387843, lon: 21.543595, type: LookaheadEventType.pedestrianCrossing),
    TrafficNode(id: 1382251026, lat: 57.387431, lon: 21.549252, type: LookaheadEventType.pedestrianCrossing), // Bērzu iela
    TrafficNode(id: 1382251048, lat: 57.388083, lon: 21.548983, type: LookaheadEventType.pedestrianCrossing), // Pētera iela
    TrafficNode(id: 1387516919, lat: 57.421962, lon: 21.635970, type: LookaheadEventType.pedestrianCrossing), // Talsu iela
    TrafficNode(id: 1387627449, lat: 57.406211, lon: 21.602940, type: LookaheadEventType.pedestrianCrossing), // Embūtes iela
    TrafficNode(id: 1567885154, lat: 57.390771, lon: 21.538332, type: LookaheadEventType.pedestrianCrossing), // Loču iela
    TrafficNode(id: 1587585288, lat: 57.385032, lon: 21.538693, type: LookaheadEventType.pedestrianCrossing), // Vasarnīcu iela
    TrafficNode(id: 1587585327, lat: 57.385562, lon: 21.546763, type: LookaheadEventType.pedestrianCrossing), // J. Poruka iela
    TrafficNode(id: 1682144200, lat: 57.385794, lon: 21.586348, type: LookaheadEventType.pedestrianCrossing), // Apļa iela
    TrafficNode(id: 1716938435, lat: 57.375099, lon: 21.547350, type: LookaheadEventType.pedestrianCrossing), // Saules iela
    TrafficNode(id: 1736057261, lat: 57.383785, lon: 21.589090, type: LookaheadEventType.pedestrianCrossing), // Rūpniecības iela
    TrafficNode(id: 1818279159, lat: 57.397766, lon: 21.570736, type: LookaheadEventType.pedestrianCrossing),
    TrafficNode(id: 1836457848, lat: 57.381362, lon: 21.569640, type: LookaheadEventType.pedestrianCrossing), // Latgales iela
    TrafficNode(id: 1843930380, lat: 57.389975, lon: 21.548751, type: LookaheadEventType.pedestrianCrossing), // Lielais prospekts
    TrafficNode(id: 2321583172, lat: 57.388326, lon: 21.557901, type: LookaheadEventType.pedestrianCrossing), // Pētera iela
    TrafficNode(id: 4290809640, lat: 57.396561, lon: 21.532733, type: LookaheadEventType.pedestrianCrossing),
    TrafficNode(id: 4290809643, lat: 57.397218, lon: 21.532825, type: LookaheadEventType.pedestrianCrossing),
    TrafficNode(id: 5226504505, lat: 57.404284, lon: 21.600666, type: LookaheadEventType.pedestrianCrossing), // Embūtes iela
    TrafficNode(id: 7375057596, lat: 57.389748, lon: 21.562778, type: LookaheadEventType.pedestrianCrossing), // Ganību iela
    TrafficNode(id: 7375825252, lat: 57.391078, lon: 21.595743, type: LookaheadEventType.pedestrianCrossing), // Kustes dambis
    TrafficNode(id: 8058638809, lat: 57.389624, lon: 21.548626, type: LookaheadEventType.pedestrianCrossing), // Lielais prospekts
    TrafficNode(id: 8794820237, lat: 57.388067, lon: 21.553215, type: LookaheadEventType.pedestrianCrossing), // Katoļu iela
    TrafficNode(id: 8794820240, lat: 57.388089, lon: 21.549382, type: LookaheadEventType.pedestrianCrossing), // Pētera iela
    TrafficNode(id: 8794820245, lat: 57.388199, lon: 21.549237, type: LookaheadEventType.pedestrianCrossing), // J. Poruka iela
    TrafficNode(id: 8794836379, lat: 57.393832, lon: 21.532854, type: LookaheadEventType.pedestrianCrossing),
    TrafficNode(id: 8795206494, lat: 57.397111, lon: 21.570739, type: LookaheadEventType.pedestrianCrossing), // Prāmju iela
    TrafficNode(id: 8848025227, lat: 57.391134, lon: 21.573674, type: LookaheadEventType.pedestrianCrossing), // Brīvības iela
    TrafficNode(id: 8848025228, lat: 57.391140, lon: 21.573864, type: LookaheadEventType.pedestrianCrossing), // Brīvības iela
    TrafficNode(id: 8848043095, lat: 57.395466, lon: 21.571398, type: LookaheadEventType.pedestrianCrossing), // Kuldīgas iela
    TrafficNode(id: 8857668382, lat: 57.384886, lon: 21.587422, type: LookaheadEventType.pedestrianCrossing), // Skaidu iela
    TrafficNode(id: 8857668509, lat: 57.383966, lon: 21.576671, type: LookaheadEventType.pedestrianCrossing), // Lāčplēša iela
    TrafficNode(id: 9099173061, lat: 57.407282, lon: 21.593137, type: LookaheadEventType.pedestrianCrossing), // Talsu iela
    TrafficNode(id: 10676903579, lat: 57.389640, lon: 21.562605, type: LookaheadEventType.pedestrianCrossing), // Lielais prospekts
    TrafficNode(id: 10676903582, lat: 57.389641, lon: 21.562927, type: LookaheadEventType.pedestrianCrossing), // Lielais prospekts
    TrafficNode(id: 10676951095, lat: 57.389711, lon: 21.557281, type: LookaheadEventType.pedestrianCrossing), // Liepājas iela
    TrafficNode(id: 10677027995, lat: 57.391170, lon: 21.569743, type: LookaheadEventType.pedestrianCrossing), // Aleksandra iela
    TrafficNode(id: 10677027998, lat: 57.391268, lon: 21.569892, type: LookaheadEventType.pedestrianCrossing), // Jūras iela
    TrafficNode(id: 10681347924, lat: 57.390833, lon: 21.570339, type: LookaheadEventType.pedestrianCrossing),
    TrafficNode(id: 10681347939, lat: 57.390052, lon: 21.571410, type: LookaheadEventType.pedestrianCrossing),
    TrafficNode(id: 10684075884, lat: 57.392616, lon: 21.573467, type: LookaheadEventType.pedestrianCrossing), // Brīvības iela
    TrafficNode(id: 10684138559, lat: 57.387219, lon: 21.565511, type: LookaheadEventType.pedestrianCrossing), // Kuldīgas iela
    TrafficNode(id: 10684138574, lat: 57.384844, lon: 21.561138, type: LookaheadEventType.pedestrianCrossing), // Ganību iela
    TrafficNode(id: 10684149380, lat: 57.386546, lon: 21.567848, type: LookaheadEventType.pedestrianCrossing), // Sporta iela
    TrafficNode(id: 10684198595, lat: 57.387380, lon: 21.565224, type: LookaheadEventType.pedestrianCrossing), // Pāvila iela
    TrafficNode(id: 10686553051, lat: 57.386654, lon: 21.552267, type: LookaheadEventType.pedestrianCrossing), // Katoļu iela
    TrafficNode(id: 10688658307, lat: 57.390770, lon: 21.571568, type: LookaheadEventType.pedestrianCrossing),
    TrafficNode(id: 10691774241, lat: 57.379040, lon: 21.552272, type: LookaheadEventType.pedestrianCrossing), // Riņķa iela
    TrafficNode(id: 10691774421, lat: 57.385548, lon: 21.546426, type: LookaheadEventType.pedestrianCrossing), // Inženieru iela
    TrafficNode(id: 10693685504, lat: 57.393901, lon: 21.560879, type: LookaheadEventType.pedestrianCrossing), // Saules iela
    TrafficNode(id: 10697569159, lat: 57.376312, lon: 21.573347, type: LookaheadEventType.pedestrianCrossing), // Kuldīgas iela
    TrafficNode(id: 10702315017, lat: 57.390853, lon: 21.538538, type: LookaheadEventType.pedestrianCrossing), // Loču iela
    TrafficNode(id: 10702315026, lat: 57.390761, lon: 21.538622, type: LookaheadEventType.pedestrianCrossing), // Medņu iela
    TrafficNode(id: 10702315061, lat: 57.389540, lon: 21.549561, type: LookaheadEventType.pedestrianCrossing), // J. Poruka iela
    TrafficNode(id: 10704936999, lat: 57.389735, lon: 21.560928, type: LookaheadEventType.pedestrianCrossing), // Lielā Dzirnavu iela
    TrafficNode(id: 10733431510, lat: 57.398039, lon: 21.569520, type: LookaheadEventType.pedestrianCrossing),
    TrafficNode(id: 10744021387, lat: 57.402789, lon: 21.587256, type: LookaheadEventType.pedestrianCrossing), // P. Stradiņa iela
    TrafficNode(id: 10749480559, lat: 57.399955, lon: 21.604642, type: LookaheadEventType.pedestrianCrossing), // Tārgales iela
    TrafficNode(id: 10749480565, lat: 57.399818, lon: 21.604688, type: LookaheadEventType.pedestrianCrossing), // Rindas iela
    TrafficNode(id: 10749480566, lat: 57.399823, lon: 21.604913, type: LookaheadEventType.pedestrianCrossing), // Tārgales iela
    TrafficNode(id: 10885095028, lat: 57.388021, lon: 21.549191, type: LookaheadEventType.pedestrianCrossing), // J. Poruka iela
    TrafficNode(id: 11102367569, lat: 57.375437, lon: 21.548363, type: LookaheadEventType.pedestrianCrossing), // Saules iela
    TrafficNode(id: 11564486465, lat: 57.405102, lon: 21.566294, type: LookaheadEventType.pedestrianCrossing), // Dzintaru iela
    TrafficNode(id: 11612892858, lat: 57.392433, lon: 21.601594, type: LookaheadEventType.pedestrianCrossing), // Kustes dambis
    TrafficNode(id: 11612918257, lat: 57.404351, lon: 21.564358, type: LookaheadEventType.pedestrianCrossing), // Dzintaru iela
    TrafficNode(id: 11612950344, lat: 57.389198, lon: 21.601780, type: LookaheadEventType.pedestrianCrossing), // Fabrikas iela
    TrafficNode(id: 11741522857, lat: 57.407248, lon: 21.599454, type: LookaheadEventType.pedestrianCrossing), // Celtnieku iela
    TrafficNode(id: 11945101976, lat: 57.404841, lon: 21.583973, type: LookaheadEventType.pedestrianCrossing), // P. Stradiņa iela
    TrafficNode(id: 13041480321, lat: 57.405204, lon: 21.601901, type: LookaheadEventType.pedestrianCrossing), // Embūtes iela
    TrafficNode(id: 14087546058, lat: 57.392428, lon: 21.572942, type: LookaheadEventType.pedestrianCrossing), // Sarkanmuižas dambis
    TrafficNode(id: 14092552258, lat: 57.392590, lon: 21.573090, type: LookaheadEventType.pedestrianCrossing), // Sarkanmuižas dambis
    TrafficNode(id: 14092552261, lat: 57.392270, lon: 21.574296, type: LookaheadEventType.pedestrianCrossing), // Sarkanmuižas dambis
    TrafficNode(id: 14092552264, lat: 57.392107, lon: 21.574132, type: LookaheadEventType.pedestrianCrossing), // Sarkanmuižas dambis
  ];

  /// Scans offline nodes ahead of vehicle within [lookaheadDist] along vehicle [heading].
  static List<LookaheadEvent> findUpcomingNodes({
    required double lat,
    required double lon,
    required double heading,
    required double lookaheadDist,
    double minDistance = 15.0,
    bool includeTrafficLights = true,
    bool includeGiveWay = true,
    bool includeTrafficCalming = true,
    bool includePedestrianCrossings = true,
  }) {
    final results = <LookaheadEvent>[];
    for (final node in nodes) {
      if (node.type == LookaheadEventType.trafficLight && !includeTrafficLights) continue;
      if ((node.type == LookaheadEventType.giveWay || node.type == LookaheadEventType.stopSign) && !includeGiveWay) continue;
      if (node.type == LookaheadEventType.trafficCalming && !includeTrafficCalming) continue;
      if (node.type == LookaheadEventType.pedestrianCrossing && !includePedestrianCrossings) continue;

      final d = _calculateDistance(lat, lon, node.lat, node.lon);
      if (d >= minDistance && d <= lookaheadDist) {
        final bearing = _calculateBearing(lat, lon, node.lat, node.lon);
        double diff = (heading - bearing).abs() % 360.0;
        if (diff > 180.0) diff = 360.0 - diff;
        if (diff <= 35.0) {
          results.add(
            LookaheadEvent(
              type: node.type,
              distanceMeters: d,
              latitude: node.lat,
              longitude: node.lon,
            ),
          );
        }
      }
    }
    return results;
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final phi1 = lat1 * pi / 180.0;
    final phi2 = lat2 * pi / 180.0;
    final deltaLambda = (lon2 - lon1) * pi / 180.0;
    final y = sin(deltaLambda) * cos(phi2);
    final x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda);
    final theta = atan2(y, x);
    return (theta * 180.0 / pi + 360.0) % 360.0;
  }
}
