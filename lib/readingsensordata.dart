// ignore_for_file: constant_identifier_names

enum DataType {
  RESISTANCE,
  FDR_VOLTAGE,
  TEMPERATURE,
  R_HUMIDITY, // Relative Humidity
  A_TEMPERATURE, // Air Temperature
  S_RADIATION, // Solar Radiation
  UNSPECIFIED
}

extension DataTypeExtension on DataType {
  String get name {
    switch (this) {
      case DataType.RESISTANCE:
        return "Resistance Soil Moisture";
      case DataType.FDR_VOLTAGE:
        return "FDR Voltage";
      case DataType.TEMPERATURE:
        return "Soil Temperature";
      case DataType.R_HUMIDITY:
        return "Relative Humidity";
      case DataType.A_TEMPERATURE:
        return "Air Temperature";
      case DataType.S_RADIATION:
        return "Solar Radiation";
      case DataType.UNSPECIFIED:
      default:
        return "Unspecified";
    }
  }
}

class ParsedSensorData {
  final DataType type;
  final double value;

  ParsedSensorData(this.type, this.value);

  static double parseDouble(String v) {
    if (v.trim().toLowerCase() == 'inf') {
      return double.infinity;
    } else {
      return double.tryParse(v) ?? double.nan;
    }
  }

  static ParsedSensorData fromDeviceData(String d) {
    // Splitting the string by the colon and space
    var parts = d.split(':');
    if (parts.length < 2) {
      return ParsedSensorData(DataType.UNSPECIFIED, double.nan);
    }

    String dataType = parts[0].trim();
    String sValue = parts[1].trim();

    DataType type = DataType.UNSPECIFIED;
    switch (dataType) {
      case "SM":
        type = DataType.RESISTANCE;
        break;
      case "FD":
        type = DataType.FDR_VOLTAGE;
        break;
      case "ST":
        type = DataType.TEMPERATURE;
        break;
      case "RH":
        type = DataType.R_HUMIDITY;
        break;
      case "AT":
        type = DataType.A_TEMPERATURE;
        break;
      case "SR":
        type = DataType.S_RADIATION;
        break;
      // Add other cases as needed
    }

    double value = parseDouble(sValue);
    return ParsedSensorData(type, value);
  }
}
