import 'package:flutter_test/flutter_test.dart';
import 'package:brain_mantra/utils/network_error.dart';

void main() {
  group('isOfflineError', () {
    test('recognizes a SocketException-shaped message', () {
      expect(
        isOfflineError(Exception('SocketException: Failed host lookup')),
        isTrue,
      );
    });

    test('recognizes the exact chain confirmed on a real offline device test '
        '(FunctionsFetchException wrapping ClientException wrapping '
        'SocketException)', () {
      final error = Exception(
        'FunctionsFetchException(status: 0, details: ClientException with '
        'SocketException: Connection reset by peer (OS Error: Connection '
        'reset by peer, errno = 104), address = example.supabase.co, '
        'port = 443)',
      );
      expect(isOfflineError(error), isTrue);
    });

    test('recognizes a timeout', () {
      expect(
        isOfflineError(Exception('TimeoutException after 0:00:10.000000')),
        isTrue,
      );
    });

    test('does not misclassify an ordinary server/validation error', () {
      expect(
        isOfflineError(Exception('PostgrestException: row not found')),
        isFalse,
      );
    });

    test('does not misclassify the "Supabase not initialized" assertion this '
        "codebase's own widget tests always hit", () {
      expect(
        isOfflineError(
          StateError(
            'You must initialize the supabase instance before calling '
            'Supabase.instance',
          ),
        ),
        isFalse,
      );
    });
  });
}
