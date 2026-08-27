class AppConstants {
  const AppConstants._();

  static const appName = 'Eloq';
  static const xpPerMessageSent = 10;
  static const xpPerCorrectionReceived = 5;
  static const xpPerNewWordSaved = 15;
  static const xpPerConversationCompleted = 50;
  static const xpPerStreakDay = 25;

  static const levels = [
    LevelDefinition('Beginner', 0),
    LevelDefinition('Building', 200),
    LevelDefinition('Active', 500),
    LevelDefinition('Consistent', 1000),
    LevelDefinition('Committed', 2000),
    LevelDefinition('Focused', 4000),
    LevelDefinition('Fluent', 7000),
    LevelDefinition('Advanced', 11000),
    LevelDefinition('Eloquent', 16000),
    LevelDefinition('Mastery', 25000),
  ];
}

class LevelDefinition {
  const LevelDefinition(this.name, this.xpRequired);

  final String name;
  final int xpRequired;
}
