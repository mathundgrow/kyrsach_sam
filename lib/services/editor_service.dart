import 'dart:io';

import '../models/class_node.dart';

/// Открывает исходный файл класса в Visual Studio Code.
///
/// Работает в несколько попыток, потому что в GUI-приложении macOS
/// команда `code` может быть не доступна в PATH:
/// 1. стандартные пути установки VS Code — сразу открыть нужную строку;
/// 2. `code -g file:line` из PATH;
/// 3. `open -a "Visual Studio Code" file` — открыть файл в приложении;
/// 4. `vscode://file/path:line` — URL-схема VS Code.
class EditorService {
  static const _codeCandidates = [
    '/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code',
    '/usr/local/bin/code',
    '/opt/homebrew/bin/code',
  ];

  Future<bool> openClassInVSCode(ClassNode node) async {
    final location = '${node.filePath}:${node.line}';

    for (final executable in _codeCandidates) {
      if (await _tryRun(executable, ['-g', location])) {
        return true;
      }
    }

    if (await _tryRun('code', ['-g', location], runInShell: true)) {
      return true;
    }

    if (await _tryRun('open', ['-a', 'Visual Studio Code', node.filePath])) {
      return true;
    }

    final uri = 'vscode://file${node.filePath}:${node.line}';
    return _tryRun('open', [uri]);
  }

  Future<bool> _tryRun(
    String executable,
    List<String> arguments, {
    bool runInShell = false,
  }) async {
    try {
      final result = await Process.run(
        executable,
        arguments,
        runInShell: runInShell,
      ).timeout(const Duration(seconds: 10));
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
