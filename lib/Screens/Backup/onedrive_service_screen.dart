import 'package:cloudotp/Models/cloud_service_config.dart';
import 'package:cloudotp/TokenUtils/Cloud/cloud_service.dart';
import 'package:cloudotp/Utils/itoast.dart';
import 'package:cloudotp/Utils/responsive_util.dart';
import 'package:cloudotp/Widgets/Item/item_builder.dart';
import 'package:flutter/material.dart';

import '../../Database/cloud_service_config_dao.dart';
import '../../TokenUtils/Cloud/onedrive_cloud_service.dart';
import '../../TokenUtils/export_token_util.dart';
import '../../Widgets/Dialog/custom_dialog.dart';
import '../../Widgets/Item/input_item.dart';
import '../../generated/l10n.dart';

class OneDriveServiceScreen extends StatefulWidget {
  const OneDriveServiceScreen({
    super.key,
  });

  static const String routeName = "/service/onedrive";

  @override
  State<OneDriveServiceScreen> createState() => _OneDriveServiceScreenState();
}

class _OneDriveServiceScreenState extends State<OneDriveServiceScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final TextEditingController _sizeController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  CloudServiceConfig? _oneDriveCloudServiceConfig;
  OneDriveCloudService? _oneDriveCloudService;
  bool inited = false;

  CloudServiceConfig get currentConfig => _oneDriveCloudServiceConfig!;

  CloudService get currentService => _oneDriveCloudService!;

  bool get _configInitialized {
    return _oneDriveCloudServiceConfig != null;
  }

  @override
  void initState() {
    super.initState();
    loadConfig();
  }

  loadConfig() async {
    _oneDriveCloudServiceConfig =
        await CloudServiceConfigDao.getOneDriveConfig();
    if (_oneDriveCloudServiceConfig != null) {
      _sizeController.text = _oneDriveCloudServiceConfig!.size;
      _accountController.text = _oneDriveCloudServiceConfig!.account ?? "";
      if (_oneDriveCloudServiceConfig!.isValid) {
        _oneDriveCloudService = OneDriveCloudService(
          context,
          _oneDriveCloudServiceConfig!,
          onConfigChanged: updateConfig,
        );
      }
    } else {
      _oneDriveCloudServiceConfig =
          CloudServiceConfig.init(type: CloudServiceType.OneDrive);
      await CloudServiceConfigDao.insertConfig(_oneDriveCloudServiceConfig!);
      _oneDriveCloudService = OneDriveCloudService(
        context,
        _oneDriveCloudServiceConfig!,
        onConfigChanged: updateConfig,
      );
    }
    if (_oneDriveCloudService != null) {
      _oneDriveCloudServiceConfig!.connected =
          await _oneDriveCloudService!.isConnected();
    }
    inited = true;
    setState(() {});
  }

  updateConfig(CloudServiceConfig config) {
    setState(() {
      _oneDriveCloudServiceConfig = config;
    });
    _sizeController.text = _oneDriveCloudServiceConfig!.size;
    _accountController.text = _oneDriveCloudServiceConfig!.account ?? "";
    CloudServiceConfigDao.updateConfig(_oneDriveCloudServiceConfig!);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ResponsiveUtil.isDesktop()
        ? _buildUnsupportBody()
        : inited
            ? _buildBody()
            : ItemBuilder.buildLoadingDialog(
                context,
                background: Colors.transparent,
                text: S.current.cloudConnecting,
              );
  }

  _buildUnsupportBody() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(S.current.cloudTypeNotSupport(S.current.cloudTypeOneDrive)),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  ping({
    bool showLoading = true,
    bool showSuccessToast = true,
  }) async {
    if (showLoading) {
      CustomLoadingDialog.showLoading(title: S.current.cloudConnecting);
    }
    await currentService.authenticate().then((value) {
      setState(() {
        currentConfig.connected = value == CloudServiceStatus.success;
      });
      if (!currentConfig.connected) {
        switch (value) {
          case CloudServiceStatus.connectionError:
            IToast.show(S.current.cloudConnectionError);
            break;
          case CloudServiceStatus.unauthorized:
            IToast.show(S.current.cloudOauthFailed);
            break;
          default:
            IToast.show(S.current.cloudUnknownError);
            break;
        }
      } else {
        if (showSuccessToast) IToast.show(S.current.cloudAuthSuccess);
      }
    });
    if (showLoading) CustomLoadingDialog.dismissLoading();
  }

  _buildBody() {
    return Column(
      children: [
        if (_configInitialized) _enableInfo(),
        const SizedBox(height: 10),
        if (_configInitialized) _accountInfo(),
        const SizedBox(height: 30),
        if (_configInitialized && !currentConfig.connected) _loginButton(),
        if (_configInitialized && currentConfig.connected) _operationButtons(),
      ],
    );
  }

  _enableInfo() {
    return ItemBuilder.buildRadioItem(
      context: context,
      title: S.current.enable + S.current.cloudTypeOneDrive,
      topRadius: true,
      bottomRadius: true,
      value: _oneDriveCloudServiceConfig?.enabled ?? false,
      onTap: () {
        setState(() {
          _oneDriveCloudServiceConfig!.enabled =
              !_oneDriveCloudServiceConfig!.enabled;
        });
      },
    );
  }

  _accountInfo() {
    return ItemBuilder.buildContainerItem(
      context: context,
      topRadius: true,
      bottomRadius: true,
      padding: const EdgeInsets.only(top: 15, bottom: 5, right: 10),
      child: Column(
        children: [
          InputItem(
            controller: _accountController,
            textInputAction: TextInputAction.next,
            leadingType: InputItemLeadingType.text,
            disabled: true,
            leadingText: S.current.webDavUsername,
          ),
          InputItem(
            controller: _sizeController,
            textInputAction: TextInputAction.next,
            leadingType: InputItemLeadingType.text,
            disabled: true,
            leadingText: S.current.cloudSize,
          ),
        ],
      ),
    );
  }

  _loginButton() {
    return Row(
      children: [
        const SizedBox(width: 10),
        Expanded(
          child: ItemBuilder.buildRoundButton(
            context,
            text: S.current.webDavSignin,
            background: Theme.of(context).primaryColor,
            fontSizeDelta: 2,
            onTap: () async {
              ping();
            },
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  _operationButtons() {
    return Row(
      children: [
        const SizedBox(width: 10),
        Expanded(
          child: ItemBuilder.buildFramedButton(
            context,
            text: S.current.webDavPullBackup,
            padding: const EdgeInsets.symmetric(vertical: 12),
            outline: Theme.of(context).primaryColor,
            color: Theme.of(context).primaryColor,
            fontSizeDelta: 2,
            onTap: () async {
              CustomLoadingDialog.showLoading(
                title: S.current.webDavPulling,
                dismissible: true,
              );
              try {
                List<dynamic> files = await _oneDriveCloudService!.listFiles();
                CustomLoadingDialog.dismissLoading();
                CloudServiceConfigDao.updateLastPullTime(
                    _oneDriveCloudServiceConfig!);
              } catch (e) {
                print(e);
              } finally {
                CustomLoadingDialog.dismissLoading();
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ItemBuilder.buildRoundButton(
            context,
            padding: const EdgeInsets.symmetric(vertical: 12),
            background: Theme.of(context).primaryColor,
            text: S.current.webDavPushBackup,
            fontSizeDelta: 2,
            onTap: () async {
              ExportTokenUtil.backupEncryptToCloud(
                config: _oneDriveCloudServiceConfig!,
                cloudService: _oneDriveCloudService!,
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ItemBuilder.buildRoundButton(
            context,
            padding: const EdgeInsets.symmetric(vertical: 12),
            background: Colors.red,
            text: S.current.webDavLogout,
            fontSizeDelta: 2,
            onTap: () async {
              await _oneDriveCloudService!.signOut();
              setState(() {
                _oneDriveCloudServiceConfig!.connected = false;
                _oneDriveCloudServiceConfig!.account = "";
                _oneDriveCloudServiceConfig!.totalSize =
                    _oneDriveCloudServiceConfig!.remainingSize =
                        _oneDriveCloudServiceConfig!.usedSize = -1;
                updateConfig(_oneDriveCloudServiceConfig!);
              });
            },
          ),
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}
