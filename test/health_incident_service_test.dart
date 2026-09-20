import 'package:flutter_test/flutter_test.dart';
import 'package:hamster_project/services/health_incident_service.dart';

void main() {
  test('incident document id matches the server mapping', () {
    expect(
      healthIncidentDocumentId('environment:humidity_high'),
      'environment__humidity_high',
    );
  });
}
