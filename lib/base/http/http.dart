import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:dio_log/dio_log.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:qinglong_app/base/http/token_interceptor.dart';
import 'package:qinglong_app/base/http/url.dart';
import 'package:qinglong_app/base/userinfo_viewmodel.dart';
import 'package:qinglong_app/utils/extension.dart';

import '../../json.jc.dart';
import '../../main.dart';
import '../routes.dart';

class Http {
  Dio? _dio;
  bool pushedLoginPage = false;

  String host;
  int index;

  Http(
    this.host,
    this.index,
  ) {
    _init();
  }

  void initDioConfig(
    String host,
  ) {
    _dio = Dio(
      BaseOptions(
        baseUrl: host,
        // 连接/发送 15~20s、接收 30s：既能在网络不通时快速反馈，
        // 又不至于把慢速但仍在传输的请求（如日志分片）误判为超时
        // （receiveTimeout 是"两个数据包之间"的间隔，不是整包时长）。
        connectTimeout: 15000,
        receiveTimeout: 30000,
        sendTimeout: 20000,
        contentType: "application/json",
      ),
    );
    if (kDebugMode) {
      // 日志拦截器只在调试期挂载：release 下它们会逐条格式化并缓存
      // 请求/响应正文，纯粹是 CPU 与内存浪费。
      _dio?.interceptors.add(DioLogInterceptor());
      _dio?.interceptors.add(PrettyDioLogger());
    }

    _dio?.interceptors.add(TokenInterceptor(
      host,
      index,
    ));
    (_dio?.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (HttpClient client) {
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return client;
    };
  }

  void _init() {
    if (_dio == null) {
      initDioConfig(host);
    }
  }

  void clear() {
    _dio = null;
  }

  Future<HttpResponse<T>> get<T>(
    String uri,
    Map<String, String?>? json, {
    bool compute = true,
    String serializationName = "data",
  }) async {
    try {
      _init();
      var response = await _dio!.get(uri, queryParameters: json);
      return decodeResponse<T>(response, serializationName, compute);
    } on DioError catch (e) {
      return exceptionHandler<T>(e, uri);
    }
  }

  /// 取**纯文本**响应（不套 `{code,data}` 信封）。
  ///
  /// 服务端 `GET /api/system/log` 返回的就是一段文本，走 [get] 会因为
  /// `response.data["code"]` 不是 Map 而失败，故单开一个口子。
  Future<HttpResponse<String>> getText(
    String uri,
    Map<String, String?>? json,
  ) async {
    try {
      _init();
      final response = await _dio!.get(
        uri,
        queryParameters: json,
        // 必须显式声明 plain：默认 responseType=json 会让 dio 去解析这段文本，
        // 直接抛 FormatException（首字符就不是 JSON）。
        options: Options(responseType: ResponseType.plain),
      );
      final int status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return HttpResponse<String>(
          success: true,
          code: status,
          bean: response.data?.toString() ?? "",
        );
      }
      return HttpResponse<String>(
        success: false,
        code: status,
        message: "读取失败（HTTP $status）",
      );
    } on DioError catch (e) {
      return exceptionHandler<String>(e, uri);
    }
  }

  /// 取「整个响应信封」。
  ///
  /// 现有 [get] 只能拿到 `serializationName` 指向的那一个字段，而日志分片接口
  /// （`/api/crons/:id/log`）除了 `data` 还要用 `nextOffset` / `total` /
  /// `truncated` 来做增量读取，故单独开一个口子。失败返回 null
  /// （错误按既有逻辑处理，例如 401 会触发退出登录）。
  Future<Map<String, dynamic>?> getEnvelope(
    String uri,
    Map<String, String?>? json,
  ) async {
    try {
      _init();
      final response = await _dio!.get(uri, queryParameters: json);
      final data = response.data;
      if (data is Map) return data.cast<String, dynamic>();
      return null;
    } on DioError catch (e) {
      exceptionHandler<NullResponse>(e, uri);
      return null;
    }
  }

  Future<HttpResponse<T>> post<T>(
    String uri,
    dynamic json, {
    bool compute = true,
    String serializationName = "data",
  }) async {
    try {
      _init();
      var response = await _dio!.post(uri, data: json);

      return decodeResponse<T>(
        response,
        serializationName,
        compute,
      );
    } on DioError catch (e) {
      return exceptionHandler<T>(e, uri);
    }
  }

  Future<HttpResponse<T>> delete<T>(
    String uri,
    dynamic json, {
    bool compute = true,
    String serializationName = "data",
  }) async {
    try {
      _init();
      var response = await _dio!.delete(uri, data: json);

      return decodeResponse<T>(
        response,
        serializationName,
        compute,
      );
    } on DioError catch (e) {
      return exceptionHandler<T>(e, uri);
    }
  }

  Future<HttpResponse<T>> put<T>(
    String uri,
    dynamic json, {
    bool compute = true,
    String serializationName = "data",
  }) async {
    try {
      _init();
      var response = await _dio!.put(uri, data: json);
      return decodeResponse<T>(
        response,
        serializationName,
        compute,
      );
    } on DioError catch (e) {
      return exceptionHandler<T>(e, uri);
    }
  }

  void exitLogin() {
    if (!pushedLoginPage) {
      "身份已过期,请重新登录".toast();
      pushedLoginPage = true;

      getIt<UserInfoViewModel>(instanceName: index.toString()).exitLoginFocus(index);

      getIt<GlobalKey<NavigatorState>>(instanceName: index.toString()).currentState?.pushNamedAndRemoveUntil(Routes.routeLogin, (route) => false);
    }
  }

  HttpResponse<T> exceptionHandler<T>(DioError e, String path) {
    try {
      logger.e(e);
      if (e.response?.statusCode == 401 && !Url.inWhiteList(path)) {
        if (!getIt<UserInfoViewModel>(instanceName: index.toString()).useSecretLogined) {
          exitLogin();
        }
        return HttpResponse(success: false, message: "没有该模块的访问权限", code: 401);
      }

      if (e.response != null && e.response!.data != null) {
        final dynamic body = e.response!.data;
        // 服务端的参数校验（celebrate）走的是 HTTP 4xx + 固定格式：
        //   { status: 400, message: "Validation failed",
        //     validation: { body: { keys: ["schedule"], message: '"schedule" failed ... 无效的定时规则' } } }
        // 顶层 message 只是英文的 "Validation failed"，真正能看懂的原因在 validation 里。
        // 这里优先取具体校验信息，取不到再退回顶层 message。
        final String? detail = _celebrateDetail(body is Map ? body["validation"] : null);
        return HttpResponse(
          success: false,
          message: detail ?? body["message"] ?? e.message,
          code: body["code"] ?? 0,
        );
      } else {
        return HttpResponse(success: false, message: e.message, code: e.response?.statusCode ?? 0);
      }
    } catch (e) {
      return HttpResponse(success: false, message: e.toString(), code: 400);
    }
  }

  /// 从 celebrate 的 validation 结构里取出具体校验信息。
  ///
  /// 形如 `{ body: { message: '...' } }`、`{ query: {...} }` 等；取不到返回 null。
  static String? _celebrateDetail(dynamic validation) {
    if (validation is! Map) return null;
    for (final String section in <String>["body", "query", "params", "headers"]) {
      final dynamic item = validation[section];
      if (item is Map) {
        final dynamic msg = item["message"];
        if (msg is String && msg.trim().isNotEmpty) return msg;
      }
    }
    return null;
  }

  static HttpResponse<T> decodeResponse<T>(
    Response<dynamic> response,
    String serializationName,
    bool compute,
  ) {
    int code = 0;
    if (response.statusCode == 200) {
      try {
        if (response.data["code"] == 200) {
          if (response.data[serializationName] != null) {
            if (T == NullResponse) {
              return HttpResponse<T>(
                success: true,
                code: 200,
              );
            }

            dynamic data = response.data[serializationName];
            T t;
            if (T == String) {
              if (data is String) {
                t = data as T;
              } else {
                t = jsonEncode(data) as T;
              }
              return HttpResponse<T>(
                success: true,
                code: 200,
                bean: t,
              );
            } else {
              T bean;
              if (compute) {
                bean = DeserializeAction.invokeJson(DeserializeAction<T>(data));
              } else {
                bean = JsonConversion$Json.fromJson<T>(data);
              }
              return HttpResponse<T>(
                success: true,
                code: 200,
                bean: bean,
              );
            }
          } else {
            return HttpResponse<T>(
              success: true,
              code: 200,
            );
          }
        } else {
          return HttpResponse<T>(
            success: false,
            code: response.data["code"],
            message: response.data["message"],
          );
        }
      } catch (e) {
        logger.e(e);
        return HttpResponse<T>(
          success: false,
          code: -1000,
          message: "json解析失败",
        );
      }
    } else {
      code = response.statusCode ?? 0;
      return HttpResponse(
        success: false,
        code: code,
        message: response.statusMessage,
      );
    }
  }
}

class HttpResponse<T> {
  late bool success;
  String? message;
  late int code;
  T? bean;

  HttpResponse({required this.success, this.message, required this.code, this.bean});
}

class DeserializeAction<T> {
  final dynamic json;

  DeserializeAction(this.json);

  T invoke() {
    return JsonConversion$Json.fromJson<T>(json);
  }

  static dynamic invokeJson(DeserializeAction a) => a.invoke();
}

mixin BaseBean<T> {
  T fromJson(Map<String, dynamic> json);
}

class CronBean with BaseBean<CronBean> {
  @override
  CronBean fromJson(Map<String, dynamic> json) {
    return CronBean();
  }
}

void decode<T>() async {
  compute(DeserializeAction.invokeJson, DeserializeAction<T>({}));
}

class NullResponse {}

class NotLoginException implements Exception {}
