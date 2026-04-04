class ActivityDistributionBin {
  final double start;
  final double end;
  final int count;
  final String label;

  const ActivityDistributionBin({
    required this.start,
    required this.end,
    required this.count,
    required this.label,
  });
}

class ActivityDistribution {
  final List<ActivityDistributionBin> bins;
  final double markerValue;
  final String markerCaption;
  final String bandLabel;
  final double p10;
  final double p25;
  final double p50;
  final double p75;
  final double p90;

  const ActivityDistribution({
    required this.bins,
    required this.markerValue,
    required this.markerCaption,
    required this.bandLabel,
    required this.p10,
    required this.p25,
    required this.p50,
    required this.p75,
    required this.p90,
  });

  bool get hasData => bins.isNotEmpty;
}
