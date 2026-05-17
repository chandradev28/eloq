class GrammarCorrection {
  const GrammarCorrection({
    required this.original,
    required this.corrected,
    required this.explanation,
  });

  final String original;
  final String corrected;
  final String explanation;

  factory GrammarCorrection.fromJson(Map<String, dynamic> json) {
    return GrammarCorrection(
      original: json['original']?.toString() ?? '',
      corrected: json['corrected']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'original': original,
        'corrected': corrected,
        'explanation': explanation,
      };
}
