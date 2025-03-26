import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

class ApiService {
  final String apiKey = 'AIzaSyD21izdTx2qn4vPFcFzkSDB5xhdWxtoXuM';
  final String baseUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
  final String detailsUrl = 'https://maps.googleapis.com/maps/api/place/details/json';
  final String distanceMatrixUrl = 'https://maps.googleapis.com/maps/api/distancematrix/json';
  final String geocodeUrl = 'https://maps.googleapis.com/maps/api/geocode/json';

  Future<List<Map<String, dynamic>>> fetchFireStations(String userAddress) async {
    try {
      // Step 1: Get precise location from user address
      final location = await _getPreciseLocationFromAddress(userAddress);

      // Step 2: Search for fire stations with a reasonable radius (3km for urban areas)
      final response = await http.get(
        Uri.parse('$baseUrl?location=${location['lat']},${location['lng']}'
            '&radius=3000'  // 3km radius for urban areas in Philippines
            '&type=fire_station'
            '&key=$apiKey'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        // Filter out invalid or unwanted results
        final validResults = jsonResponse['results'].where((result) =>
        result['business_status'] == 'OPERATIONAL' ||
            !result.containsKey('business_status')
        ).toList();

        if (validResults.isEmpty) {
          throw Exception('No operational fire stations found nearby');
        }

        List<Map<String, dynamic>> stations = [];
        List<String> destinations = [];

        // Collect destination coordinates for Distance Matrix API
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

        // Step 3: Get precise travel distances and times
        final distances = await _getPreciseDistances(location, destinations);

        // Combine results with distances
        for (int i = 0; i < stations.length; i++) {
          stations[i]['distance_km'] = distances[i]['distance'];
          stations[i]['duration'] = distances[i]['duration'];
          stations[i]['straight_distance_km'] = _calculateStraightDistance(
            location['lat']!,
            location['lng']!,
            stations[i]['location']['lat'],
            stations[i]['location']['lng'],
          ).toStringAsFixed(2);
        }

        // Step 4: Sort by actual travel distance (not straight-line)
        stations.sort((a, b) => double.parse(a['distance_km']).compareTo(double.parse(b['distance_km'])));

        // Get top 3 nearest stations
        List<Map<String, dynamic>> topStations = stations.take(3).toList();

        // Step 5: Fetch additional details for the top 3 stations
        for (var station in topStations) {
          try {
            var details = await _getEnhancedPlaceDetails(station['place_id']);
            station['contact'] = details['formatted_phone_number'] ?? 'Not available';
            station['full_address'] = details['formatted_address'] ?? station['address'];
            station['website'] = details['website'] ?? 'Not available';
          } catch (e) {
            // If details fail, keep the basic info
            station['contact'] = 'Not available';
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

  Future<Map<String, dynamic>> _getEnhancedPlaceDetails(String placeId) async {
    final response = await http.get(
      Uri.parse('$detailsUrl?place_id=$placeId'
          '&fields=name,formatted_address,formatted_phone_number,website,opening_hours'
          '&key=$apiKey'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      return jsonResponse['result'];
    } else {
      throw Exception('Failed to load place details: ${response.statusCode}');
    }
  }

  Future<Map<String, double>> _getPreciseLocationFromAddress(String address) async {
    // Add Philippines to the address to improve geocoding accuracy
    final String phAddress = address.contains('Philippines') ? address : '$address, Philippines';

    final response = await http.get(
      Uri.parse('$geocodeUrl?address=${Uri.encodeComponent(phAddress)}'
          '&region=ph'  // Bias results to Philippines
          '&key=$apiKey'),
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

    // Use driving mode for realistic travel distance in Philippines
    final response = await http.get(
      Uri.parse('$distanceMatrixUrl?origins=$originString'
          '&destinations=$destinationString'
          '&mode=driving'  // More accurate for fire station accessibility
          '&traffic_model=best_guess'  // Consider typical traffic
          '&departure_time=now'  // Current traffic conditions
          '&region=ph'  // Philippines-specific routing
          '&key=$apiKey'),
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
          // Fallback to straight-line distance if route fails
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
    // Haversine formula for straight-line distance
    const earthRadius = 6371; // Earth's radius in km

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