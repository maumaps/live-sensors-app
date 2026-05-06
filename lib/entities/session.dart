import 'tokens.dart';

class Session {
  Tokens? tokens;

  Session({this.tokens});

  factory Session.fromJson(Map<String, dynamic> json) {
    final tokenJson = json['tokens'];
    return Session(
      tokens: tokenJson == null ? null : Tokens.fromJson(tokenJson),
    );
  }

  Map<String, dynamic> toJson() => {
        'tokens': tokens?.toJson(),
      };
}
