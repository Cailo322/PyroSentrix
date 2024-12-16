import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  final String apiKey = 'AIzaSyD21izdTx2qn4vPFcFzkSDB5xhdWxtoXuM';
  final String baseUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
  final String detailsUrl = 'https://maps.googleapis.com/maps/api/place/details/json';
  final String distanceMatrixUrl = 'https://maps.googleapis.com/maps/api/distancematrix/json';

  Future<List<Map<String, dynamic>>> fetchFireStations(String userAddress) async {
    // Get location from user address
    final location = await _getLocationFromAddress(userAddress);
    final response = await http.get(
      Uri.parse('$baseUrl?location=${location['lat']},${location['lng']}&rankby=distance&type=fire_station&key=$apiKey'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      List<Map<String, dynamic>> stations = [];
      List<String> destinations = [];

      // Collect destination coordinates for Distance Matrix API
      for (var result in jsonResponse['results']) {
        final lat = result['geometry']['location']['lat'];
        final lng = result['geometry']['location']['lng'];
        destinations.add('$lat,$lng');

        stations.add({
          'name': result['name'],
          'address': result['vicinity'],
          'place_id': result['place_id'],
        });
      }

      // Use Distance Matrix API to calculate distances
      final distances = await _getDistances(location, destinations);

      // Combine results with distances
      for (int i = 0; i < stations.length; i++) {
        stations[i]['distance_km'] = distances[i]['distance']; // Travel distance in km
        stations[i]['duration'] = distances[i]['duration'];   // Travel time
      }

      // Sort by distance and fetch details for the top 2
      stations.sort((a, b) => double.parse(a['distance_km']).compareTo(double.parse(b['distance_km'])));
      List<Map<String, dynamic>> topStations = stations.take(2).toList();

      // Fetch details for the top 2 stations
      for (var station in topStations) {
        var details = await _getPlaceDetails(station['place_id']);
        station['contact'] = details['formatted_phone_number'] ?? 'N/A';
      }

      return topStations;
    } else {
      throw Exception('Failed to load fire stations');
    }
  }

  Future<Map<String, dynamic>> _getPlaceDetails(String placeId) async {
    final response = await http.get(
      Uri.parse('$detailsUrl?place_id=$placeId&key=$apiKey'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      return jsonResponse['result'];
    } else {
      throw Exception('Failed to load place details');
    }
  }

  Future<Map<String, double>> _getLocationFromAddress(String address) async {
    final response = await http.get(
      Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$apiKey'),
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
      throw Exception('Failed to get location from address');
    }
  }

  Future<List<Map<String, String>>> _getDistances(Map<String, double> origin, List<String> destinations) async {
    final originString = '${origin['lat']},${origin['lng']}';
    final destinationString = destinations.join('|');

    final response = await http.get(
      Uri.parse('$distanceMatrixUrl?origins=$originString&destinations=$destinationString&key=$apiKey'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      List<Map<String, String>> distances = [];

      for (var element in jsonResponse['rows'][0]['elements']) {
        distances.add({
          'distance': (element['distance']['value'] / 1000).toStringAsFixed(2), // Convert meters to km
          'duration': element['duration']['text'], // Travel time
        });
      }

      return distances;
    } else {
      throw Exception('Failed to get distances from Distance Matrix API');
    }
  }
}
