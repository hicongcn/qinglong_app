import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qinglong_app/base/commit_button.dart';
import 'package:path/path.dart' as p;
import 'package:qinglong_app/base/http/http.dart';
import 'package:qinglong_app/base/ql_app_bar.dart';
import 'package:qinglong_app/base/single_account_page.dart';
import 'package:qinglong_app/base/theme.dart';
import 'package:qinglong_app/base/ui/lazy_load_state.dart';
import 'package:qinglong_app/base/upload_script_widget.dart';
import 'package:qinglong_app/module/others/scripts/script_upload_page.dart';
import 'package:qinglong_app/module/subscribe/add_subscribe_page.dart';
import 'package:qinglong_app/module/task/task_bean.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/utils.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/config_detail_page.dart';

class AddTaskPage extends ConsumerStatefulWidget {
  final TaskBean? taskBean;
  final bool hideUploadFile;

  const AddTaskPage({
    Key? key,
    this.taskBean,
    required this.hideUploadFile,
  }) : super(key: key);

  @override
  ConsumerState<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends ConsumerState<AddTaskPage> with LazyLoadState<AddTaskPage> {
  late TaskBean taskBean;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _commandController = TextEditingController();
  final TextEditingController _cronController = TextEditingController();

  FocusNode focusNode = FocusNode();

  /// 是否允许同时运行多个实例（服务端默认 0 = 单实例）。
  /// 关闭时：任务到点触发而上一次还在跑 → 服务端会先终止旧实例再启动新的。
  bool allowMultipleInstances = false;

  /// 额外调度规则（服务端 `extra_schedules`）：一个任务除主规则外还能挂多条。
  /// 服务端的 cron 校验会把「3 个以上、等差、且一直排到边界」的逗号列表判为无效
  /// （cron-parser 缩写出的 `N/M` 写法 node-cron 不接受），这种情况拆成多条规则即可。
  final List<TextEditingController> _extraControllers = [];

  @override
  void initState() {
    super.initState();
    if (widget.taskBean != null) {
      taskBean = widget.taskBean!;
      _nameController.text = taskBean.name ?? "";
      _commandController.text = taskBean.command ?? "";
      _cronController.text = taskBean.schedule ?? "";
      allowMultipleInstances = taskBean.allowMultipleInstances == 1;
      for (final String rule in taskBean.extraSchedules ?? <String>[]) {
        _extraControllers.add(TextEditingController(text: rule));
      }
    } else {
      taskBean = TaskBean();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: QlAppBar(
        canBack: true,
        actions: [
          CommitButton(
            onTap: () {
              submit();
            },
          ),
        ],
        title: (taskBean.sId == null || taskBean.sId!.isEmpty) ? "新增任务" : "编辑任务",
      ),
      body: SingleChildScrollView(
        primary: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 15,
                  ),
                  const TitleWidget(
                    "名称",
                    required: true,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  TextField(
                    focusNode: focusNode,
                    controller: _nameController,
                    maxLines: 3,
                    minLines: 1,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: const InputDecoration(
                      hintText: "请输入名称",
                    ),
                    autofocus: false,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 15,
                  ),
                  const TitleWidget(
                    "命令",
                    required: true,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  TextField(
                    controller: _commandController,
                    maxLines: 4,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: "请输入命令",
                    ),
                    autofocus: false,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 15,
                  ),
                  const TitleWidget(
                    "定时规则",
                    required: true,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  TextField(
                    controller: _cronController,
                    minLines: 1,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: const InputDecoration(
                      hintText: "秒(可选) 分	时 天 月 周",
                    ),
                    autofocus: false,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  GestureDetector(
                    onTap: () async {
                      try {
                        var cron = _cronController.text.replaceAll(" ", "_");
                        await launchUrl(Uri.tryParse("https://crontab.guru/#$cron")!);
                      } catch (e) {}
                    },
                    child: Text(
                      "在线测试",
                      style: TextStyle(
                        fontSize: 12,
                        color: ref.watch(themeProvider).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "允许多个实例",
                              style: TextStyle(
                                fontSize: 15,
                                color: ref.watch(themeProvider).themeColor.titleColor(),
                              ),
                            ),
                            const SizedBox(
                              height: 5,
                            ),
                            Text(
                              "关闭时（服务端默认），若任务到点触发而上一次还在运行，服务端会先终止旧实例再启动新的——脚本耗时超过定时间隔时就会一直被打断。这种情况把它打开。",
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: ref.watch(themeProvider).themeColor.descColor(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      CupertinoSwitch(
                        value: allowMultipleInstances,
                        activeColor: ref.watch(themeProvider).primaryColor,
                        onChanged: (value) {
                          setState(() {
                            allowMultipleInstances = value;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Text(
                    "额外调度规则",
                    style: TextStyle(
                      fontSize: 15,
                      color: ref.watch(themeProvider).themeColor.titleColor(),
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    "同一个任务可以挂多条时间规则，主规则之外的时间点写在这里。"
                    "服务端的定时规则校验会把「3 个以上、等差且排到边界」的逗号列表误判为无效，"
                    "这种情况拆成多条规则就能绕过。",
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: ref.watch(themeProvider).themeColor.descColor(),
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  ..._extraControllers.asMap().entries.map((entry) {
                    final int index = entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: entry.value,
                              minLines: 1,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: const InputDecoration(
                                hintText: "秒(可选) 分\t时 天 月 周",
                                isDense: true,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            color: Colors.transparent,
                            onPressed: () {
                              setState(() {
                                _extraControllers.removeAt(index).dispose();
                              });
                            },
                            child: const Icon(
                              CupertinoIcons.minus_circle,
                              size: 20,
                              color: Color(0xffFB5858),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _extraControllers.add(TextEditingController());
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.add_circled,
                          size: 18,
                          color: ref.watch(themeProvider).primaryColor,
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        Text(
                          "添加一条规则",
                          style: TextStyle(
                            fontSize: 13,
                            color: ref.watch(themeProvider).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  Visibility(
                    visible: !widget.hideUploadFile,
                    child: UploadScriptWidget(
                      key: fileKey,
                      nameCallBack: (name) async {
                        _nameController.text = name ?? "";
                        if (name == null || name.isEmpty) {
                          _commandController.text = "";
                          _cronController.text = "";
                        } else {
                          String command =
                              "task ${fileKey.currentState?.scriptPath}${(fileKey.currentState != null && fileKey.currentState!.scriptPath.isNotEmpty) ? p.separator : ""}${fileKey.currentState?.getFileName()}";

                          _commandController.text = command;

                          String data = await fileKey.currentState?.file?.readAsString() ?? "";

                          _cronController.text = ScriptUploadPageState.getCronString(data, name) ?? "";
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  GlobalKey<UploadScriptWidgetState> fileKey = GlobalKey();

  void submit() async {
    if (_nameController.text.isEmpty) {
      "任务名称不能为空".toast();
      return;
    }
    if (_commandController.text.isEmpty) {
      "命令不能为空".toast();
      return;
    }
    if (_cronController.text.isEmpty) {
      "定时规则不能为空".toast();
      return;
    }

    commitReal();
  }

  void commitReal() async {
    try {
      hideKeyboardFocus();
      if (fileKey.currentState != null && fileKey.currentState!.file != null) {
        String content = await fileKey.currentState!.file!.readAsString();
        HttpResponse<NullResponse> responseS = await SingleAccountPageState.ofApi(context).addScript(
          fileKey.currentState?.getFileName() ?? _commandController.text.split(" ").last,
          fileKey.currentState?.scriptPath ?? "",
          content,
        );
        if (!responseS.success) {
          responseS.message.toast();
          return;
        }
      }

      taskBean.name = _nameController.text;
      taskBean.command = _commandController.text.trim();
      taskBean.schedule = _cronController.text.trim();

      // 只在「要开启」或「服务端本来就有这个字段」时才带上它，
      // 免得给不认识该字段的老服务端传未知参数。
      int? allowValue;
      if (allowMultipleInstances) {
        allowValue = 1;
      } else if (taskBean.allowMultipleInstances != null) {
        allowValue = 0;
      }
      taskBean.allowMultipleInstances = allowValue;

      // 额外调度规则：丢掉空行；编辑时总是提交（空数组 = 清空全部），
      // 新建时若一条都没填则不带该字段。
      final List<String> extraSchedules = _extraControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final bool isEditing = taskBean.id != null;
      taskBean.extraSchedules = extraSchedules;

      await EasyLoading.show(status: " 提交中");
      HttpResponse<NullResponse> response = await SingleAccountPageState.ofApi(context).addTask(
        _nameController.text,
        _commandController.text.trim(),
        _cronController.text.trim(),
        id: taskBean.id,
        allowMultipleInstances: allowValue,
        extraSchedules:
            (isEditing || extraSchedules.isNotEmpty) ? extraSchedules : null,
      );
      await EasyLoading.dismiss();
      if (response.success) {
        (widget.taskBean?.sId == null) ? "新增成功" : "修改成功".toast();
        ref.read(SingleAccountPageState.ofTaskProvider(context)(getProviderName(context))).updateBean(context, taskBean);
        Navigator.of(context).pop();
      } else {
        response.message.toast();
      }
    } catch (e) {
      e.toString().toast();
      EasyLoading.dismiss();
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in _extraControllers) {
      c.dispose();
    }
    _nameController.dispose();
    _commandController.dispose();
    _cronController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  void onLazyLoad() {
    if (widget.hideUploadFile) {
      focusNode.requestFocus();
    }
  }
}
