class SimpleState<S> {
  final List<void Function(S)> _listeners = <void Function(S)>[];
  late S state;

  SimpleState() {
    state = initState();
  }

  S initState() {
    return state;
  }

  void setState(void Function() update) {
    update();
    _notify();
  }

  void _notify() {
    for (final listener in _listeners) {
      listener(state);
    }
  }

  void Function() subscribe(void Function(S) listener) {
    _listeners.add(listener);
    Future(() => listener(state));
    return () {
      _listeners.remove(listener);
    };
  }
}
