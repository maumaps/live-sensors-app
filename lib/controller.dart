import 'package:fk_user_agent/fk_user_agent.dart';
import 'package:live_sensors/app_config.dart';
import 'package:live_sensors/logger/logger.dart';
import 'package:live_sensors/session_storage/session_storage.dart';
import 'package:live_sensors/utils/state.dart';

import 'api/api_client.dart';
import 'entities/session.dart';
import 'entities/tokens.dart';
import 'entities/user.dart';
import 'fidelity/fidelity_collector.dart';
import 'geolocator/base_flow_geolocator.dart';
import 'geolocator/geolocator.dart';
import 'http_client/errors.dart';
import 'http_client/open_id_api.dart';
import 'http_client/open_id_client.dart';
import 'queue/queue.dart';
import 'sender.dart';
import 'sensors/sensors.dart';
import 'storage/storage.dart';
import 'tracker.dart';

class LoginFailedException implements Exception {
  final String? message;
  const LoginFailedException([this.message]);
}

// TODO Inject auti in api? or api in auth? How to refresh token
class AppControllerState {
  // Enabled tracking or not
  bool isTracking = false;
  // Application ready for work or not
  bool isBooted = false;
  // User authorized or not
  bool isAuthorized = false;
}

class AppController extends SimpleState<AppControllerState> {
  final Logger logger = Logger();
  /* Store snapshots on hard drive */
  final Storage storage = Storage();
  final GeoLocator geoLocator;
  final Sensors sensors;

  late ApiClient api;
  late OpenIdClient openIdClient;

  final SnapshotsQueue queue;
  /* Listen sensors and position, and creates new snapshots in queue */
  final Tracker tracker;

  /* Sends snapshots from queue */
  final Sender sender;
  final FidelityCollector fidelityCollector;

  AppController()
      : sensors = Sensors(),
        geoLocator = BaseFlowGeolocator(),
        queue = SnapshotsQueue(),
        tracker = Tracker(),
        sender = Sender(),
        fidelityCollector = const FidelityCollector();

  @override
  AppControllerState initState() {
    return AppControllerState();
  }

  // Create common application structure
  Future<void> init() async {
    await logger.init();
    await storage.init();
    SessionStorage sessionStorage = SessionStorage();
    Session session = Session();

    openIdClient = OpenIdClient(
      OpenIdApi(
        refreshPath: _configuredUri(
          AppConfig.openIdTokenUrl,
          'LIVE_SENSORS_OPENID_TOKEN_URL',
        ),
        clientId: _configuredValue(
          AppConfig.openIdClientId,
          'LIVE_SENSORS_OPENID_CLIENT_ID',
        ),
      ),
      postLogin: (tokens) {
        _postLogin(tokens);
        session.tokens = tokens;
        sessionStorage.saveSession(session);
      },
      postRefresh: (tokens) {
        session.tokens = tokens;
        sessionStorage.saveSession(session);
      },
      postLogout: () {
        _postLogout();
        sessionStorage.dropSession();
      },
    );

    api = ApiClient(openIdClient);

    session = await sessionStorage.restoreLast();
    Tokens? lastTokens = session.tokens;
    if (lastTokens != null) {
      try {
        await openIdClient.loginByTokens(lastTokens);
      } on AuthBackendUnavailableException catch (e) {
        logger.warn('Auth server unavailable, restored offline session ($e)');
      } catch (e) {
        logger.info('Tokens expired, re-logout ($e)');
      }
    }
    setState(() {
      state.isBooted = true;
    });
  }

  Uri _configuredUri(String value, String name) {
    return Uri.parse(_configuredValue(value, name));
  }

  String _configuredValue(String value, String name) {
    if (value.isEmpty) {
      throw StateError('$name must be provided with --dart-define.');
    }
    return value;
  }

  Future<void> login(String login, String password) async {
    try {
      await openIdClient.loginByPassword(email: login, password: password);
    } on BadCredentialsException catch (e) {
      throw LoginFailedException(e.message);
    }
  }

  Future<void> _postLogin(Tokens tokens) async {
    User user = User(id: tokens.sessionId);
    try {
      setState(() {
        state.isAuthorized = true;
      });
      await setup(user);
      start();
    } catch (e) {
      logger.error('Failed to start. Reason: ${e.toString()}');
    }
  }

  Future<void> setup(User user) async {
    try {
      await geoLocator.requestPermissions();
      await fidelityCollector.requestPermissions();
      sender.setup(
        api: api,
        storage: storage,
        queue: queue,
        user: user,
      );

      await FkUserAgent.init();
      String userAgent = FkUserAgent.userAgent ?? 'Unknown';

      tracker.setup(
        user: user,
        userAgent: userAgent,
        queue: queue,
        sensors: sensors.stream,
        position: geoLocator.getPositionStream(),
        fidelityCollector: fidelityCollector,
      );
    } catch (e) {
      logger.error(e.toString());
    }
  }

  void logout() {
    openIdClient.logout();
  }

  void _postLogout() {
    stop();
    setState(() {
      state.isAuthorized = false;
    });
  }

  void start() {
    tracker.track();
    sender.run();
    setState(() {
      state.isTracking = true;
    });
  }

  void stop() {
    tracker.dispose();
    queue.clear();
    sender.stop();
    setState(() {
      state.isTracking = false;
    });
  }

  void pause() {
    tracker.pause();
    setState(() {
      state.isTracking = false;
    });
  }

  void resume() {
    tracker.resume();
    setState(() {
      state.isTracking = true;
    });
  }
}
