import 'dart:io';

// TODO: remove
// https://github.com/flutter/flutter/issues/182281
const newOverScrollIndicator = '362b1de29974ffc1ed6faa826e1df870d7bec75f';

const bottomSheetAndroidPatch = 'lib/scripts/bottom_sheet_android.patch';

// https://github.com/bggRGjQaUbCoE/PiliPlus/issues/1906
const bottomSheetIOSFlutterPatch = 'lib/scripts/bottom_sheet_ios_flutter.patch';
const bottomSheetIOSPiliPlusPatch =
    'lib/scripts/bottom_sheet_ios_piliplus.patch';

// https://github.com/bggRGjQaUbCoE/PiliPlus/issues/1662
const scrollViewPatch = 'lib/scripts/scroll_view.patch';

// https://github.com/bggRGjQaUbCoE/PiliPlus/issues/2106
const textSelectionPatch = 'lib/scripts/text_selection.patch';

// https://github.com/bggRGjQaUbCoE/PiliPlus/issues/1947
const navigatorPatch = 'lib/scripts/navigator.patch';

// https://github.com/bggRGjQaUbCoE/PiliPlus/issues/2107
const imageAnimPatch = 'lib/scripts/image_anim.patch';

// TODO: remove
// https://github.com/flutter/flutter/issues/90223
const modalBarrierPatch = 'lib/scripts/modal_barrier.patch';

// TODO: remove
// https://github.com/flutter/flutter/issues/182466
const mouseCursorPatch = 'lib/scripts/mouse_cursor.patch';

Future<void> main(List<String> args) async {
  try {
    final exitCode = await _patch(args);
    if (exitCode != 0) {
      exit(exitCode);
    }
  } catch (e, st) {
    stderr
      ..writeln('Patch Error: $e')
      ..writeln(st);
    exit(1);
  }
}

Future<int> _patch(List<String> args) async {
  final platform = args.isNotEmpty ? args[0].toLowerCase() : '';
  final workspace =
      Platform.environment['GITHUB_WORKSPACE'] ?? Directory.current.path;

  if (platform == 'ios') {
    final code = await _git(
      ['apply', bottomSheetIOSPiliPlusPatch],
      workingDirectory: workspace,
    );
    if (code == 0) {
      stdout.writeln('$bottomSheetIOSPiliPlusPatch applied');
    }
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null || flutterRoot.isEmpty) {
    throw Exception('FLUTTER_ROOT is not set');
  }

  final picks = <String>[];
  final reverts = <String>[];
  final patches = <String>[
    modalBarrierPatch,
    textSelectionPatch,
    mouseCursorPatch,
    imageAnimPatch,
  ];

  switch (platform) {
    case 'android':
      reverts.add(newOverScrollIndicator);
      patches
        ..add(bottomSheetAndroidPatch)
        ..add(scrollViewPatch)
        ..add(navigatorPatch);
      break;
    case 'ios':
      patches
        ..add(scrollViewPatch)
        ..add(bottomSheetIOSFlutterPatch)
        ..add(navigatorPatch);
      break;
    case 'linux':
    case 'macos':
    case 'windows':
    default:
      break;
  }

  var lastExitCode = 0;

  lastExitCode = await _git([
    'config',
    '--global',
    'user.name',
    'ci',
  ], workingDirectory: flutterRoot);
  lastExitCode = await _git(
    ['config', '--global', 'user.email', 'example@example.com'],
    workingDirectory: flutterRoot,
  );

  lastExitCode = await _git(
    ['reset', '--hard', 'HEAD'],
    workingDirectory: flutterRoot,
  );

  for (final pick in picks) {
    lastExitCode = await _git(['stash'], workingDirectory: flutterRoot);
    final code = await _git([
      'cherry-pick',
      pick,
      '--no-edit',
    ], workingDirectory: flutterRoot);
    lastExitCode = code;
    if (code == 0) {
      lastExitCode = await _git(
        ['reset', '--soft', 'HEAD~1'],
        workingDirectory: flutterRoot,
      );
      stdout.writeln('$pick picked');
    }
    lastExitCode = await _git(['stash', 'pop'], workingDirectory: flutterRoot);
  }

  for (final revert in reverts) {
    lastExitCode = await _git(['stash'], workingDirectory: flutterRoot);
    final code = await _git([
      'revert',
      revert,
      '--no-edit',
    ], workingDirectory: flutterRoot);
    lastExitCode = code;
    if (code == 0) {
      lastExitCode = await _git(
        ['reset', '--soft', 'HEAD~1'],
        workingDirectory: flutterRoot,
      );
      stdout.writeln('$revert reverted');
    }
    lastExitCode = await _git(['stash', 'pop'], workingDirectory: flutterRoot);
  }

  for (final patch in patches) {
    lastExitCode = await _git(
      ['apply', _joinPath(workspace, patch)],
      workingDirectory: flutterRoot,
    );
    if (lastExitCode == 0) {
      stdout.writeln('$patch applied');
    }
  }

  return lastExitCode;
}

Future<int> _git(List<String> args, {String? workingDirectory}) {
  return _run('git', args, workingDirectory: workingDirectory);
}

Future<int> _run(
  String executable,
  List<String> args, {
  String? workingDirectory,
}) async {
  final result = await Process.run(
    executable,
    args,
    workingDirectory: workingDirectory,
    runInShell: Platform.isWindows,
  );

  if (result.stdout.toString().isNotEmpty) {
    stdout.write(result.stdout);
  }
  if (result.stderr.toString().isNotEmpty) {
    stderr.write(result.stderr);
  }

  return result.exitCode;
}

String _joinPath(String root, String child) {
  final separator = Platform.pathSeparator;
  final normalizedRoot = root.endsWith(separator)
      ? root.substring(0, root.length - 1)
      : root;
  final normalizedChild = child.replaceAll('/', separator);
  return '$normalizedRoot$separator$normalizedChild';
}
