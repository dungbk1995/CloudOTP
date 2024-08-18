import 'dart:math';

import 'package:cloudotp/Utils/route_util.dart';
import 'package:cloudotp/Utils/utils.dart';
import 'package:cloudotp/Widgets/General/Unlock/gesture_notifier.dart';
import 'package:cloudotp/Widgets/General/Unlock/gesture_unlock_view.dart';
import 'package:cloudotp/Widgets/Window/window_caption.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../Utils/hive_util.dart';
import '../../Utils/responsive_util.dart';
import '../../Widgets/Item/item_builder.dart';
import '../../generated/l10n.dart';
import '../main_screen.dart';

class PinVerifyScreen extends StatefulWidget {
  const PinVerifyScreen({
    super.key,
    this.onSuccess,
    this.isModal = true,
    this.autoAuth = true,
    this.jumpToMain = false,
  });

  final bool isModal;
  final bool autoAuth;
  final bool jumpToMain;
  final Function()? onSuccess;
  static const String routeName = "/pin/verify";

  @override
  PinVerifyScreenState createState() => PinVerifyScreenState();
}

class PinVerifyScreenState extends State<PinVerifyScreen> with WindowListener{
  final String? _password = HiveUtil.getString(HiveUtil.guesturePasswdKey);
  late final bool _isUseBiometric =
      HiveUtil.getBool(HiveUtil.enableBiometricKey);
  late final GestureNotifier _notifier = GestureNotifier(
      status: GestureStatus.verify, gestureText: S.current.verifyGestureLock);
  final GlobalKey<GestureState> _gestureUnlockView = GlobalKey();

  @override
  Future<void> onWindowResized() async {
    super.onWindowResized();
    HiveUtil.setWindowSize(await windowManager.getSize());
  }

  @override
  Future<void> onWindowMoved() async {
    super.onWindowMoved();
    HiveUtil.setWindowPosition(await windowManager.getPosition());
  }

  @override
  void dispose() {
    super.dispose();
    windowManager.removeListener(this);
  }

  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
    if (_isUseBiometric && widget.autoAuth) {
      auth();
    }
  }

  void auth() async {
    Utils.localAuth(
      onAuthed: () {
        if (widget.onSuccess != null) widget.onSuccess!();
        if (widget.jumpToMain) {
          Navigator.of(context).pushReplacement(RouteUtil.getFadeRoute(
              ItemBuilder.buildContextMenuOverlay(const MainScreen())));
        } else {
          Navigator.of(context).pop();
        }
        _gestureUnlockView.currentState?.updateStatus(UnlockStatus.normal);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        right: false,
        child: Stack(
          children: [
            if (ResponsiveUtil.isDesktop()) const WindowMoveHandle(),
            Center(
              child: PopScope(
                canPop: !widget.isModal,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),
                    Text(
                      _notifier.gestureText,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 30),
                    Flexible(
                      child: GestureUnlockView(
                        key: _gestureUnlockView,
                        size: min(MediaQuery.sizeOf(context).width, 400),
                        padding: 60,
                        roundSpace: 40,
                        defaultColor: Colors.grey.withOpacity(0.5),
                        selectedColor: Theme.of(context).primaryColor,
                        failedColor: Colors.redAccent,
                        disableColor: Colors.grey,
                        solidRadiusRatio: 0.3,
                        lineWidth: 2,
                        touchRadiusRatio: 0.3,
                        onCompleted: _gestureComplete,
                      ),
                    ),
                    Visibility(
                      visible: _isUseBiometric,
                      child: GestureDetector(
                        onTap: () {
                          auth();
                        },
                        child: ItemBuilder.buildClickItem(
                          Text(
                            ResponsiveUtil.isWindows()
                                ? S.current.biometricVerifyPin
                                : S.current.biometricVerifyFingerprint,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _gestureComplete(List<int> selected, UnlockStatus status) async {
    switch (_notifier.status) {
      case GestureStatus.verify:
      case GestureStatus.verifyFailed:
        String password = GestureUnlockView.selectedToString(selected);
        if (_password == password) {
          if (widget.onSuccess != null) widget.onSuccess!();
          if (widget.jumpToMain) {
            Navigator.of(context).pushReplacement(RouteUtil.getFadeRoute(
                ItemBuilder.buildContextMenuOverlay(const MainScreen())));
          } else {
            Navigator.of(context).pop();
          }
          _gestureUnlockView.currentState?.updateStatus(UnlockStatus.normal);
        } else {
          setState(() {
            _notifier.setStatus(
              status: GestureStatus.verifyFailed,
              gestureText: S.current.gestureLockWrong,
            );
          });
          _gestureUnlockView.currentState?.updateStatus(UnlockStatus.failed);
        }
        break;
      case GestureStatus.verifyFailedCountOverflow:
      case GestureStatus.create:
      case GestureStatus.createFailed:
        break;
    }
  }
}
