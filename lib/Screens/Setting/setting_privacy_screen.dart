import 'package:cloudotp/Screens/Setting/setting_screen.dart';
import 'package:cloudotp/Widgets/BottomSheet/input_password_bottom_sheet.dart';
import 'package:cloudotp/Widgets/Dialog/dialog_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../Database/database_manager.dart';
import '../../Utils/app_provider.dart';
import '../../Utils/hive_util.dart';
import '../../Utils/itoast.dart';
import '../../Utils/responsive_util.dart';
import '../../Utils/route_util.dart';
import '../../Widgets/BottomSheet/bottom_sheet_builder.dart';
import '../../Widgets/BottomSheet/list_bottom_sheet.dart';
import '../../Widgets/Item/item_builder.dart';
import '../../generated/l10n.dart';
import '../Lock/pin_change_screen.dart';
import '../Lock/pin_verify_screen.dart';

class PrivacySettingScreen extends StatefulWidget {
  const PrivacySettingScreen({super.key});

  static const String routeName = "/setting/privacy";

  @override
  State<PrivacySettingScreen> createState() => _PrivacySettingScreenState();
}

class _PrivacySettingScreenState extends State<PrivacySettingScreen>
    with TickerProviderStateMixin {
  bool _enableGuesturePasswd =
      HiveUtil.getBool(HiveUtil.enableGuesturePasswdKey);
  bool _hasGuesturePasswd =
      HiveUtil.getString(HiveUtil.guesturePasswdKey) != null &&
          HiveUtil.getString(HiveUtil.guesturePasswdKey)!.isNotEmpty;
  bool _autoLock = HiveUtil.getBool(HiveUtil.autoLockKey);
  bool _enableSafeMode = HiveUtil.getBool(HiveUtil.enableSafeModeKey);
  bool _enableBiometric = HiveUtil.getBool(HiveUtil.enableBiometricKey);
  bool _biometricAvailable = false;
  EncryptDatabaseStatus _encryptDatabaseStatus =
      HiveUtil.getEncryptDatabaseStatus();

  @override
  void initState() {
    super.initState();
    initBiometricAuthentication();
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Scaffold(
        appBar: ResponsiveUtil.isLandscape()
            ? ItemBuilder.buildSimpleAppBar(
                title: S.current.safeSetting,
                context: context,
                transparent: true,
              )
            : ItemBuilder.buildAppBar(
                context: context,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                leading: Icons.arrow_back_rounded,
                onLeadingTap: () {
                  Navigator.pop(context);
                },
                title: Text(
                  S.current.setting,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.apply(fontWeightDelta: 2),
                ),
                center: true,
                actions: [
                  ItemBuilder.buildBlankIconButton(context),
                  const SizedBox(width: 5),
                ],
              ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            children: [
              ..._privacySettings(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  _privacySettings() {
    return [
      const SizedBox(height: 10),
      ItemBuilder.buildCaptionItem(
          context: context, title: S.current.safeSetting),
      ItemBuilder.buildRadioItem(
        context: context,
        value: _enableGuesturePasswd,
        title: S.current.enableGestureLock,
        description: S.current.enableGestureLockTip,
        onTap: onEnablePinTapped,
      ),
      Visibility(
        visible: _enableGuesturePasswd,
        child: ItemBuilder.buildEntryItem(
          context: context,
          title: _hasGuesturePasswd
              ? S.current.changeGestureLock
              : S.current.setGestureLock,
          description:
              _hasGuesturePasswd ? "" : S.current.haveToSetGestureLockTip,
          onTap: onChangePinTapped,
        ),
      ),
      Visibility(
        visible:
            _enableGuesturePasswd && _hasGuesturePasswd && _biometricAvailable,
        child: ItemBuilder.buildRadioItem(
          context: context,
          value: _enableBiometric,
          disabled: ResponsiveUtil.isMacOS() || ResponsiveUtil.isLinux(),
          title: S.current.biometric,
          description: S.current.biometricTip,
          onTap: onBiometricTapped,
        ),
      ),
      Visibility(
        visible: _enableGuesturePasswd && _hasGuesturePasswd,
        child: ItemBuilder.buildRadioItem(
          context: context,
          value: _autoLock,
          title: S.current.autoLock,
          description: S.current.autoLockTip,
          onTap: onEnableAutoLockTapped,
        ),
      ),
      Visibility(
        visible: _enableGuesturePasswd && _hasGuesturePasswd && _autoLock,
        child: Selector<AppProvider, int>(
          selector: (context, appProvider) => appProvider.autoLockTime,
          builder: (context, autoLockTime, child) => ItemBuilder.buildEntryItem(
            context: context,
            title: S.current.autoLockDelay,
            tip: AppProvider.getAutoLockOptionLabel(autoLockTime),
            onTap: () {
              BottomSheetBuilder.showListBottomSheet(
                context,
                (context) => TileList.fromOptions(
                  AppProvider.getAutoLockOptions(),
                  (item2) {
                    appProvider.autoLockTime = item2;
                    Navigator.pop(context);
                  },
                  selected: autoLockTime,
                  context: context,
                  title: S.current.chooseAutoLockDelay,
                  onCloseTap: () => Navigator.pop(context),
                ),
              );
            },
          ),
        ),
      ),
      ItemBuilder.buildRadioItem(
        context: context,
        value: _enableSafeMode,
        title: S.current.safeMode,
        disabled: ResponsiveUtil.isDesktop(),
        description: S.current.safeModeTip,
        onTap: onSafeModeTapped,
      ),
      ItemBuilder.buildEntryItem(
        context: context,
        bottomRadius:
            _encryptDatabaseStatus == EncryptDatabaseStatus.defaultPassword,
        title: S.current.editEncryptDatabasePassword,
        description: S.current.encryptDatabaseTip,
        tip: _encryptDatabaseStatus == EncryptDatabaseStatus.defaultPassword
            ? S.current.defaultEncryptDatabasePassword
            : S.current.customEncryptDatabasePassword,
        onTap: () {
          BottomSheetBuilder.showBottomSheet(
            context,
            responsive: true,
            (context) => InputPasswordBottomSheet(
              title: S.current.editEncryptDatabasePassword,
              message: S.current.editEncryptDatabasePasswordTip,
              onConfirm: (passord, confirmPassword) async {},
              onValidConfirm: (passord, confirmPassword) async {
                bool res = await DatabaseManager.changePassword(passord);
                if (res) {
                  IToast.showTop(S.current.editSuccess);
                  HiveUtil.setEncryptDatabaseStatus(
                      EncryptDatabaseStatus.customPassword);
                  setState(() {
                    _encryptDatabaseStatus =
                        EncryptDatabaseStatus.customPassword;
                  });
                } else {
                  IToast.showTop(S.current.editFailed);
                }
              },
            ),
          );
        },
      ),
      Visibility(
        visible: _encryptDatabaseStatus == EncryptDatabaseStatus.customPassword,
        child: ItemBuilder.buildEntryItem(
          context: context,
          title: S.current.clearEncryptDatabasePassword,
          description: S.current.clearEncryptDatabasePasswordTip,
          bottomRadius: true,
          onTap: () {
            DialogBuilder.showConfirmDialog(
              context,
              title: S.current.clearEncryptDatabasePassword,
              message: S.current.clearEncryptDatabasePasswordTip,
              onTapConfirm: () async {
                bool res = await DatabaseManager.changePassword(
                    await HiveUtil.regeneratePassword());
                if (res) {
                  HiveUtil.setEncryptDatabaseStatus(
                      EncryptDatabaseStatus.defaultPassword);
                  setState(() {
                    _encryptDatabaseStatus =
                        EncryptDatabaseStatus.defaultPassword;
                  });
                  IToast.showTop(S.current.clearEncryptDatabasePasswordSuccess);
                } else {
                  IToast.showTop(S.current.clearEncryptDatabasePasswordFailed);
                }
              },
              onTapCancel: () {},
            );
          },
        ),
      ),
    ];
  }

  initBiometricAuthentication() async {
    LocalAuthentication localAuth = LocalAuthentication();
    bool available = await localAuth.canCheckBiometrics;
    setState(() {
      _biometricAvailable = available;
    });
  }

  onEnablePinTapped() {
    setState(() {
      RouteUtil.pushCupertinoRoute(
        context,
        PinVerifyScreen(
          onSuccess: () {
            setState(() {
              _enableGuesturePasswd = !_enableGuesturePasswd;
              IToast.showTop(_enableGuesturePasswd
                  ? S.current.enableGestureLockSuccess
                  : S.current.disableGestureLockSuccess);
              HiveUtil.put(
                  HiveUtil.enableGuesturePasswdKey, _enableGuesturePasswd);
              _hasGuesturePasswd =
                  HiveUtil.getString(HiveUtil.guesturePasswdKey) != null &&
                      HiveUtil.getString(HiveUtil.guesturePasswdKey)!
                          .isNotEmpty;
            });
          },
          isModal: false,
        ),
      );
    });
  }

  onBiometricTapped() {
    if (!_enableBiometric) {
      RouteUtil.pushCupertinoRoute(
        context,
        PinVerifyScreen(
          onSuccess: () {
            IToast.showTop(S.current.enableBiometricSuccess);
            setState(() {
              _enableBiometric = !_enableBiometric;
              HiveUtil.put(HiveUtil.enableBiometricKey, _enableBiometric);
            });
          },
          isModal: false,
        ),
      );
    } else {
      setState(() {
        _enableBiometric = !_enableBiometric;
        HiveUtil.put(HiveUtil.enableBiometricKey, _enableBiometric);
      });
    }
  }

  onChangePinTapped() {
    setState(() {
      RouteUtil.pushCupertinoRoute(context, const PinChangeScreen())
          .then((value) {
        setState(() {
          _hasGuesturePasswd =
              HiveUtil.getString(HiveUtil.guesturePasswdKey) != null &&
                  HiveUtil.getString(HiveUtil.guesturePasswdKey)!.isNotEmpty;
        });
      });
    });
  }

  onEnableAutoLockTapped() {
    setState(() {
      _autoLock = !_autoLock;
      HiveUtil.put(HiveUtil.autoLockKey, _autoLock);
    });
  }

  onSafeModeTapped() {
    setState(() {
      _enableSafeMode = !_enableSafeMode;
      if (ResponsiveUtil.isMobile()) {
        if (_enableSafeMode) {
          FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
        } else {
          FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
        }
      }
      HiveUtil.put(HiveUtil.enableSafeModeKey, _enableSafeMode);
    });
  }
}
