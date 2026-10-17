import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qinglong_app/base/http/api.dart';
import 'package:qinglong_app/base/sp_const.dart';
import 'package:qinglong_app/base/userinfo_viewmodel.dart';
import 'package:qinglong_app/main.dart';
import 'package:qinglong_app/module/env/env_bean.dart';
import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/icloud_channel.dart';
import 'package:qinglong_app/utils/sp_utils.dart';
import 'package:qinglong_app/utils/utils.dart';
import 'package:path/path.dart' as path;



class ICloudUtils {
  static bool remindError = false;

  static String now() {
    return Utils.formatMessageTime(DateTime.now().millisecondsSinceEpoch);
  }

  static const containerID = "iCloud.work.newtab.ql";
  int index;

  ICloudUtils(this.index);

  Future<void> asyncSubscribe(String list, {bool focusUpdate = false}) async {
    try {
      if (list.isEmpty) return;
      if (SpUtil.getBool(spICloud, defValue: true) == false &&
          focusUpdate == false) return;

      bool exist = await existContent(
          await FileUtil(index).getSubscribeDirectory(), list);

      if (!exist) {
        await FileUtil(index).writeSubscribe(list);
      }
    } catch (e) {
      logger.e(e);
    }
  }

  Future<bool> existContent(Directory d, String content) async {
    try {
      await for (FileSystemEntity fileSystemEntity in d.list()) {
        if ((await File(fileSystemEntity.path).readAsString()) == content) {
          return true;
        }
      }
      return false;
    } catch (e) {}
    return false;
  }

  Future<void> asyncEnv(List<EnvBean> list, {bool focusUpdate = false}) async {
    try {
      if (list.isEmpty) return;
      if (SpUtil.getBool(spICloud, defValue: true) == false &&
          focusUpdate == false) return;
      bool exist = await existContent(
          await FileUtil(index).getEnvDirectory(), jsonEncode(list));

      if (!exist) {
        await FileUtil(index).writeEnv(jsonEncode(list));
      }
    } catch (e) {
      logger.e(e);
    }
  }

  Future<void> asyncConfig(String? title, String? content,
      {bool focusUpdate = false}) async {
    try {

      if (content == null || content.isEmpty) return;
      if (SpUtil.getBool(spICloud, defValue: true) == false &&
          focusUpdate == false) return;

      bool exist = await existContent(
          await FileUtil(index)
              .getConfigHolDirectory(title ?? "nameNotFound.sh"),
          content);

      if (!exist) {
        await FileUtil(index).writeConfig(title ?? "nameNotFound.sh", content);
      }
    } catch (e) {}
  }

  void restoreEnv(String? path) async {

    if (path == null) {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null &&
          result.files.isNotEmpty &&
          result.files.single.path != null) {
        if (!result.files.single.path!.endsWith(FileUtil.env)) {
          "只支持 .${FileUtil.env} 结尾的文件".toast();
        } else {
          _handleRestoreEnv(result.files.single.path!);
        }
      }
    } else {
      _handleRestoreEnv(path);
    }
  }

  void restoreSubscribe(String? path) async {
    if (path == null) {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null &&
          result.files.isNotEmpty &&
          result.files.single.path != null) {
        if (!result.files.single.path!.endsWith(FileUtil.subscribe)) {
          "只支持 .${FileUtil.subscribe} 结尾的文件".toast();
        } else {
          _handleRestoreSubscribe(result.files.single.path!);
        }
      }
    } else {
      _handleRestoreSubscribe(path);
    }
  }

  void restoreConfig(String? path) async {
    if (path == null) {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null &&
          result.files.isNotEmpty &&
          result.files.single.path != null) {
        if (!result.files.single.path!.endsWith(FileUtil.config)) {
          "只支持 .${FileUtil.config} 结尾的文件".toast();
        } else {
          String p = result.files.single.path!;
          String title = "nameNotFound.sh";

          try {
            //获取倒数第二个/的内容
            List<String> temp = p.split("/");
            if (temp.length > 1) {
              title = temp[temp.length - 2];
            }
            _handleRestoreConfig(title, p);
          } catch (e) {}
        }
      }
    } else {
      String title = "nameNotFound.sh";
      try {
        //获取倒数第二个/的内容
        List<String> temp = path.split("/");
        if (temp.length > 1) {
          title = temp[temp.length - 2];
        }
        _handleRestoreConfig(title, path);
      } catch (e) {}
    }
  }

  void _handleRestoreSubscribe(String localSubscribePath) async {
    try {
      final file = File(localSubscribePath);
      final contents = await file.readAsString();

      List<Map<String, dynamic>> list = [];

      List<dynamic> data = jsonDecode(contents);

      list.addAll(data.map((e) {
        return e as Map<String, dynamic>;
      }).toList());

      for (var value in list) {
        value.remove("id");
        value.remove("status");
        value.remove("pid");
        value.remove("is_disabled");
        value.remove("log_path");
        value.remove("createdAt");
        value.remove("updatedAt");

        await Api(index).addSubscribes(value);
      }
      "已还原，请刷新订阅管理列表查看".toast();
    } catch (e) {
      e.toString().toast();
    }
  }

  void _handleRestoreEnv(String localEnvPath) async {
    try {
      final file = File(localEnvPath);
      final contents = await file.readAsString();

      List<EnvBean> list = [];

      List<dynamic> data = jsonDecode(contents);

      list.addAll(data.map((e) => EnvBean.fromJson(e)).toList());

      var result = await Api(index).envs("");

      if (result.success) {
        if (result.bean != null && result.bean!.isNotEmpty) {
          List<String> temp = result.bean!.map((e) => e.sId!).toList();
          await Api(index).delEnvs(temp);
        }
      }

      for (var value in list) {
        if (value.name == null || value.value == null) continue;

        await Api(index).addEnv(
          value.name!,
          value.value!,
          value.remarks ?? "",
        );
      }
      "已还原，请刷新环境变量列表查看".toast();
    } catch (e) {
      e.toString().toast();
    }
  }

  void _handleRestoreConfig(String title, String localConfigPath) async {
    try {
      final file = File(localConfigPath);
      final contents = await file.readAsString();

      Api(index).saveFile(title, contents);
      "已还原$title文件".toast();
    } catch (e) {
      e.toString().toast();
    }
  }
}

class FileUtil {
  int index;

  FileUtil(this.index);

  static const String config = "config";
  static const String env = "env";
  static const String subscribe = "subscribe";
  static const String downloadFiles = "download_files";

  String today() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  String time() {
    return DateFormat('HH-mm-ss').format(DateTime.now());
  }

  /// 给下载文件名加时间戳，插在**扩展名之前**。
  ///
  /// `writeDownloadFile` 对同名文件是「先删后写」，所以直接用原名会让第二次下载
  /// 覆盖上一次的文件。加时间戳既能保持"看得出是哪个脚本"，又不会互相覆盖。
  ///
  /// `demo.js` → `demo_20261017_093000.js`；`demo` → `demo_20261017_093000`
  /// 保证文件名带扩展名。
  ///
  /// 运行日志页的 `title` 是**任务名**（如「天天夺宝」），本身没有后缀，
  /// 直接拿去保存会得到一个无后缀文件，系统不知道该用什么打开。
  /// 已经有扩展名的（`xxx.log`）原样返回。
  static String withLogExtension(String fileName, {String ext = ".log"}) {
    String name = fileName.trim();
    if (name.isEmpty) return "log$ext";
    // 历史日志那边传进来的是**目录名**（如 `elm/天天夺宝`），
    // 直接当文件名会拼出子目录，这里把路径分隔符等非法字符换成下划线。
    name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (path.extension(name).isNotEmpty) return name;
    return "$name$ext";
  }

  static String timestampedName(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    // dot > 0：跳过 `dot == 0`（形如 ".gitignore" 的隐藏文件）和没有点的情况
    final String stem = dot > 0 ? fileName.substring(0, dot) : fileName;
    final String ext = dot > 0 ? fileName.substring(dot) : '';
    // 用**可读时间**而不是 `20261017_134500` 这种紧凑时间戳
    final String stamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    return "${stem}_$stamp$ext";
  }

  String getHost() {
    String? temp =
        getIt<UserInfoViewModel>(instanceName: index.toString()).host;

    if (temp == null) return "";

    return temp
        .trim()
        .replaceAll("http://", "")
        .replaceAll("https://", "")
        .replaceAll("/", "-")
        .replaceAll("\\", "-")
        .replaceAll(":", "-")
        .replaceAll("*", "_")
        .replaceAll("?", "_")
        .replaceAll("<", "_")
        .replaceAll(">", "_")
        .replaceAll("|", "_");
  }

  Future<String> get downloadFilePath async {
    Directory directory;
    if (Platform.isAndroid) {
      var temp = await getExternalStorageDirectory();

      if (temp != null) {
        directory = temp;
      } else {
        directory = Directory("storage/emulated/0");
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    return directory.path;
  }

  Future<String> get sourcePath async {
    Directory directory;
    if (Platform.isAndroid) {
      directory = await getApplicationSupportDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    return directory.path;
  }

  /// 备份根目录：**优先 iCloud 容器**，拿不到再退回本机沙盒。
  ///
  /// 这是「备份」和「本地快照」的唯一区别 —— 只有落在 iCloud 容器的 Documents 里，
  /// 卸载重装、换机才找得回来（iOS 上该目录会出现在「文件 → iCloud Drive → 青龙客户端」）。
  /// Android 没有 iCloud，`ICloudChannel` 直接返回 null，行为与以前一致。
  Future<String> get localPath async {
    final String base = await backupRoot;
    return base + path.separator + getHost();
  }

  /// 备份根目录（不含 host 子目录）
  Future<String> get backupRoot async {
    if (SpUtil.getBool(spICloud, defValue: true)) {
      final String? cloud = await ICloudChannel.containerPath();
      if (cloud != null && cloud.isNotEmpty) return cloud;
    }
    return await sourcePath;
  }

  Future<Directory> getSubscribeDirectory() async {
    final path = await localPath;
    Directory f = Directory('$path/${today()}/$subscribe/');
    if (!(await f.exists())) {
      await f.create(recursive: true);
    }
    return f;
  }

  Future<File> get _localSubscribeFile async {
    final path = await localPath;
    File f = File('$path/${today()}/$subscribe/${time()}.$subscribe');
    if (f.existsSync()) {
      f.deleteSync();
    }
    return f;
  }

  Future<Directory> getEnvDirectory() async {
    final path = await localPath;
    Directory f = Directory('$path/${today()}/$env/');
    if (!(await f.exists())) {
      await f.create(recursive: true);
    }
    return f;
  }

  Future<File> get _localEnvFile async {
    final path = await localPath;
    File f = File('$path/${today()}/$env/${time()}.$env');
    if (f.existsSync()) {
      f.deleteSync();
    }
    return f;
  }

  Future<File> writeDownloadFile(String suffix, String content) async {
    final path = await downloadFilePath;
    File f;
    if (Platform.isAndroid) {
      f = File('$path/qinglong_app/$downloadFiles/$suffix');
    } else {
      f = File('$path/$downloadFiles/$suffix');
    }
    if (f.existsSync()) {
      f.deleteSync();
    }
    await f.create(recursive: true);
    return f.writeAsString(content);
  }

  Future<File> writeSubscribe(String content) async {
    final file = await _localSubscribeFile;
    await file.create(recursive: true);
    return file.writeAsString(content);
  }

  Future<File> writeEnv(String content) async {
    final file = await _localEnvFile;
    await file.create(recursive: true);
    return file.writeAsString(content);
  }

  Future<Directory> getConfigHolDirectory(String name) async {
    final path = await localPath;
    Directory f = Directory('$path/${today()}/$config/$name/');
    if (!(await f.exists())) {
      await f.create(recursive: true);
    }
    return f;
  }

  Future<File> locaConfigHolFile(String title) async {
    final path = await localPath;
    File f = File('$path/${today()}/$config/$title/${time()}.$config');
    if (f.existsSync()) {
      f.deleteSync();
    }
    return f;
  }

  Future<File> writeConfig(String title, String content) async {
    final file = await locaConfigHolFile(title);
    await file.create(recursive: true);
    return file.writeAsString(content);
  }
}
