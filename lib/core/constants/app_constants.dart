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
    LevelDefinition('Tourist', 200),
    LevelDefinition('Explorer', 500),
    LevelDefinition('Conversationalist', 1000),
    LevelDefinition('Communicator', 2000),
    LevelDefinition('Storyteller', 4000),
    LevelDefinition('Debater', 7000),
    LevelDefinition('Articulate', 11000),
    LevelDefinition('Eloquent', 16000),
    LevelDefinition('Native Speaker', 25000),
  ];
}

class LevelDefinition {
  const LevelDefinition(this.name, this.xpRequired);

  final String name;
  final int xpRequired;
}
