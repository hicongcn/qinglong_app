// 下载文件名的行为测试。
//
// 背景：`writeDownloadFile` 对同名文件是「先删后写」，所以文件名必须带时间戳，
// 否则第二次下载会覆盖上一次。时间戳要插在**扩展名之前**，扩展名不能被吃掉。
import 'package:flutter_test/flutter_test.dart';
import 'package:qinglong_app/utils/icloud_utils.dart';

void main() {
  group('下载文件名加时间戳', () {
    test('保留扩展名，时间戳插在扩展名前', () {
      final String n = FileUtil.timestampedName('demo.js');
      expect(RegExp(r'^demo_\d{8}_\d{6}\.js$').hasMatch(n), isTrue, reason: n);
    });

    test('没有扩展名时直接追加时间戳', () {
      final String n = FileUtil.timestampedName('demo');
      expect(RegExp(r'^demo_\d{8}_\d{6}$').hasMatch(n), isTrue, reason: n);
    });

    test('多个点只按最后一个点切分', () {
      final String n = FileUtil.timestampedName('my.task.sh');
      expect(RegExp(r'^my\.task_\d{8}_\d{6}\.sh$').hasMatch(n), isTrue, reason: n);
    });

    test('以点开头的隐藏文件不被当成扩展名', () {
      final String n = FileUtil.timestampedName('.gitignore');
      expect(RegExp(r'^\.gitignore_\d{8}_\d{6}$').hasMatch(n), isTrue, reason: n);
    });

    test('时间戳解析回来接近当前时间', () {
      final String n = FileUtil.timestampedName('x.py');
      final RegExpMatch? m = RegExp(r'_(\d{8})_(\d{6})\.py$').firstMatch(n);
      expect(m, isNotNull, reason: n);
      final String s = m!.group(1)! + m.group(2)!;
      final DateTime d = DateTime.parse('${s.substring(0, 4)}-${s.substring(4, 6)}'
          '-${s.substring(6, 8)}T${s.substring(8, 10)}:'
          '${s.substring(10, 12)}:${s.substring(12, 14)}');
      expect(d.difference(DateTime.now()).inMinutes.abs(), lessThan(2),
          reason: '时间戳不是当前时间：$n');
    });
  });

  group('日志保存必须带扩展名', () {
    test('任务名（无后缀）补 .log', () {
      // 运行日志页的 title 是任务名，「天天夺宝」直接存出来是无后缀文件
      expect(FileUtil.withLogExtension('天天夺宝'), '天天夺宝.log');
      expect(FileUtil.withLogExtension('  elm/天天夺宝  '), 'elm/天天夺宝.log');
    });

    test('已有扩展名的原样保留', () {
      expect(FileUtil.withLogExtension('a.log'), 'a.log');
      expect(FileUtil.withLogExtension('task.txt'), 'task.txt');
    });

    test('空名字也有兜底', () {
      expect(FileUtil.withLogExtension(''), 'log.log');
      expect(FileUtil.withLogExtension('   '), 'log.log');
    });

    test('补完再插时间戳，后缀仍在末尾', () {
      final String n = FileUtil.timestampedName(
          FileUtil.withLogExtension('天天夺宝'));
      expect(RegExp(r'^天天夺宝_\d{8}_\d{6}\.log$').hasMatch(n), isTrue,
          reason: n);
    });
  });
}
