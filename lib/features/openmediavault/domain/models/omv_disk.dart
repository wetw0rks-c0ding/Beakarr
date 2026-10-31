import 'omv_parse.dart';

class OmvDisk {
  final String? devicename;
  final String? devicefile;
  final String? model;
  final String? vendor;
  final String? serialnumber;
  final int? sizeBytes;
  final int? temperatureC;
  final String? powerMode;
  final bool isRaid;
  final bool isRoot;
  final bool isReadonly;
  final bool hotpluggable;
  final String? description;

  const OmvDisk({
    this.devicename,
    this.devicefile,
    this.model,
    this.vendor,
    this.serialnumber,
    this.sizeBytes,
    this.temperatureC,
    this.powerMode,
    this.isRaid = false,
    this.isRoot = false,
    this.isReadonly = false,
    this.hotpluggable = false,
    this.description,
  });

  factory OmvDisk.fromJson(Map<String, dynamic> json) {
    final temp = json['temperature'];
    int? tempC;
    if (temp is int) {
      tempC = temp;
    } else if (temp is num) {
      tempC = temp.toInt();
    } else {
      final s = temp?.toString().trim() ?? '';
      if (s.isNotEmpty && s != '""') {
        tempC = int.tryParse(s);
      }
    }
    return OmvDisk(
      devicename: asString(json['devicename']),
      devicefile: asString(json['devicefile']),
      model: asString(json['model']),
      vendor: asString(json['vendor']),
      serialnumber: asString(json['serialnumber']),
      sizeBytes: bytesFromString(json['size']),
      temperatureC: tempC,
      powerMode: asString(json['powermode']),
      isRaid: asBool(json['israid']),
      isRoot: asBool(json['isroot']),
      isReadonly: asBool(json['isreadonly']),
      hotpluggable: asBool(json['hotpluggable']),
      description: asString(json['description']),
    );
  }
}