import 'omv_parse.dart';

class OmvSmartDevice {
  final String? devicename;
  final String? devicefile;
  final String? model;
  final String? serialnumber;
  final int? temperatureC;
  final String overallStatus;
  final bool monitorEnabled;

  const OmvSmartDevice({
    this.devicename,
    this.devicefile,
    this.model,
    this.serialnumber,
    this.temperatureC,
    this.overallStatus = '',
    this.monitorEnabled = false,
  });

  factory OmvSmartDevice.fromJson(Map<String, dynamic> json) {
    final temp = json['temperature'];
    int? tempC;
    if (temp is int) {
      tempC = temp;
    } else if (temp is num) {
      tempC = temp.toInt();
    } else {
      final s = temp?.toString().trim() ?? '';
      if (s.isNotEmpty) tempC = int.tryParse(s);
    }
    return OmvSmartDevice(
      devicename: asString(json['devicename']),
      devicefile: asString(json['devicefile']),
      model: asString(json['model']),
      serialnumber: asString(json['serialnumber']),
      temperatureC: tempC,
      overallStatus: asString(json['overallstatus']) ?? '',
      monitorEnabled: asBool(json['monitor']),
    );
  }

  bool get isHealthy => smartAssessmentIsHealthy(overallStatus);
}