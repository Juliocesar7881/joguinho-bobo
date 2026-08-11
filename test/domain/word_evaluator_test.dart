import 'package:flutter_test/flutter_test.dart';
import 'package:lexinexo/src/domain/models.dart';
import 'package:lexinexo/src/domain/word_evaluator.dart';

void main() {
  group('WordEvaluator', () {
    test('marca posições corretas, presentes e ausentes', () {
      final result = WordEvaluator.evaluate(answer: 'crate', guess: 'tracy');
      expect(result.marks, <LetterMark>[
        LetterMark.present,
        LetterMark.correct,
        LetterMark.correct,
        LetterMark.present,
        LetterMark.absent,
      ]);
    });

    test('não valida ocorrências repetidas além das disponíveis', () {
      final result = WordEvaluator.evaluate(answer: 'level', guess: 'eerie');
      expect(result.marks, <LetterMark>[
        LetterMark.present,
        LetterMark.correct,
        LetterMark.absent,
        LetterMark.absent,
        LetterMark.absent,
      ]);
    });

    test('consome exatas antes de distribuir letras presentes', () {
      final result = WordEvaluator.evaluate(answer: 'apple', guess: 'alley');
      expect(result.marks, <LetterMark>[
        LetterMark.correct,
        LetterMark.present,
        LetterMark.absent,
        LetterMark.present,
        LetterMark.absent,
      ]);
    });

    test('uma letra repetida excedente fica ausente depois do consumo', () {
      final result = WordEvaluator.evaluate(answer: 'letter', guess: 'teller');
      expect(result.marks, <LetterMark>[
        LetterMark.present,
        LetterMark.correct,
        LetterMark.present,
        LetterMark.absent,
        LetterMark.correct,
        LetterMark.correct,
      ]);
    });

    test(
      'combina exatas e repetidas dos dois lados sem reutilizar ocorrencia',
      () {
        final result = WordEvaluator.evaluate(answer: 'cacao', guess: 'cocoa');
        expect(result.marks, <LetterMark>[
          LetterMark.correct,
          LetterMark.present,
          LetterMark.correct,
          LetterMark.absent,
          LetterMark.present,
        ]);
      },
    );

    test('teclado preserva o melhor estado observado', () {
      final marks = WordEvaluator.keyboardMarks(<GuessResult>[
        const GuessResult(
          word: 'ace',
          marks: <LetterMark>[
            LetterMark.absent,
            LetterMark.present,
            LetterMark.absent,
          ],
        ),
        const GuessResult(
          word: 'bad',
          marks: <LetterMark>[
            LetterMark.absent,
            LetterMark.correct,
            LetterMark.absent,
          ],
        ),
      ]);
      expect(marks['a'], LetterMark.correct);
      expect(marks['c'], LetterMark.present);
      expect(marks['e'], LetterMark.absent);
    });

    test('teclado nunca rebaixa correta para presente ou ausente', () {
      final marks = WordEvaluator.keyboardMarks(<GuessResult>[
        const GuessResult(
          word: 'aaa',
          marks: <LetterMark>[
            LetterMark.correct,
            LetterMark.present,
            LetterMark.absent,
          ],
        ),
        const GuessResult(
          word: 'aba',
          marks: <LetterMark>[
            LetterMark.absent,
            LetterMark.absent,
            LetterMark.present,
          ],
        ),
      ]);

      expect(marks['a'], LetterMark.correct);
      expect(marks['b'], LetterMark.absent);
    });
  });
}
