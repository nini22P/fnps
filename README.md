# FNPS

Flutter NoPayStation client

## Building

First add `.env` file

```
PSV_GAMES_URL=
PSV_DLCS_URL=
PSV_THEMES_URL=
PSV_UPDATES_URL=
PSV_DEMOS_URL=
PSP_GAMES_URL=
PSP_DLCS_URL=
PSP_THEMES_URL=
PSP_UPDATES_URL=
PSM_GAMES_URL=
PSX_GAMES_URL=
PS3_GAMES_URL=
PS3_DLCS_URL=
PS3_THEMES_URL=
PS3_DEMOS_URL=
HMAC_KEY=
```

### Android

Open `android/` folder on Android studio, select  `build` -> `Generate Signed Bundle or APK` -> `APK`, create a keystore on `android/` folder.

And create `key.properties` file on `android/` folder.

```
storePassword=<paaaword>
keyPassword=<password>
keyAlias=<alias>
storeFile=D:/xxx/fnps/android/keystore.jks
```

Open shell, run

``` shell
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter build apk
```

### Windows

``` shell
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter build windows
```


## Thanks and References

* [NoPayStation](https://nopaystation.com/)
* [IllusionMan1212 / NPS-Browser](https://github.com/IllusionMan1212/NPS-Browser)
* [mmozeiko / pkg2zip](https://github.com/mmozeiko/pkg2zip)
* [lusid1 / pkg2zip](https://github.com/lusid1/pkg2zip)
* [JeffreyO / pkg2zip](https://github.com/JeffreyO/pkg2zip)
* [nabil6391/flutter_download_manager](https://github.com/nabil6391/flutter_download_manager)
