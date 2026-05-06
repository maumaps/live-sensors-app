import 'tokens.dart';

class Session {
  Tokens? tokens;

  Session({this.tokens});

  factory Session.fromJson(Map<String, dynamic> json) {
    final tokenJson = json['tokens'];
    return Session(
      tokens:
          tokenJson is Map<String, dynamic> ? Tokens.fromJson(tokenJson) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'tokens': tokens?.toJson(),
      };
}
