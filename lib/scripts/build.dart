import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final arg = args.isNotEmpty ? args[0] : '';

  try {
    String? versionName;

    // git rev-list --count HEAD
    final versionCode = int.parse(
      (await _run('git', ['rev-list', '--count', 'HEAD'])).trim(),
    );

    // git rev-parse HEAD
    final commitHash = (await _run('git', ['rev-parse', 'HEAD'])).trim();

    final pubspec = File('pubspec.yaml');
    if (!pubspec.existsSync()) {
      throw Exception('pubspec.yaml not found');
    }

    final lines = pubspec.readAsLinesSync(encoding: utf8);
    final updatedLines = <String>[];

    final versionReg = RegExp(r'^\s*version:\s*([\d.]+)');

    for (final line in lines) {
      final match = versionReg.firstMatch(line);
      if (match != null) {
        versionName = match.group(1)!;

        if (arg == 'android') {
          versionName = '$versionName-${commitHash.substring(0, 9)}';
        }

        updatedLines.add('version: $versionName+$versionCode');
      } else {
        updatedLines.add(line);
      }
    }

    if (versionName == null) {
      throw Exception('version not found');
    }

    pubspec.writeAsStringSync(updatedLines.join('\n'), encoding: utf8);

    final buildTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final data = {
      'pili.name': versionName,
      'pili.code': versionCode,
      'pili.hash': commitHash,
      'pili.time': buildTime,
    };

    File('pili_release.json').writeAsStringSync(
      jsonEncode(data),
      encoding: utf8,
    );

    // GitHub Actions env
    final githubEnv = Platform.environment['GITHUB_ENV'];
    if (githubEnv != null) {
      File(githubEnv).writeAsStringSync(
        'version=$versionName+$versionCode\n',
        mode: FileMode.append,
      );
    }

    stdout.writeln('Prebuild success: $versionName+$versionCode');
  } catch (e, st) {
    stderr
      ..writeln('Prebuild Error: $e')
      ..writeln(st);
    exit(1);
  }
}

Future<String> _run(String cmd, List<String> args) async {
  final result = await Process.run(cmd, args);
  if (result.exitCode != 0) {
    throw Exception('$cmd failed: ${result.stderr}');
  }
  return result.stdout.toString();
}
