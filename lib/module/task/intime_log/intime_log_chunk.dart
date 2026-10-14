/// `/api/crons/:id/log` 的分片响应。
///
/// 服务端（青龙 2.19+）这个接口支持 `offset` / `limit` / `tail`，并在响应里回
/// `nextOffset` / `total` / `truncated`：带上一次返回的 `nextOffset` 再请求，
/// 就只会拿到**新增**的那段日志。
///
/// 这正是把「实时日志」做成流式追加（而不是每 2 秒整段重取、整段重排、
/// 滚动位置跳来跳去）的关键 —— 原来客户端只用 `data` 字段，把这些能力浪费了。
class InTimeLogChunk {
  /// 本片日志文本（`data`）
  final String content;

  /// 本片在文件中的起始字节
  final int? offset;

  /// 本片结束位置＝下次增量读取的起点
  final int? nextOffset;

  /// 文件总字节数
  final int? total;

  /// 是否被截断（不是从文件头开始，或后面还有内容）
  final bool truncated;

  /// 服务端的日志状态：empty / ignored / running 等
  final String? status;

  final int code;
  final String? message;

  InTimeLogChunk({
    required this.content,
    required this.code,
    this.offset,
    this.nextOffset,
    this.total,
    this.truncated = false,
    this.status,
    this.message,
  });

  bool get success => code == 200;

  /// 服务端是否支持增量读取（老服务端不返回 nextOffset，此时退回整段刷新）
  bool get supportIncremental => nextOffset != null;

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// 由 `Http.getEnvelope` 拿到的整个响应信封构造
  factory InTimeLogChunk.fromEnvelope(Map<String, dynamic>? envelope) {
    if (envelope == null) {
      return InTimeLogChunk(
        content: "",
        code: 0,
        message: "日志读取失败，请检查网络",
      );
    }
    final dynamic data = envelope["data"];
    return InTimeLogChunk(
      content: data is String ? data : (data?.toString() ?? ""),
      code: _asInt(envelope["code"]) ?? 0,
      offset: _asInt(envelope["offset"]),
      nextOffset: _asInt(envelope["nextOffset"]),
      total: _asInt(envelope["total"]),
      truncated: envelope["truncated"] == true,
      status: envelope["logStatus"]?.toString(),
      message: envelope["message"]?.toString(),
    );
  }
}
