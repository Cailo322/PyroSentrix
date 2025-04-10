import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:math' as math;

class ApiService {
  final String apiKey = 'AIzaSyD21izdTx2qn4vPFcFzkSDB5xhdWxtoXuM';
  final String baseUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
  final String detailsUrl = 'https://maps.googleapis.com/maps/api/place/details/json';
  final String distanceMatrixUrl = 'https://maps.googleapis.com/maps/api/distancematrix/json';
  final String geocodeUrl = 'https://maps.googleapis.com/maps/api/geocode/json';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> _officialFireStationPatterns = [
    'Fire Station',
    'Fire Sub-Station',
    'Fire Sub Station',
    'Bureau of Fire Protection',
    'BFP Station',
  ];

  // Known name mappings for fire stations
  final Map<String, List<String>> _knownStationMappings = {
    'krus na ligas': ['krusnaligas', 'krus na ligas'],
    'quirino 2a': ['quirino 2-a', 'quirino2a'],
    'sub station': ['substation', 'sub-station'],
  };

  Future<List<Map<String, dynamic>>> fetchFireStations(String userAddress) async {
    try {
      final location = await _getPreciseLocationFromAddress(userAddress);
      final city = await _determineCityFromAddress(userAddress);

      final response = await http.get(
        Uri.parse('$baseUrl?location=${location['lat']},${location['lng']}&radius=3000&type=fire_station&key=$apiKey'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final validResults = jsonResponse['results'].where((result) =>
        (result['business_status'] == 'OPERATIONAL' || !result.containsKey('business_status')) &&
            _isOfficialFireStation(result['name'])
        ).toList();

        if (validResults.isEmpty) {
          throw Exception('No operational OFFICIAL fire stations found nearby');
        }

        List<Map<String, dynamic>> stations = [];
        List<String> destinations = [];

        for (var result in validResults) {
          final lat = result['geometry']['location']['lat'];
          final lng = result['geometry']['location']['lng'];
          destinations.add('$lat,$lng');

          stations.add({
            'name': result['name'],
            'address': result['vicinity'],
            'place_id': result['place_id'],
            'location': result['geometry']['location'],
          });
        }

        final distances = await _getPreciseDistances(location, destinations);

        for (int i = 0; i < stations.length; i++) {
          stations[i]['distance_km'] = distances[i]['distance'];
          stations[i]['duration'] = distances[i]['duration'];
          stations[i]['travel_distance_km'] = _calculateStraightDistance(
            location['lat']!,
            location['lng']!,
            stations[i]['location']['lat'],
            stations[i]['location']['lng'],
          ).toStringAsFixed(2);
        }

        stations.sort((a, b) => double.parse(a['distance_km']).compareTo(double.parse(b['distance_km'])));
        List<Map<String, dynamic>> topStations = stations.take(4).toList(); // Changed from 3 to 4 here

        for (var station in topStations) {
          try {
            var details = await _getEnhancedPlaceDetails(station['place_id']);
            List<String> contacts = [];

            if (details['formatted_phone_number'] != null) {
              contacts.add(details['formatted_phone_number']);
            }

            if (city != null) {
              final phoneNumbers = await _getPhoneNumbersFromFirestore(city, station['name']);
              if (phoneNumbers.isNotEmpty) {
                contacts.addAll(phoneNumbers);
              }
            }

            station['contact'] = contacts.isNotEmpty ? contacts : ['Not available'];
            station['full_address'] = details['formatted_address'] ?? station['address'];
            station['website'] = details['website'] ?? 'Not available';
          } catch (e) {
            station['contact'] = ['Not available'];
            station['full_address'] = station['address'];
            station['website'] = 'Not available';
          }
        }

        return topStations;
      } else {
        throw Exception('Failed to load fire stations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching fire stations: $e');
    }
  }

  bool _isOfficialFireStation(String name) {
    if (name == null || name.isEmpty) return false;
    final lowerName = name.toLowerCase();
    return _officialFireStationPatterns.any((pattern) =>
        lowerName.contains(pattern.toLowerCase())
    );
  }

  Future<String?> _determineCityFromAddress(String address) async {
    try {
      final cityMap = {
        'Quezon City': 'Quezon City',
        'Caloocan': 'Caloocan',
        'Las Piñas': 'Las_Pi_as',
        'Makati': 'Makati',
        'Malabon': 'Malabon',
        'Mandaluyong': 'Mandaluyong',
        'Marikina': 'Marikina',
        'Muntinlupa': 'Muntinlupa',
        'Navotas': 'Navotas',
        'Parañaque': 'Para_aque',
        'Pasay': 'Pasay',
        'Pasig': 'Pasig',
        'Pateros': 'Pateros',
        'San Juan': 'San_Juan',
        'Taguig': 'Taguig',
        'Valenzuela': 'Valenzuela',
        'Manila': 'Manila',
      };

      final lowerAddress = address.toLowerCase();

      if (lowerAddress.contains('quezon city') || lowerAddress.contains('qc')) {
        return 'Quezon City';
      }

      for (var entry in cityMap.entries) {
        final displayName = entry.key;
        final pattern = r'\b' + displayName.toLowerCase() + r'\b';
        if (RegExp(pattern).hasMatch(lowerAddress)) {
          return entry.value;
        }
      }

      for (var firestoreName in cityMap.values) {
        final searchPattern = firestoreName.replaceAll('_', ' ');
        final pattern = r'\b' + searchPattern.toLowerCase() + r'\b';
        if (RegExp(pattern).hasMatch(lowerAddress)) {
          return firestoreName;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> _getPhoneNumbersFromFirestore(String city, String stationName) async {
    try {
      final snapshot = await _firestore
          .collection('FireStations')
          .doc('NCR')
          .collection(city)
          .get();

      List<String> phoneNumbers = [];
      final normalizedSearchName = _normalizeStationName(stationName);

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final firestoreName = data['name']?.toString() ?? '';
        final normalizedFirestoreName = _normalizeStationName(firestoreName);

        if (_stationNamesMatch(normalizedSearchName, normalizedFirestoreName)) {
          if (data['phoneNumbers'] is String) {
            phoneNumbers.add(data['phoneNumbers']);
          } else if (data['phoneNumbers'] is List) {
            phoneNumbers.addAll((data['phoneNumbers'] as List).map((e) => e.toString()));
          }
        }
      }

      return phoneNumbers.where((num) => num.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  String _normalizeStationName(String name) {
    if (name.isEmpty) return name;

    // Convert to lowercase
    var normalized = name.toLowerCase();

    // Remove common variations
    normalized = normalized
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .replaceAll('.', '')
        .replaceAll('sub station', 'substation')
        .replaceAll('sub-station', 'substation');

    // Remove common prefixes/suffixes
    normalized = normalized
        .replaceAll('bureau of fire protection', '')
        .replaceAll('bfp', '')
        .replaceAll('fire station', '')
        .replaceAll('fire substation', '')
        .replaceAll('station', '');

    // Remove numbers at the end (like "44" in "Krus Na Ligas Fire Sub-Station 44")
    normalized = normalized.replaceAll(RegExp(r'\s+\d+$'), '');

    // Remove extra spaces
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();

    return normalized;
  }

  bool _stationNamesMatch(String name1, String name2) {
    if (name1.isEmpty || name2.isEmpty) return false;

    // Exact match after normalization
    if (name1 == name2) return true;

    // Check if one contains the other
    if (name1.contains(name2) || name2.contains(name1)) return true;

    // Handle cases like "2-A" vs "2A"
    final simplified1 = name1.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final simplified2 = name2.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (simplified1 == simplified2) return true;

    // Check against known mappings
    for (final entry in _knownStationMappings.entries) {
      if ((name1.contains(entry.key) && entry.value.any((v) => name2.contains(v))) ||
          (name2.contains(entry.key) && entry.value.any((v) => name1.contains(v)))) {
        return true;
      }
    }

    return false;
  }

  Future<Map<String, dynamic>> _getEnhancedPlaceDetails(String placeId) async {
    final response = await http.get(
      Uri.parse('$detailsUrl?place_id=$placeId&fields=name,formatted_address,formatted_phone_number,website,opening_hours&key=$apiKey'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      return jsonResponse['result'];
    } else {
      throw Exception('Failed to load place details: ${response.statusCode}');
    }
  }

  Future<Map<String, double>> _getPreciseLocationFromAddress(String address) async {
    final String phAddress = address.contains('Philippines') ? address : '$address, Philippines';
    final response = await http.get(
      Uri.parse('$geocodeUrl?address=${Uri.encodeComponent(phAddress)}&region=ph&key=$apiKey'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      if (jsonResponse['results'].isNotEmpty) {
        final location = jsonResponse['results'][0]['geometry']['location'];
        return {
          'lat': location['lat'],
          'lng': location['lng'],
        };
      } else {
        throw Exception('No results found for the provided address');
      }
    } else {
      throw Exception('Failed to get location from address: ${response.statusCode}');
    }
  }

  Future<List<Map<String, String>>> _getPreciseDistances(
      Map<String, double> origin, List<String> destinations) async {
    final originString = '${origin['lat']},${origin['lng']}';
    final destinationString = destinations.join('|');

    final response = await http.get(
      Uri.parse('$distanceMatrixUrl?origins=$originString&destinations=$destinationString&mode=driving&traffic_model=best_guess&departure_time=now&region=ph&key=$apiKey'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      List<Map<String, String>> distances = [];

      for (var element in jsonResponse['rows'][0]['elements']) {
        if (element['status'] == 'OK') {
          distances.add({
            'distance': (element['distance']['value'] / 1000).toStringAsFixed(2),
            'duration': element['duration']['text'],
          });
        } else {
          distances.add({
            'distance': 'N/A',
            'duration': 'N/A',
          });
        }
      }

      return distances;
    } else {
      throw Exception('Failed to get distances: ${response.statusCode}');
    }
  }

  double _calculateStraightDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLng = _degreesToRadians(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}