import 'package:json_conversion_annotation/json_conversion_annotation.dart';

/// 脚本编辑历史（青龙 2.23+，需要 `scripts` 权限）。
///
/// 服务端实现在 `back/shared/scriptHistory.ts`，接口是：
/// - `GET  /api/scripts/history`         → `{versions, currentHash, limit}`
/// - `GET  /api/scripts/history/detail`  → `{version, current, currentHash}`
/// - `PUT  /api/scripts/history/restore`  body `{filename, path, id, expectedHash}`
///
/// ⚠️ 两个容易踩的点：
/// 1. history 系列用的参数名是 **`filename`**，而读文件内容的 `/scripts/detail`
///    用的是 **`file`** —— 服务端自己就不一致。
/// 2. 这三个接口失败时返回的是**真实 HTTP 状态码**（404 版本不存在 / 409 文件已变化 /
///    413 超过 1 MiB 或非 UTF-8），与青龙其他接口「HTTP 200 + body code」不同。
///    `Http.exceptionHandler` 已经会从错误响应体里取 `code` / `message`，所以直接透传。
///
/// 历史保留上限由服务端决定（`SCRIPT_HISTORY_LIMITS.versions = 20`）。

/// 一个历史版本。
class ScriptHistoryVersion {
  String? id;

  /// ISO 时间字符串
  String? createdAt;

  /// baseline（初始）| save（保存）| restore（回滚）| external（外部修改）
  String? source;

  /// sha256 十六进制（64 位）
  String? hash;

  /// 内容字节数
  int? size;

  /// 内容是否与当前文件一致（只有列表接口返回）
  bool? identical;

  /// 完整内容（只有 detail 接口返回）
  String? content;

  ScriptHistoryVersion({
    this.id,
    this.createdAt,
    this.source,
    this.hash,
    this.size,
    this.identical,
    this.content,
  });

  ScriptHistoryVersion.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    createdAt = json['createdAt'];
    source = json['source'];
    hash = json['hash'];
    size = json['size'];
    identical = json['identical'];
    content = json['content'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['createdAt'] = createdAt;
    data['source'] = source;
    data['hash'] = hash;
    data['size'] = size;
    data['identical'] = identical;
    data['content'] = content;
    return data;
  }

  /// 来源的中文标签
  String get sourceLabel {
    switch (source) {
      case 'baseline':
        return '初始版本';
      case 'save':
        return '保存';
      case 'restore':
        return '回滚';
      case 'external':
        return '外部修改';
      default:
        return source ?? '';
    }
  }

  /// 本地时间字符串，形如 `2026-10-14 15:30:00`
  String get timeLabel {
    final String? raw = createdAt;
    if (raw == null || raw.isEmpty) return '';
    final DateTime? d = DateTime.tryParse(raw)?.toLocal();
    if (d == null) return raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  /// 人类可读的体积
  String get sizeLabel {
    final int? n = size;
    if (n == null) return '';
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    return '${(n / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}

/// `GET /api/scripts/history` 的响应体（`data`）。
@JsonConversion()
class ScriptHistoryListBean {
  /// 按时间**倒序**（最新的在前）
  List<ScriptHistoryVersion>? versions;

  /// 服务端当前文件的 sha256
  String? currentHash;

  /// 服务端保留的历史条数上限
  int? limit;

  ScriptHistoryListBean({this.versions, this.currentHash, this.limit});

  ScriptHistoryListBean.fromJson(Map<String, dynamic> json) {
    if (json['versions'] != null) {
      versions = <ScriptHistoryVersion>[];
      json['versions'].forEach((v) {
        versions!.add(ScriptHistoryVersion.fromJson(v));
      });
    }
    currentHash = json['currentHash'];
    limit = json['limit'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (versions != null) {
      data['versions'] = versions!.map((v) => v.toJson()).toList();
    }
    data['currentHash'] = currentHash;
    data['limit'] = limit;
    return data;
  }

  static ScriptHistoryListBean jsonConversion(Map<String, dynamic> json) {
    return ScriptHistoryListBean.fromJson(json);
  }
}

/// `GET /api/scripts/history/detail` 的响应体（`data`）。
@JsonConversion()
class ScriptHistoryDetailBean {
  /// 选中的历史版本（含完整 `content`）
  ScriptHistoryVersion? version;

  /// 服务端当前的内容
  String? current;

  /// 服务端当前内容的 sha256，回滚时必须原样回传
  String? currentHash;

  ScriptHistoryDetailBean({this.version, this.current, this.currentHash});

  ScriptHistoryDetailBean.fromJson(Map<String, dynamic> json) {
    version = json['version'] != null
        ? ScriptHistoryVersion.fromJson(json['version'])
        : null;
    current = json['current'];
    currentHash = json['currentHash'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (version != null) {
      data['version'] = version!.toJson();
    }
    data['current'] = current;
    data['currentHash'] = currentHash;
    return data;
  }

  static ScriptHistoryDetailBean jsonConversion(Map<String, dynamic> json) {
    return ScriptHistoryDetailBean.fromJson(json);
  }
}
