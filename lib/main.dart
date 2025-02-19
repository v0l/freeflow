import 'package:amberflutter/amberflutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:freeflow/data/video.dart';
import 'package:freeflow/screens/create.dart';
import 'package:freeflow/screens/create_preview.dart';
import 'package:freeflow/screens/feed_screen.dart';
import 'package:freeflow/screens/layout.dart';
import 'package:freeflow/screens/login.dart';
import 'package:freeflow/screens/messages_screen.dart';
import 'package:freeflow/screens/new_account.dart';
import 'package:freeflow/screens/profile_screen.dart';
import 'package:freeflow/screens/search_screen.dart';
import 'package:freeflow/view_model/feed_viewmodel.dart';
import 'package:freeflow/view_model/login.dart';
import 'package:freeflow/widgets/short_video.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip19/nip19.dart';
import 'package:ndk_amber/data_layer/data_sources/amber_flutter.dart';
import 'package:ndk_amber/data_layer/repositories/signers/amber_event_signer.dart';
import 'package:ndk_objectbox/ndk_objectbox.dart';
import 'package:ndk_rust_verifier/data_layer/repositories/verifiers/rust_event_verifier.dart';

class NoVerify extends EventVerifier {
  @override
  Future<bool> verify(Nip01Event event) {
    return Future.value(true);
  }
}

final ndk_cache = DbObjectBox();
final eventVerifier = kDebugMode? NoVerify(): RustEventVerifier();
var ndk = Ndk(
  NdkConfig(
    eventVerifier: eventVerifier,
    cache: ndk_cache,
  ),
);

final SHORT_KIND = [22];
final USER_AGENT = "freeflow/1.0";
const DEFAULT_RELAYS = [
  "wss://nos.lol",
  "wss://relay.damus.io",
  "wss://relay.primal.net"
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final l = LoginData();

  // reload / cache login data
  l.addListener(() {
    if (l.value != null) {
      if (!ndk.accounts.hasAccount(l.value!.pubkey)) {
        switch (l.value!.type) {
          case AccountType.privateKey:
            ndk.accounts.loginPrivateKey(
                pubkey: l.value!.pubkey, privkey: l.value!.privateKey!);
          case AccountType.externalSigner:
            ndk.accounts.loginExternalSigner(
                signer: AmberEventSigner(publicKey: l.value!.pubkey,
                    amberFlutterDS: AmberFlutterDS(Amberflutter()))
            );
          case AccountType.publicKey:
            ndk.accounts.loginPublicKey(pubkey: l.value!.pubkey);
        }
      }
      ndk.metadata.loadMetadata(l.value!.pubkey);
      ndk.follows.getContactList(l.value!.pubkey);
    }
  });

  await l.load();

  GetIt.I.registerSingleton<FeedViewModel>(FeedViewModel());
  GetIt.I.registerSingleton<LoginData>(l);

  runApp(MaterialApp.router(
    routerConfig: GoRouter(routes: [
      StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              SafeArea(child: LayoutScreen(navigationShell), top: false),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: "/", builder: (context, state) => FeedScreen()),
              GoRoute(
                path: "/profile/:pubkey",
                builder: (context, state) =>
                    ProfileScreen(pubkey: state.pathParameters["pubkey"]!),
              ),
              GoRoute(
                  path: "/search", builder: (context, state) => SearchScreen()),
              GoRoute(
                path: "/messages",
                builder: (context, state) => MessagesScreen(),
              ),
              GoRoute(
                path: "/create",
                builder: (context, state) => CreateShortScreen(),
                routes: [
                  GoRoute(
                      path: "preview",
                      builder: (context, state) =>
                          CreatePreview(state.extra as List<RecordingSegment>)),
                ],
              ),
              GoRoute(
                  path: "/login",
                  builder: (context, state) => LoginScreen(),
                  routes: [
                    GoRoute(
                      path: "new",
                      builder: (context, state) => NewAccountScreen(),
                    )
                  ]),
              GoRoute(
                path: "/e/:id",
                builder: (ctx, state) {
                  if (state.extra is Nip01Event) {
                    return ShortVideoPlayer(
                        Video.fromEvent(state.extra as Nip01Event));
                  } else {
                    return FutureBuilder(
                      future: ndk.requests.query(
                        filters: [
                          Filter(
                            ids: [Nip19.decode(state.pathParameters["id"]!)],
                          ),
                        ],
                        timeout: Duration(seconds: 30),
                      ).future,
                      builder: (ctx, data) {
                        final ev = (data.data?.length ?? 0) > 0
                            ? data.data!.first
                            : null;
                        if (ev != null) {
                          return ShortVideoPlayer(Video.fromEvent(ev));
                        } else {
                          return Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                      },
                    );
                  }
                },
              )
            ]),
          ]),
    ]),
  ));
}

String formatSats(int n) {
  if (n > 1000000) {
    return (n / 1000000).toStringAsFixed(0) + "M";
  } else if (n > 1000) {
    return (n / 1000).toStringAsFixed(0) + "k";
  } else {
    return "${n}";
  }
}
