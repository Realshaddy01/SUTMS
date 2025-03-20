import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sutms/models/violation.dart';
import 'package:sutms/utils/api_constants.dart';

class ViolationProvider with ChangeNotifier {
  List<Violation> _violations = [];
  bool _isLoading = false;
  String? _error;

  List<Violation> get violations => [..._violations];
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchViolations(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/violations/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode != 200) {
        _error = 'Failed to load violations';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final List<dynamic> responseData = json.decode(response.body);
      final List<Violation> loadedViolations = [];
      
      for (var item in responseData) {
        loadedViolations.add(Violation.fromJson(item));
      }

      _violations = loadedViolations;
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _error = 'Could not fetch violations. Please try again later.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> reportViolation(String token, String vehicleNumber, String violationType, String location, File image) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}/violations/report/'),
      );

      request.headers.addAll({
        'Authorization': 'Token $token',
      });

      request.fields['vehicle_number'] = vehicleNumber;
      request.fields['violation_type'] = violationType;
      request.fields['location'] = location;

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          image.path,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 201) {
        final responseData = json.decode(response.body);
        _error = responseData['detail'] ?? 'Failed to report violation';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Refresh violations list
      await fetchViolations(token);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      _error = 'Could not report violation. Please try again later.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Violation?> getViolationDetails(String token, int violationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/violations/$violationId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode != 200) {
        _error = 'Failed to load violation details';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      final responseData = json.decode(response.body);
      final violation = Violation.fromJson(responseData);

      _isLoading = false;
      notifyListeners();
      return violation;
    } catch (error) {
      _error = 'Could not fetch violation details. Please try again later.';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}

