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

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../Models/github_response.dart';
import '../../Utils/responsive_util.dart';
import '../../Utils/uri_util.dart';
import '../../Utils/utils.dart';
import '../../Widgets/General/EasyRefresh/easy_refresh.dart';
import '../../Widgets/Item/item_builder.dart';
import '../../Widgets/Scaffold/my_scaffold.dart';
import '../../generated/l10n.dart';

class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key});

  static const String routeName = "/setting/changelog";

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen>
    with TickerProviderStateMixin {
  List<ReleaseItem> releaseItems = [];
  final EasyRefreshController _refreshController = EasyRefreshController();
  String currentVersion = "";
  String latestVersion = "";

  @override
  void initState() {
    super.initState();
    getAppInfo();
  }

  void getAppInfo() {
    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      setState(() {
        currentVersion = packageInfo.version;
      });
    });
  }

  Future<void> fetchReleases() async {
    await Utils.getReleases(
      context: context,
      showLoading: false,
      showUpdateDialog: false,
      showLatestToast: false,
      noUpdateToastText: S.current.failedToGetChangelog,
      onGetCurrentVersion: (currentVersion) {
        setState(() {
          this.currentVersion = currentVersion;
        });
      },
      onGetLatestRelease: (latestVersion, latestReleaseItem) {
        setState(() {
          this.latestVersion = latestVersion;
        });
      },
      onGetReleases: (releases) {
        setState(() {
          releaseItems = releases;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: MyScaffold(
        appBar: ResponsiveUtil.isLandscape()
            ? ItemBuilder.buildSimpleAppBar(
                title: S.current.changelog,
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
                  S.current.changelog,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.apply(fontWeightDelta: 2),
                ),
                actions: [
                  ItemBuilder.buildBlankIconButton(context),
                  const SizedBox(width: 5),
                ],
              ),
        body: EasyRefresh(
          controller: _refreshController,
          refreshOnStart: true,
          onRefresh: () async {
            // await fetchReleases();
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
            itemBuilder: (context, index) => _buildItem(releaseItems[index]),
            itemCount: releaseItems.length,
          ),
        ),
      ),
    );
  }

  _buildItem(ReleaseItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ItemBuilder.buildContainerItem(
        topRadius: true,
        bottomRadius: true,
        context: context,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 2),
                  Text(
                    item.tagName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.apply(fontSizeDelta: 1),
                  ),
                  const SizedBox(width: 6),
                  if (Utils.compareVersion(
                          item.tagName.replaceAll(RegExp(r'[a-zA-Z]'), ''),
                          currentVersion) ==
                      0)
                    ItemBuilder.buildRoundButton(
                      context,
                      text: S.current.currentVersion,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 2),
                      radius: 3,
                      color: Theme.of(context).primaryColor,
                    ),
                  const Spacer(),
                  ItemBuilder.buildIconButton(
                    context: context,
                    icon: Icon(
                      Icons.keyboard_arrow_right_rounded,
                      size: 20,
                      color: Theme.of(context).textTheme.labelMedium?.color,
                    ),
                    onTap: () {
                      UriUtil.launchUrlUri(context, item.htmlUrl);
                    },
                  ),
                ],
              ),
              ItemBuilder.buildDivider(context, horizontal: 0, vertical: 5),
              const SizedBox(height: 9),
              ItemBuilder.buildHtmlWidget(
                context,
                Utils.replaceLineBreak(item.body ?? ""),
                textStyle: Theme.of(context).textTheme.titleMedium?.apply(
                      fontSizeDelta: 1,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
              ),
              const SizedBox(height: 5),
            ],
          ),
        ),
      ),
    );
  }
}
