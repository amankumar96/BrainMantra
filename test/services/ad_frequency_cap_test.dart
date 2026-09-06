import 'package:flutter_test/flutter_test.dart';
import 'package:math_blitz/services/ad_frequency_cap.dart';

void main() {
  group('AdFrequencyCap', () {
    test('is not due before questionsBetweenAds questions are recorded', () {
      final cap = AdFrequencyCap(questionsBetweenAds: 10);
      for (var i = 0; i < 9; i++) {
        cap.recordQuestionAnswered();
        expect(cap.isDue, isFalse);
      }
    });

    test('becomes due exactly at questionsBetweenAds questions', () {
      final cap = AdFrequencyCap(questionsBetweenAds: 10);
      for (var i = 0; i < 10; i++) {
        cap.recordQuestionAnswered();
      }
      expect(cap.isDue, isTrue);
    });

    test('recordAdShown resets the counter back to not-due', () {
      final cap = AdFrequencyCap(questionsBetweenAds: 10);
      for (var i = 0; i < 10; i++) {
        cap.recordQuestionAnswered();
      }
      expect(cap.isDue, isTrue);

      cap.recordAdShown();

      expect(cap.isDue, isFalse);
    });

    test('is due again after another full cycle post-reset', () {
      final cap = AdFrequencyCap(questionsBetweenAds: 10);
      for (var i = 0; i < 10; i++) {
        cap.recordQuestionAnswered();
      }
      cap.recordAdShown();

      for (var i = 0; i < 9; i++) {
        cap.recordQuestionAnswered();
        expect(cap.isDue, isFalse);
      }
      cap.recordQuestionAnswered();
      expect(cap.isDue, isTrue);
    });

    test('a non-default questionsBetweenAds behaves identically - the '
        'logic is not hardcoded to 10', () {
      final cap = AdFrequencyCap(questionsBetweenAds: 3);
      cap.recordQuestionAnswered();
      cap.recordQuestionAnswered();
      expect(cap.isDue, isFalse);
      cap.recordQuestionAnswered();
      expect(cap.isDue, isTrue);
    });

    test('defaults to 10 questions between ads when unspecified', () {
      final cap = AdFrequencyCap();
      for (var i = 0; i < 9; i++) {
        cap.recordQuestionAnswered();
      }
      expect(cap.isDue, isFalse);
      cap.recordQuestionAnswered();
      expect(cap.isDue, isTrue);
    });

    test('never due with zero questions recorded', () {
      final cap = AdFrequencyCap();
      expect(cap.isDue, isFalse);
    });
  });
}
