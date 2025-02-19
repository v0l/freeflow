import 'package:flutter/material.dart';
import 'package:freeflow/main.dart';
import 'package:freeflow/view_model/login.dart';
import 'package:freeflow/widgets/button.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ndk/config/bootstrap_relays.dart';
import 'package:ndk/domain_layer/entities/metadata.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:ndk/shared/nips/nip01/key_pair.dart';

class NewAccountScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _NewAccountScreen();
}

class _NewAccountScreen extends State<NewAccountScreen> {
  TextEditingController _name = TextEditingController();
  String? _avatar;
  String? _error;
  KeyPair _privateKey = Bip340.generatePrivateKey();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(10, 40, 10, 10),
        child: Column(
          spacing: 40,
          children: [
            GestureDetector(
              onTap: () {
                _uploadAvatar().catchError((e) {
                  setState(() {
                    if (e is String) {
                      _error = e;
                    }
                  });
                });
              },
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(200)),
                  color: Color.fromARGB(100, 50, 50, 50),
                ),
                child: Center(child: Text("Upload Avatar")),
              ),
            ),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: "Username",
              ),
            ),
            BasicButton.text("Login", onTap: () {
              _login().then((_) {
                GetIt.I.get<LoginData>().value =
                    Account.privateKeyHex(_privateKey.privateKey!);
                context.go("/");
              }).catchError((e) {
                setState(() {
                  if (e is String) {
                    _error = e;
                  }
                });
              });
            }),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadAvatar() async {
    ndk.accounts.loginPrivateKey(pubkey: _privateKey.publicKey, privkey: _privateKey.privateKey!);

    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) {
      final upload =
          await ndk.blossom.uploadBlob(data: await file.readAsBytes());
      setState(() {
        _avatar = upload.first.descriptor!.url;
      });
    }
  }

  Future<void> _login() async {
    if (ndk.accounts.isNotLoggedIn) {
      ndk.accounts.loginPrivateKey(
          pubkey: _privateKey.publicKey, privkey: _privateKey.privateKey!);
    }

    await ndk.metadata.broadcastMetadata(Metadata(
      pubKey: _privateKey.publicKey,
      name: _name.text,
      picture: _avatar,
    ));
  }
}
