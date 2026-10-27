/// A presentation contract shared by current Silver and immutable Gold readers.
/// These supplied numbers never define a health score or a healthy range.
class WeightResearchComparison {
  const WeightResearchComparison({
    required this.individualWeightGrams,
    required this.referenceMedianGrams,
    required this.referenceP25Grams,
    required this.referenceP75Grams,
  });

  final double individualWeightGrams;
  final double referenceMedianGrams;
  final double referenceP25Grams;
  final double referenceP75Grams;

  bool get isValid =>
      [
        individualWeightGrams,
        referenceMedianGrams,
        referenceP25Grams,
        referenceP75Grams
      ].every((value) => value.isFinite && value > 0) &&
      referenceP25Grams <= referenceMedianGrams &&
      referenceMedianGrams <= referenceP75Grams;
}
