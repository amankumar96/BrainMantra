/// Thrown whenever [evaluate] can't produce a trustworthy number — a
/// malformed expression, an unrecognized character, or a division by
/// zero. Never silently returns a wrong value; always throws instead.
class EvaluationException implements Exception {
  final String message;
  const EvaluationException(this.message);

  @override
  String toString() => 'EvaluationException: $message';
}

/// Calculates the result of a simple arithmetic expression string, such as
/// `"(3 + 4) × 2"`, respecting standard order of operations (parentheses,
/// then multiply/divide, then add/subtract) — the same way a person would
/// solve it by hand.
///
/// Supports `+ - × ÷` (and their ASCII equivalents `* /`), parentheses,
/// and unary minus. Throws [EvaluationException] rather than ever
/// returning a silently-wrong answer.
num evaluate(String expression) {
  final tokens = _tokenize(expression);
  final parser = _Parser(tokens);
  final result = parser.parseExpression();
  parser.expectEnd(); // reject leftover input like "3 + 4)" or "3 4"
  return result;
}

/// Turns a raw expression string into a flat list of tokens (numbers,
/// operators, parentheses) that the parser below can walk one at a time.
/// Doing this as a separate pass keeps the parser itself simple — it never
/// has to think about whitespace or character-by-character scanning.
List<String> _tokenize(String expression) {
  // The UI displays × and ÷; normalize them to the ASCII operators the
  // rest of this function understands before scanning anything else.
  final normalized = expression.replaceAll('×', '*').replaceAll('÷', '/');
  final tokens = <String>[];
  var i = 0;

  while (i < normalized.length) {
    final char = normalized[i];

    if (char == ' ' || char == '\t' || char == '\n') {
      i++;
      continue;
    }

    if ('+-*/()'.contains(char)) {
      tokens.add(char);
      i++;
      continue;
    }

    if (_isDigit(char) || char == '.') {
      // Consume a whole number token: digits with at most one decimal
      // point, e.g. "12" or "3.5".
      final start = i;
      var sawDecimalPoint = false;
      while (i < normalized.length &&
          (_isDigit(normalized[i]) ||
              (normalized[i] == '.' && !sawDecimalPoint))) {
        if (normalized[i] == '.') sawDecimalPoint = true;
        i++;
      }
      final numberText = normalized.substring(start, i);
      if (numberText.isEmpty || numberText == '.') {
        throw EvaluationException(
          'Malformed number near position $start in "$expression"',
        );
      }
      tokens.add(numberText);
      continue;
    }

    throw EvaluationException(
      'Unexpected character "$char" at position $i in "$expression"',
    );
  }

  return tokens;
}

bool _isDigit(String char) {
  final code = char.codeUnitAt(0);
  return code >= 0x30 && code <= 0x39; // '0'..'9'
}

/// A small recursive-descent parser encoding standard arithmetic
/// precedence directly in its call structure:
/// `expr := term (('+'|'-') term)*`
/// `term := factor (('*'|'/') factor)*`
/// `factor := NUMBER | '(' expr ')' | '-' factor`
/// Each level only ever calls the level below it for a single value, which
/// is what makes `×`/`÷` bind tighter than `+`/`-` and parentheses bind
/// tightest of all — no separate precedence table needed.
class _Parser {
  final List<String> _tokens;
  int _position = 0;

  _Parser(this._tokens);

  /// The token at the current read position, or null once every token has
  /// been consumed.
  String? get _current => _position < _tokens.length
      ? _tokens[_position]
      : null;

  void _advance() => _position++;

  /// Handles the lowest-precedence operators: + and -.
  num parseExpression() {
    var value = parseTerm();
    while (_current == '+' || _current == '-') {
      final operator = _current!;
      _advance();
      final rightHandSide = parseTerm();
      value = operator == '+' ? value + rightHandSide : value - rightHandSide;
    }
    return value;
  }

  /// Handles the higher-precedence operators: × and ÷. Because
  /// [parseExpression] calls this *before* looking for +/-, every ×/÷ in a
  /// chain like "3 + 4 × 2" gets fully resolved before the addition does.
  num parseTerm() {
    var value = parseFactor();
    while (_current == '*' || _current == '/') {
      final operator = _current!;
      _advance();
      final rightHandSide = parseFactor();
      if (operator == '/') {
        if (rightHandSide == 0) {
          throw const EvaluationException('Division by zero');
        }
        value = value / rightHandSide;
      } else {
        value = value * rightHandSide;
      }
    }
    return value;
  }

  /// The smallest unit: a plain number, a parenthesized sub-expression
  /// (which recurses all the way back to [parseExpression], letting
  /// parentheses override normal precedence), or a unary minus.
  num parseFactor() {
    final token = _current;
    if (token == null) {
      throw const EvaluationException(
        'Unexpected end of expression — missing an operand',
      );
    }

    if (token == '-') {
      _advance();
      return -parseFactor();
    }

    if (token == '(') {
      _advance();
      final value = parseExpression();
      if (_current != ')') {
        throw const EvaluationException('Missing closing parenthesis');
      }
      _advance();
      return value;
    }

    final number = num.tryParse(token);
    if (number == null) {
      throw EvaluationException('Expected a number, found "$token"');
    }
    _advance();
    return number;
  }

  /// Called after parsing the top-level expression — rejects anything left
  /// over, e.g. the stray ")" in "3 + 4)" or a second expression bolted on
  /// with no operator like "3 4".
  void expectEnd() {
    if (_current != null) {
      throw EvaluationException('Unexpected trailing input: "$_current"');
    }
  }
}
