import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  final String? psvGamesUrl = _checkEnv(dotenv.env['PSV_GAMES_URL']);
  final String? psvDLCsUrl = _checkEnv(dotenv.env['PSV_DLCS_URL']);
  final String? psvThemesUrl = _checkEnv(dotenv.env['PSV_THEMES_URL']);
  final String? psvUpdatesUrl = _checkEnv(dotenv.env['PSV_UPDATES_URL']);
  final String? psvDemosUrl = _checkEnv(dotenv.env['PSV_DEMOS_URL']);
  final String? pspGamesUrl = _checkEnv(dotenv.env['PSP_GAMES_URL']);
  final String? pspDLCsUrl = _checkEnv(dotenv.env['PSP_DLCS_URL']);
  final String? pspThemesUrl = _checkEnv(dotenv.env['PSP_THEMES_URL']);
  final String? pspUpdatesUrl = _checkEnv(dotenv.env['PSP_UPDATES_URL']);
  final String? psmGamesUrl = _checkEnv(dotenv.env['PSM_GAMES_URL']);
  final String? psxGamesUrl = _checkEnv(dotenv.env['PSX_GAMES_URL']);
  final String? ps3GamesUrl = _checkEnv(dotenv.env['PS3_GAMES_URL']);
  final String? ps3DLCsUrl = _checkEnv(dotenv.env['PS3_DLCS_URL']);
  final String? ps3ThemesUrl = _checkEnv(dotenv.env['PS3_THEMES_URL']);
  final String? ps3DemosUrl = _checkEnv(dotenv.env['PS3_DEMOS_URL']);
  final String? hmacKey = _checkEnv(dotenv.env['HMAC_KEY']);
}

String? _checkEnv(String? env) => env != null
    ? env.isEmpty
        ? null
        : env
    : null;
