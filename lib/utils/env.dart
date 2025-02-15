import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  final String? psvGamesUrl = dotenv.env['PSV_GAMES_URL'];
  final String? psvDLCsUrl = dotenv.env['PSV_DLCS_URL'];
  final String? psvThemesUrl = dotenv.env['PSV_THEMES_URL'];
  final String? psvUpdatesUrl = dotenv.env['PSV_UPDATES_URL'];
  final String? psvDemosUrl = dotenv.env['PSV_DEMOS_URL'];
  final String? pspGamesUrl = dotenv.env['PSP_GAMES_URL'];
  final String? pspDLCsUrl = dotenv.env['PSP_DLCS_URL'];
  final String? pspThemesUrl = dotenv.env['PSP_THEMES_URL'];
  final String? pspUpdatesUrl = dotenv.env['PSP_UPDATES_URL'];
  final String? psmGamesUrl = dotenv.env['PSM_GAMES_URL'];
  final String? psxGamesUrl = dotenv.env['PSX_GAMES_URL'];
  final String? ps3GamesUrl = dotenv.env['PS3_GAMES_URL'];
  final String? ps3DLCsUrl = dotenv.env['PS3_DLCS_URL'];
  final String? ps3ThemesUrl = dotenv.env['PS3_THEMES_URL'];
  final String? ps3DemosUrl = dotenv.env['PS3_DEMOS_URL'];
  final String? hmacKey = dotenv.env['HMAC_KEY'];
}
