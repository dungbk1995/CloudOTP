/*
 * Copyright (c) 2024 Robert-Stackflow.
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
 * even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.
 * If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloudotp/Database/token_dao.dart';
import 'package:cloudotp/Screens/Token/add_token_screen.dart';
import 'package:cloudotp/Screens/home_screen.dart';
import 'package:cloudotp/TokenUtils/code_generator.dart';
import 'package:cloudotp/TokenUtils/otp_token_parser.dart';
import 'package:cloudotp/Utils/hive_util.dart';
import 'package:cloudotp/Utils/responsive_util.dart';
import 'package:cloudotp/Utils/route_util.dart';
import 'package:cloudotp/Widgets/BottomSheet/select_category_bottom_sheet.dart';
import 'package:cloudotp/Widgets/BottomSheet/token_option_bottom_sheet.dart';
import 'package:cloudotp/Widgets/Dialog/dialog_builder.dart';
import 'package:cloudotp/Widgets/Item/item_builder.dart';
import 'package:context_menus/context_menus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../Models/opt_token.dart';
import '../../Utils/app_provider.dart';
import '../../Utils/asset_util.dart';
import '../../Utils/constant.dart';
import '../../Utils/itoast.dart';
import '../../Utils/utils.dart';
import '../../Widgets/BottomSheet/bottom_sheet_builder.dart';
import '../../Widgets/BottomSheet/select_icon_bottom_sheet.dart';
import '../../generated/l10n.dart';

class TokenLayout extends StatefulWidget {
  const TokenLayout({
    super.key,
    required this.token,
    required this.layoutType,
  });

  final OtpToken token;

  final LayoutType layoutType;

  @override
  State<TokenLayout> createState() => TokenLayoutState();
}

class TokenLayoutNotifier extends ChangeNotifier {
  String _code = "";

  String get code => _code;

  set code(String value) {
    _code = value;
    notifyListeners();
  }

  bool _codeVisiable = !HiveUtil.getBool(HiveUtil.defaultHideCodeKey);

  bool get codeVisiable => _codeVisiable;

  set codeVisiable(bool value) {
    _codeVisiable = value;
    notifyListeners();
  }

  bool _haveToResetHOTP = false;

  bool get haveToResetHOTP => _haveToResetHOTP;

  set haveToResetHOTP(bool value) {
    _haveToResetHOTP = value;
    notifyListeners();
  }
}

class TokenLayoutState extends State<TokenLayout>
    with TickerProviderStateMixin {
  Timer? _timer;

  TokenLayoutNotifier tokenLayoutNotifier = TokenLayoutNotifier();

  final ValueNotifier<double> progressNotifier = ValueNotifier(0);

  int get remainingMilliseconds => widget.token.period == 0
      ? 0
      : widget.token.period * 1000 -
          (DateTime.now().millisecondsSinceEpoch %
              (widget.token.period * 1000));

  double get currentProgress => widget.token.period == 0
      ? 0
      : remainingMilliseconds / (widget.token.period * 1000);

  bool get isYandex => widget.token.tokenType == OtpTokenType.Yandex;

  bool get isHOTP => widget.token.tokenType == OtpTokenType.HOTP;

  @override
  void dispose() {
    _timer?.cancel();
    tokenLayoutNotifier.dispose();
    super.dispose();
  }

  updateInfo({
    bool counterChanged = false,
  }) {
    setState(() {});
    if (isHOTP && counterChanged) {
      tokenLayoutNotifier.codeVisiable = true;
      resetTimer();
    }
  }

  @override
  void initState() {
    super.initState();
    updateCode();
    progressNotifier.value = currentProgress;
    resetTimer();
  }

  resetTimer() {
    tokenLayoutNotifier.haveToResetHOTP = false;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        progressNotifier.value = currentProgress;
        if (remainingMilliseconds <= 180 && appProvider.autoHideCode) {
          tokenLayoutNotifier.codeVisiable = false;
        }
        updateCode();
        if (remainingMilliseconds <= 100) {
          tokenLayoutNotifier.haveToResetHOTP = true;
          tokenLayoutNotifier.code = getNextCode();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildContextMenuRegion();
  }

  String getCurrentCode() {
    return CodeGenerator.getCurrentCode(widget.token);
  }

  getNextCode() {
    return CodeGenerator.getNextCode(widget.token);
  }

  _buildContextMenuButtons() {
    return GenericContextMenu(
      buttonConfigs: [
        ContextMenuButtonConfig(S.current.copyTokenCode,
            onPressed: _processCopyCode),
        ContextMenuButtonConfig(S.current.copyNextTokenCode,
            onPressed: _processCopyNextCode),
        ContextMenuButtonConfig.divider(),
        ContextMenuButtonConfig(
            widget.token.pinned ? S.current.unPinToken : S.current.pinToken,
            textColor:
                widget.token.pinned ? Theme.of(context).primaryColor : null,
            onPressed: _processPin),
        ContextMenuButtonConfig(S.current.editToken, onPressed: _processEdit),
        ContextMenuButtonConfig(S.current.editTokenIcon,
            onPressed: _processEditIcon),
        ContextMenuButtonConfig(S.current.editTokenCategory,
            onPressed: _processEditCategory),
        ContextMenuButtonConfig.divider(),
        ContextMenuButtonConfig(S.current.viewTokenQrCode,
            onPressed: _processViewQrCode),
        ContextMenuButtonConfig(S.current.copyTokenUri,
            onPressed: _processCopyUri),
        ContextMenuButtonConfig.divider(),
        ContextMenuButtonConfig.warning(S.current.resetCopyTimes,
            textColor: Colors.red, onPressed: _processResetCopyTimes),
        ContextMenuButtonConfig.warning(S.current.deleteToken,
            textColor: Colors.red, onPressed: _processDelete),
      ],
    );
  }

  _buildContextMenuRegion() {
    return ContextMenuRegion(
      key: ValueKey("contextMenuRegion${widget.token.keyString}"),
      behavior: ResponsiveUtil.isDesktop()
          ? const [ContextMenuShowBehavior.secondaryTap]
          : const [],
      contextMenu: _buildContextMenuButtons(),
      child: Selector<AppProvider, bool>(
        selector: (context, provider) => provider.dragToReorder,
        builder: (context, dragToReorder, child) => GestureDetector(
          onLongPress: dragToReorder && !ResponsiveUtil.isDesktop()
              ? () {
                  showContextMenu();
                  HapticFeedback.lightImpact();
                }
              : null,
          child: _buildBody(),
        ),
      ),
    );
  }

  _buildSlidable({
    required Widget child,
    bool simple = false,
    double startExtentRatio = 0.16,
    double endExtentRatio = 0.64,
  }) {
    return Slidable(
      groupTag: "TokenLayout",
      enabled: !ResponsiveUtil.isWideLandscape(),
      startActionPane: ActionPane(
        extentRatio: startExtentRatio,
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _processPin(),
            backgroundColor: widget.token.pinned
                ? Theme.of(context).primaryColor
                : Theme.of(context).cardColor,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            foregroundColor: Theme.of(context).primaryColor,
            icon: widget.token.pinned
                ? Icons.push_pin_rounded
                : Icons.push_pin_outlined,
            label: widget.token.pinned
                ? S.current.unPinTokenShort
                : S.current.pinTokenShort,
            simple: simple,
            spacing: 8,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            iconAndTextColor: widget.token.pinned ? Colors.white : null,
          ),
          const SizedBox(width: 6),
        ],
      ),
      endActionPane: ActionPane(
        extentRatio: endExtentRatio,
        motion: const ScrollMotion(),
        children: [
          const SizedBox(width: 6),
          SlidableAction(
            onPressed: (context) => _processViewQrCode(),
            backgroundColor: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            foregroundColor: Theme.of(context).primaryColor,
            icon: Icons.qr_code_rounded,
            label: S.current.viewTokenQrCodeShort,
            spacing: 8,
            simple: simple,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          const SizedBox(width: 6),
          SlidableAction(
            onPressed: (context) => _processEdit(),
            backgroundColor: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            foregroundColor: Theme.of(context).primaryColor,
            icon: Icons.edit_outlined,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            label: S.current.editTokenShort,
            simple: simple,
            spacing: 8,
          ),
          const SizedBox(width: 6),
          SlidableAction(
            onPressed: (context) => showContextMenu(),
            backgroundColor: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            foregroundColor: Theme.of(context).primaryColor,
            icon: Icons.more_vert_rounded,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            label: S.current.moreOptionShort,
            simple: simple,
            spacing: 8,
          ),
          const SizedBox(width: 6),
          SlidableAction(
            onPressed: (context) => _processDelete(),
            backgroundColor: Colors.red,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            foregroundColor: Theme.of(context).primaryColor,
            icon: Icons.delete,
            simple: simple,
            label: S.current.deleteTokenShort,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            spacing: 8,
            iconAndTextColor: Colors.white,
          ),
        ],
      ),
      child: child,
    );
  }

  _buildBody() {
    switch (widget.layoutType) {
      case LayoutType.Simple:
        return _buildSimpleLayout();
      case LayoutType.Compact:
        return _buildCompactLayout();
      // case LayoutType.Tile:
      //   return _buildSlidable(
      //     startExtentRatio: 0.23,
      //     endExtentRatio: 0.9,
      //     child: _buildTileLayout(),
      //   );
      case LayoutType.List:
        return _buildSlidable(
          simple: true,
          child: _buildListLayout(),
        );
      case LayoutType.Spotlight:
        return _buildSlidable(
          startExtentRatio: 0.21,
          endExtentRatio: 0.8,
          child: _buildSpotlightLayout(),
        );
    }
  }

  showContextMenu() {
    if (ResponsiveUtil.isLandscape()) {
      BottomSheetBuilder.showBottomSheet(
        context,
        responsive: true,
        (context) => TokenOptionBottomSheet(token: widget.token),
      );
    } else {
      BottomSheetBuilder.showBottomSheet(
        context,
        responsive: true,
        (context) => TokenOptionBottomSheet(token: widget.token),
      );
    }
  }

  _processCopyCode() {
    Utils.copy(context, getCurrentCode());
    TokenDao.incTokenCopyTimes(widget.token);
  }

  _processCopyNextCode() {
    Utils.copy(context, getNextCode());
    TokenDao.incTokenCopyTimes(widget.token);
  }

  _processEdit() {
    RouteUtil.pushDialogRoute(context, AddTokenScreen(token: widget.token),
        showClose: false);
  }

  _processPin() async {
    await TokenDao.updateTokenPinned(widget.token, !widget.token.pinned);
    IToast.showTop(
      widget.token.pinned
          ? S.current.alreadyPinnedToken(widget.token.title)
          : S.current.alreadyUnPinnedToken(widget.token.title),
    );
    homeScreenState?.updateToken(widget.token, pinnedStateChanged: true);
  }

  _processEditIcon() {
    BottomSheetBuilder.showBottomSheet(
      context,
      responsive: true,
      (context) => SelectIconBottomSheet(
        token: widget.token,
        onSelected: (path) => {},
        doUpdate: true,
      ),
    );
  }

  _processEditCategory() {
    BottomSheetBuilder.showBottomSheet(
      context,
      responsive: true,
      (context) => SelectCategoryBottomSheet(token: widget.token),
    );
  }

  _processViewQrCode() {
    DialogBuilder.showQrcodesDialog(
      context,
      title: widget.token.title,
      qrcodes: [OtpTokenParser.toUri(widget.token).toString()],
      asset: AssetUtil.getBrandPath(widget.token.imagePath),
    );
  }

  _processCopyUri() {
    DialogBuilder.showConfirmDialog(
      context,
      title: S.current.copyUriClearWarningTitle,
      message: S.current.copyUriClearWarningTip,
      onTapConfirm: () {
        Utils.copy(context, OtpTokenParser.toUri(widget.token));
      },
      onTapCancel: () {},
    );
  }

  _processResetCopyTimes() {
    DialogBuilder.showConfirmDialog(
      context,
      title: S.current.resetCopyTimesTitle,
      message: S.current.resetCopyTimesMessage(widget.token.title),
      onTapConfirm: () async {
        await TokenDao.resetSingleTokenCopyTimes(widget.token);
        homeScreenState?.resetCopyTimesSingle(widget.token);
        IToast.showTop(S.current.resetSuccess);
      },
      onTapCancel: () {},
    );
  }

  _processDelete() {
    DialogBuilder.showConfirmDialog(
      context,
      title: S.current.deleteTokenTitle(widget.token.title),
      message: S.current.deleteTokenMessage(widget.token.title),
      onTapConfirm: () async {
        await TokenDao.deleteToken(widget.token);
        IToast.showTop(S.current.deleteTokenSuccess(widget.token.title));
        homeScreenState?.removeToken(widget.token);
      },
      onTapCancel: () {},
    );
  }

  _buildVisibleLayout(Function(bool) builder) {
    return ChangeNotifierProvider.value(
      value: tokenLayoutNotifier,
      child: Selector<TokenLayoutNotifier, bool>(
        selector: (context, tokenLayoutNotifier) =>
            tokenLayoutNotifier.codeVisiable,
        builder: (context, codeVisiable, child) => builder(codeVisiable),
      ),
    );
  }

  _buildVisibleLayoutWithEye(Function(bool) builder) {
    return _buildVisibleLayout(
      (codeVisiable) => Selector<AppProvider, bool>(
        selector: (context, provider) => provider.showEye,
        builder: (context, showEye, child) =>
            showEye ? builder(codeVisiable) : builder(true),
      ),
    );
  }

  _buildEyeButton({
    double padding = 8,
    Color? color,
  }) {
    return _buildVisibleLayout(
      (codeVisiable) {
        if (codeVisiable) return emptyWidget;
        return Selector<AppProvider, bool>(
          selector: (context, provider) => provider.showEye,
          builder: (context, showEye, child) => showEye
              ? Container(
                  child: ItemBuilder.buildIconButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      tokenLayoutNotifier.codeVisiable =
                          !tokenLayoutNotifier.codeVisiable;
                      setState(() {});
                    },
                    padding: EdgeInsets.all(padding),
                    icon: Icon(
                      Icons.visibility_outlined,
                      size: 20,
                      color: color ??
                          Theme.of(context).textTheme.labelMedium?.color,
                    ),
                    context: context,
                  ),
                )
              : emptyWidget,
        );
      },
    );
  }

  _buildHOTPRefreshButton({
    double padding = 8,
    Color? color,
  }) {
    return ChangeNotifierProvider.value(
      value: tokenLayoutNotifier,
      child: Selector<TokenLayoutNotifier, bool>(
        selector: (context, tokenLayoutNotifier) =>
            tokenLayoutNotifier.haveToResetHOTP,
        builder: (context, haveToResetHOTP, child) => haveToResetHOTP
            ? Container(
                child: ItemBuilder.buildIconButton(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.token.counterString =
                        (widget.token.counter + 1).toString();
                    TokenDao.updateTokenCounter(widget.token);
                    tokenLayoutNotifier.codeVisiable = true;
                    resetTimer();
                    setState(() {});
                  },
                  padding: EdgeInsets.all(padding),
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color:
                        color ?? Theme.of(context).textTheme.labelMedium?.color,
                  ),
                  context: context,
                ),
              )
            : emptyWidget,
      ),
    );
  }

  _buildCodeLayout({
    double letterSpacing = 5,
    double fontSize = 24,
    AlignmentGeometry alignment = Alignment.centerLeft,
    bool forceNoType = false,
  }) {
    return _buildVisibleLayout(
      (codeVisiable) => ChangeNotifierProvider.value(
        value: tokenLayoutNotifier,
        child: Selector<TokenLayoutNotifier, String>(
          selector: (context, tokenLayoutNotifier) => tokenLayoutNotifier.code,
          builder: (context, code, child) => ValueListenableBuilder(
            valueListenable: progressNotifier,
            builder: (context, value, _) => Container(
              alignment: alignment,
              child: AutoSizeText(
                codeVisiable
                    ? code
                    : (isHOTP ? hotpPlaceholderText : placeholderText) *
                        widget.token.digits.digit,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: fontSize,
                      letterSpacing: letterSpacing,
                      color: progressNotifier.value >
                          autoCopyNextCodeProgressThrehold
                          ? Theme.of(context).primaryColor
                          : Colors.red,
                    ),
                maxLines: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  _buildLinearProgress([bool hideProgressBar = false]) {
    return isHOTP || hideProgressBar
        ? const SizedBox(height: 1)
        : ValueListenableBuilder(
            valueListenable: progressNotifier,
            builder: (context, progress, child) {
              return Container(
                constraints: const BoxConstraints(minHeight: 2, maxHeight: 2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  color: progress > autoCopyNextCodeProgressThrehold
                      ? Theme.of(context).primaryColor
                      : Colors.red,
                  borderRadius: BorderRadius.circular(5),
                  backgroundColor: Colors.grey.withOpacity(0.3),
                ),
              );
            },
          );
  }

  _buildCircleProgress() {
    return Selector<AppProvider, bool>(
      selector: (context, provider) => provider.hideProgressBar,
      builder: (context, hideProgressBar, child) => hideProgressBar
          ? const SizedBox.shrink()
          : Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(left: 8, right: 4),
              child: Stack(
                children: [
                  ValueListenableBuilder(
                    valueListenable: progressNotifier,
                    builder: (context, value, child) {
                      return CircularProgressIndicator(
                        value: progressNotifier.value,
                        color: progressNotifier.value >
                                autoCopyNextCodeProgressThrehold
                            ? Theme.of(context).primaryColor
                            : Colors.red,
                        backgroundColor: Colors.grey.withOpacity(0.3),
                        strokeCap: StrokeCap.round,
                      );
                    },
                  ),
                  Center(
                    child: ValueListenableBuilder(
                      valueListenable: progressNotifier,
                      builder: (context, value, child) {
                        return Text(
                          (remainingMilliseconds / 1000).toStringAsFixed(0),
                          style: Theme.of(context).textTheme.bodyMedium?.apply(
                                color: currentProgress >
                                        autoCopyNextCodeProgressThrehold
                                    ? Theme.of(context).primaryColor
                                    : Colors.red,
                                fontSizeDelta: -3,
                              ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  updateCode() {
    if (appProvider.autoDisplayNextCode &&
        currentProgress < autoCopyNextCodeProgressThrehold) {
      tokenLayoutNotifier.code = getNextCode();
    } else {
      tokenLayoutNotifier.code = getCurrentCode();
    }
  }

  _processTap() {
    if (!appProvider.showEye) {
      tokenLayoutNotifier.codeVisiable = true;
    }
    updateCode();
    if (HiveUtil.getBool(HiveUtil.clickToCopyKey)) {
      if (HiveUtil.getBool(HiveUtil.autoCopyNextCodeKey) &&
          currentProgress < autoCopyNextCodeProgressThrehold) {
        _processCopyNextCode();
      } else {
        _processCopyCode();
      }
      if (HiveUtil.getBool(HiveUtil.autoMinimizeAfterClickToCopyKey,
          defaultValue: false)) {
        if (ResponsiveUtil.isDesktop()) {
          windowManager.minimize();
        } else {
          MoveToBackground.moveTaskToBack();
        }
      }
    }
  }

  _buildSimpleLayout() {
    return ItemBuilder.buildClickItem(
      Material(
        color: widget.token.pinned
            ? Theme.of(context).primaryColor.withOpacity(0.15)
            : Theme.of(context).canvasColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: _processTap,
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ItemBuilder.buildTokenImage(widget.token, size: 32),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.token.issuer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.apply(fontWeightDelta: 2),
                          ),
                        ),
                        if (!isHOTP) _buildEyeButton(padding: 6),
                        if (isHOTP) _buildHOTPRefreshButton(padding: 6),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Container(
                      constraints:
                          const BoxConstraints(minHeight: 56, maxHeight: 56),
                      child: _buildCodeLayout(
                        letterSpacing: 10,
                        alignment: Alignment.center,
                        fontSize: 27,
                      ),
                    ),
                    const SizedBox(height: 5),
                  ],
                ),
              ),
              Selector<AppProvider, bool>(
                selector: (context, provider) => provider.hideProgressBar,
                builder: (context, hideProgressBar, child) =>
                    _buildLinearProgress(hideProgressBar),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _buildCompactLayout() {
    // TextTheme textTheme = Theme.of(context).textTheme;
    return ItemBuilder.buildClickItem(
      Material(
        color: widget.token.pinned
            ? Theme.of(context).primaryColor.withOpacity(0.15)
            : Theme.of(context).canvasColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: _processTap,
          customBorder:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.token.issuer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.apply(fontWeightDelta: 2),
                              ),
                              Text(
                                widget.token.account,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ItemBuilder.buildTokenImage(widget.token, size: 28),
                      ],
                    ),
                    Container(
                      constraints:
                          const BoxConstraints(minHeight: 56, maxHeight: 56),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _buildCodeLayout(letterSpacing: 8)),
                          if (isHOTP) _buildHOTPRefreshButton(padding: 4),
                          if (!isHOTP) _buildEyeButton(padding: 4),
                          ItemBuilder.buildIconButton(
                            context: context,
                            padding: const EdgeInsets.all(4),
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color:
                                  Theme.of(context).textTheme.labelSmall?.color,
                              size: 20,
                            ),
                            onTap: showContextMenu,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Selector<AppProvider, bool>(
                selector: (context, provider) => provider.hideProgressBar,
                builder: (context, hideProgressBar, child) =>
                    _buildLinearProgress(hideProgressBar),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _buildSpotlightLayout() {
    return ItemBuilder.buildClickItem(
      Material(
        color: widget.token.pinned
            ? Theme.of(context).primaryColor.withOpacity(0.15)
            : Theme.of(context).canvasColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: _processTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            padding:
                const EdgeInsets.only(left: 12, right: 12, top: 15, bottom: 8),
            child: Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 3),
                  child: ItemBuilder.buildTokenImage(widget.token, size: 36),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    constraints:
                        const BoxConstraints(maxHeight: 85, minHeight: 85),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.token.issuer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.apply(fontWeightDelta: 2),
                        ),
                        if (widget.token.account.isNotEmpty)
                          Text(
                            widget.token.account,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        Container(
                          constraints: const BoxConstraints(
                              maxHeight: 45, minHeight: 45),
                          child: _buildCodeLayout(
                              fontSize: 28,
                              forceNoType: false,
                              letterSpacing: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                if (!isHOTP) _buildEyeButton(),
                if (isHOTP) _buildHOTPRefreshButton(),
                if (!isHOTP)
                  _buildVisibleLayoutWithEye((codeVisible) =>
                      codeVisible ? _buildCircleProgress() : emptyWidget),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _buildListLayout() {
    return ItemBuilder.buildClickItem(
      Material(
        color: widget.token.pinned
            ? Theme.of(context).primaryColor.withOpacity(0.15)
            : Theme.of(context).canvasColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: _processTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                ItemBuilder.buildTokenImage(widget.token, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.token.issuer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.apply(fontWeightDelta: 2),
                  ),
                ),
                _buildCodeLayout(),
                const SizedBox(width: 4),
                if (!isHOTP)
                  _buildEyeButton(
                      padding: 6, color: Theme.of(context).primaryColor),
                if (!isHOTP)
                  _buildVisibleLayoutWithEye((codeVisible) =>
                      codeVisible ? _buildCircleProgress() : emptyWidget),
                if (isHOTP)
                  _buildHOTPRefreshButton(
                      padding: 6, color: Theme.of(context).primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
