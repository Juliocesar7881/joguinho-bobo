import 'models.dart';

abstract final class WordEvaluator {
  static GuessResult evaluate({required String answer, required String guess}) {
    assert(answer.length == guess.length);
    final marks = List<LetterMark>.filled(answer.length, LetterMark.absent);
    final remaining = <String, int>{};

    for (var index = 0; index < answer.length; index++) {
      if (answer[index] == guess[index]) {
        marks[index] = LetterMark.correct;
      } else {
        remaining.update(
          answer[index],
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    for (var index = 0; index < guess.length; index++) {
      if (marks[index] == LetterMark.correct) continue;
      final letter = guess[index];
      final available = remaining[letter] ?? 0;
      if (available > 0) {
        marks[index] = LetterMark.present;
        remaining[letter] = available - 1;
      }
    }

    return GuessResult(word: guess, marks: List.unmodifiable(marks));
  }

  static Map<String, LetterMark> keyboardMarks(Iterable<GuessResult> guesses) {
    final result = <String, LetterMark>{};
    for (final guess in guesses) {
      for (var index = 0; index < guess.word.length; index++) {
        final letter = guess.word[index];
        final mark = guess.marks[index];
        final current = result[letter];
        if (current == null || mark.index > current.index) {
          result[letter] = mark;
        }
      }
    }
    return Map.unmodifiable(result);
  }
}
