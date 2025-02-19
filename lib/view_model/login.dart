import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ndk/domain_layer/entities/account.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:ndk/shared/nips/nip19/nip19.dart';

class Account {
  final AccountType type;
  final String pubkey;
  final String? privateKey;

  Account._(
      {required this.type, required this.pubkey, this.privateKey});

  static Account nip19(String key) {
    final keyData = Nip19.decode(key);
    final pubkey =
        Nip19.isKey("nsec", key) ? Bip340.getPublicKey(keyData) : keyData;
    final privateKey = Nip19.isKey("npub", key) ? null : keyData;
    return Account._(
        type: AccountType.privateKey, pubkey: pubkey, privateKey: privateKey);
  }

  static Account privateKeyHex(String key) {
    return Account._(
        type: AccountType.privateKey,
        privateKey: key,
        pubkey: Bip340.getPublicKey(key));
  }

  static Account externalPublicKeyHex(String key) {
    return Account._(
        type: AccountType.externalSigner,
        pubkey: key);
  }

  static Map<String, dynamic> toJson(Account? acc) => {
        "type": acc?.type.name,
        "pubKey": acc?.pubkey,
        "privateKey": acc?.privateKey
      };

  static Account? fromJson(Map<String, dynamic> json) {
    if (json.length > 2 && json.containsKey("pubKey")) {
      return Account._(
          type: AccountType.privateKey,
          pubkey: json["pubKey"],
          privateKey: json["privateKey"]);
    }
    return null;
  }
}

class LoginData extends ValueNotifier<Account?> {
  final _storage = FlutterSecureStorage();
  static const String _StorageKey = "accounts";

  LoginData() : super(null) {
    super.addListener(() async {
      final data = json.encode(Account.toJson(this.value));
      await _storage.write(key: _StorageKey, value: data);
    });
  }

  Future<void> load() async {
    final acc = await _storage.read(key: _StorageKey);
    if (acc != null) {
      super.value = Account.fromJson(json.decode(acc));
    }
  }
}
