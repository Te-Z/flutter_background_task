import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:background_fetch/background_fetch.dart';

/// POC execution tâche en arrière plan
/// Source: https://pub.dev/packages/background_fetch
/// iOS: ouvrir runner.xcworkspace dans XCODE puis Targets -> Runner -> Capabilities -> Ajouter "Background Modes"
/// -> cocher "background fetch"
///
/// Pour debugger:
/// iOS: Dans XCode: Debug->Simulate Background Fetch
/// Android:
/// - observer les logs du plugin: adb logcat *:S flutter:V, TSBackgroundFetch:V
/// - simuler un fetch en arrière plan (sdk >21): adb shell cmd jobscheduler run -f <your.application.id> 999
/// - simuler un fetch en arrière plan (sdk <21): adb shell am broadcast -a <your.application.id>.event.BACKGROUND_FETCH
///

/// Cette méthode est lancée dès que l'app est fermée
void backgroundFetchHeadlessTask() async {
  print('[BackgroundFetch] Headless event received.');
  BackgroundFetch.finish();
}

void main() {
  runApp(new MyApp());

  /// __Android-only__: Préviens l'application qu'il faut lancer backgroundFetchHeadlessTask quand elle sera terminée
  /// Nécessite [BackgroundFetchConfig.stopOnTerminate] `false` (voir ligne 43) et [BackgroundFetchConfig.enableHeadless] `true` (voir ligne 44).
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _enabled = true;
  int _status = 0;
  List<DateTime> _events = [];

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  /// La communication avec les plateformes est asynchrone, on utilise donc une méthone asynchrone.
  /// Sur iOS et Android l'intervale minimale est 15 minutues
  /// iOS gère seul les background fetch, et Android les effectue au départ à l'intervalle donné puis va les optimiser en fonction de
  /// l'usage de l'application, de l'appareil et de la batterie.
  /// Si l'application effectue des tâches trop longues en arrière plan ( > 30s), le système va pénaliser l'application
  Future<void> initPlatformState() async {
    /// Configuration de BackgroundFetch
    BackgroundFetch.configure(BackgroundFetchConfig(
        minimumFetchInterval: 15,
        stopOnTerminate: false,
        enableHeadless: true,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresStorageNotLow: false,
        requiresDeviceIdle: false,
        requiredNetworkType: BackgroundFetchConfig.NETWORK_TYPE_NONE
    ), () async {
      /// Callback contenant l'action à effectuer pendant que l'application est fermée
      print('[BackgroundFetch] Event received');
      setState(() {
        _events.insert(0, new DateTime.now());
      });
      /// IMPORTANT: Vous devez signaler explicitement la fin de la tâche sous peine de voir l'application pénalisée par l'OS
      /// du fait d'une tâche trop longue en background
      BackgroundFetch.finish();
    }).then((int status) {
      print('[BackgroundFetch] configure success: $status');
      setState(() {
        _status = status;
      });
    }).catchError((e) {
      print('[BackgroundFetch] configure ERROR: $e');
      setState(() {
        _status = e;
      });
    });

    /// Optionnel: récupère le status de BackgroundFetch
    int status = await BackgroundFetch.status;
    setState(() {
      _status = status;
    });

    /// Si le widget a été retirer de l'arborescence pendant que la tâche était en cours
    /// il est mieux d'abandonner la réponse plutôt que d'appeler setState pour rafraichir notre
    /// interface non existante
    if (!mounted) return;
  }

  void _onClickEnable(enabled) {
    setState(() {
      _enabled = enabled;
    });
    if (enabled) {
      BackgroundFetch.start().then((int status) {
        print('[BackgroundFetch] start success: $status');
      }).catchError((e) {
        print('[BackgroundFetch] start FAILURE: $e');
      });
    } else {
      BackgroundFetch.stop().then((int status) {
        print('[BackgroundFetch] stop success: $status');
      });
    }
  }

  void _onClickStatus() async {
    int status = await BackgroundFetch.status;
    print('[BackgroundFetch] status: $status');
    setState(() {
      _status = status;
    });
  }
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
            title: const Text('BackgroundFetch Example', style: TextStyle(color: Colors.black)),
            backgroundColor: Colors.amberAccent,
            brightness: Brightness.light,
            actions: <Widget>[
              Switch(value: _enabled, onChanged: _onClickEnable),
            ]
        ),
        body: Container(
          color: Colors.black,
          child: new ListView.builder(
              itemCount: _events.length,
              itemBuilder: (BuildContext context, int index) {
                DateTime timestamp = _events[index];
                return InputDecorator(
                    decoration: InputDecoration(
                        contentPadding: EdgeInsets.only(left: 10.0, top: 10.0, bottom: 0.0),
                        labelStyle: TextStyle(color: Colors.amberAccent, fontSize: 20.0),
                        labelText: "[background fetch event]"
                    ),
                    child: new Text(timestamp.toString(), style: TextStyle(color: Colors.white, fontSize: 16.0))
                );
              }
          ),
        ),
        bottomNavigationBar: BottomAppBar(
            child: Row(
                children: <Widget>[
                  RaisedButton(onPressed: _onClickStatus, child: Text('Status')),
                  Container(child: Text("$_status"), margin: EdgeInsets.only(left: 20.0))
                ]
            )
        ),
      ),
    );
  }
}
