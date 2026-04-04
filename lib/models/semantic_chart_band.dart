enum SemanticBandKey {
  low,
  normal,
  high,
}

class SemanticChartBand {
  final double start;
  final double end;
  final SemanticBandKey bandKey;

  const SemanticChartBand({
    required this.start,
    required this.end,
    required this.bandKey,
  });
}
