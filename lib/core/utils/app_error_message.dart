class AppErrorMessage {
  const AppErrorMessage._();

  static String from(Object error) {
    var message = error.toString().trim();
    for (final prefix in const [
      'Bad state: ',
      'StateError: ',
      'Exception: ',
      'TimeoutException: ',
    ]) {
      if (message.startsWith(prefix)) {
        message = message.substring(prefix.length).trim();
      }
    }

    final lower = message.toLowerCase();
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return 'The request took too long. Check your connection and try again.';
    }
    if (lower.contains('socket') || lower.contains('connection error')) {
      return 'Eloq could not reach the provider. Check your connection and try again.';
    }
    if (lower.contains('401') || lower.contains('unauthorized')) {
      return 'The API key was rejected. Check it in Settings.';
    }
    if (lower.contains('429') || lower.contains('rate limit')) {
      return 'This provider is temporarily rate limited. Try again shortly.';
    }
    return message.isEmpty
        ? 'Something went wrong. Please try again.'
        : message;
  }
}
