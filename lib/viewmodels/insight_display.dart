/// Ready-to-render text, independent of evidence metric and storage scope.
class InsightDisplay {
  final String id, text, periodLabel, evidenceLabel;
  final bool discovery;
  const InsightDisplay(
      {required this.id,
      required this.text,
      required this.periodLabel,
      required this.evidenceLabel,
      this.discovery = true});
}
