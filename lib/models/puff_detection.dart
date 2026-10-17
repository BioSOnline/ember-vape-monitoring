class PuffDetection {
  // Bounding box center and size, normalized to [0, 1] relative to image dimensions.
  final double x;
  final double y;
  final double width;
  final double height;
  final double confidence;
  final int classId; // 0=Vape, 1=cigarette, 2=iqos, 3=trubka

  PuffDetection({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
    required this.classId,
  });

  // Top edge of the device/cigarette (usually the tip that touches lips)
  double get topY => (y - height / 2).clamp(0.0, 1.0);
  double get bottomY => (y + height / 2).clamp(0.0, 1.0);
  double get leftX => (x - width / 2).clamp(0.0, 1.0);
  double get rightX => (x + width / 2).clamp(0.0, 1.0);

  // Check if the smoking device is positioned in the mouth / lips proximity zone
  // Face & mouth region in typical front camera usage:
  // Horizontally centered: 0.20 to 0.80
  // Vertically in mouth/chin region: 0.22 to 0.72 (tip or center near lips)
  bool get isNearMouth {
    final bool horizontalInZone = x >= 0.20 && x <= 0.80;
    final bool verticalInZone = (topY <= 0.72 && bottomY >= 0.22) || (y >= 0.24 && y <= 0.72);
    return horizontalInZone && verticalInZone && confidence >= 0.25;
  }

  bool get isPuffEvent => classId >= 0 && classId <= 3 && isNearMouth && confidence >= 0.28;

  bool get isVape => classId == 0 || classId == 2;
  bool get isCigarette => classId == 1 || classId == 3;

  String get className {
    switch (classId) {
      case 0:
        return 'Vape';
      case 1:
        return 'Cigarette';
      case 2:
        return 'Vape'; // Consolidated IQOS -> Vape
      case 3:
        return 'Trubka';
      default:
        return 'Unknown';
    }
  }

  Map<String, double> toPixelCoordinates(int imageWidth, int imageHeight) {
    return {
      'left': (x - width / 2) * imageWidth,
      'top': (y - height / 2) * imageHeight,
      'right': (x + width / 2) * imageWidth,
      'bottom': (y + height / 2) * imageHeight,
      'width': width * imageWidth,
      'height': height * imageHeight,
    };
  }

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(0)}%';

  PuffDetection copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? confidence,
    int? classId,
  }) {
    return PuffDetection(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      confidence: confidence ?? this.confidence,
      classId: classId ?? this.classId,
    );
  }

  @override
  String toString() {
    return 'PuffDetection(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, w: ${width.toStringAsFixed(2)}, h: ${height.toStringAsFixed(2)}, conf: $confidencePercent, class: $className, nearMouth: $isNearMouth)';
  }
}
