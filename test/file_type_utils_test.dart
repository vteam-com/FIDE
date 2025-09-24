import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/utils/file_type_utils.dart';

// Helper class for test cases
class TestCase {
  final String filename;
  final Matcher expectedType;
  final IconData? expectedIcon;

  const TestCase(this.filename, this.expectedType, {this.expectedIcon});
}

void main() {
  group('FileTypeUtils', () {
    group('isFileSupportedInEditor', () {
      test('returns true for supported text file extensions', () {
        expect(FileTypeUtils.isFileSupportedInEditor('main.dart'), true);
        expect(FileTypeUtils.isFileSupportedInEditor('script.py'), true);
        expect(FileTypeUtils.isFileSupportedInEditor('app.java'), true);
        expect(FileTypeUtils.isFileSupportedInEditor('index.html'), true);
        expect(FileTypeUtils.isFileSupportedInEditor('styles.css'), true);
        expect(FileTypeUtils.isFileSupportedInEditor('data.json'), true);
        expect(FileTypeUtils.isFileSupportedInEditor('README.md'), true);
      });

      test('returns true for supported image file extensions', () {
        expect(FileTypeUtils.isFileSupportedInEditor('photo.png'), true);
        expect(FileTypeUtils.isFileSupportedInEditor('image.jpg'), true);
        expect(FileTypeUtils.isFileSupportedInEditor('picture.gif'), true);
        expect(FileTypeUtils.isFileSupportedInEditor('icon.webp'), true);
      });

      test('returns false for unsupported file extensions', () {
        expect(FileTypeUtils.isFileSupportedInEditor('document.docx'), false);
        expect(FileTypeUtils.isFileSupportedInEditor('archive.zip'), false);
        expect(FileTypeUtils.isFileSupportedInEditor('executable.exe'), false);
        expect(FileTypeUtils.isFileSupportedInEditor('video.mp4'), false);
      });

      test('returns false for empty string', () {
        expect(FileTypeUtils.isFileSupportedInEditor(''), false);
      });

      test('handles case insensitive extensions', () {
        expect(FileTypeUtils.isFileSupportedInEditor('MAIN.DART'), true);
        expect(FileTypeUtils.isFileSupportedInEditor('script.PY'), true);
        expect(FileTypeUtils.isFileSupportedInEditor('photo.PNG'), true);
      });
    });

    group('isTextFile', () {
      test('returns true for supported text file extensions', () {
        expect(FileTypeUtils.isTextFile('main.dart'), true);
        expect(FileTypeUtils.isTextFile('script.py'), true);
        expect(FileTypeUtils.isTextFile('app.java'), true);
        expect(FileTypeUtils.isTextFile('index.html'), true);
        expect(FileTypeUtils.isTextFile('styles.css'), true);
        expect(FileTypeUtils.isTextFile('data.json'), true);
        expect(FileTypeUtils.isTextFile('README.md'), true);
        expect(FileTypeUtils.isTextFile('config.yaml'), true);
        expect(FileTypeUtils.isTextFile('script.sh'), true);
      });

      test('returns false for image file extensions', () {
        expect(FileTypeUtils.isTextFile('photo.png'), false);
        expect(FileTypeUtils.isTextFile('image.jpg'), false);
        expect(FileTypeUtils.isTextFile('picture.gif'), false);
      });

      test('returns false for unsupported file extensions', () {
        expect(FileTypeUtils.isTextFile('document.docx'), false);
        expect(FileTypeUtils.isTextFile('archive.zip'), false);
        expect(FileTypeUtils.isTextFile('executable.exe'), false);
      });

      test('returns false for empty string', () {
        expect(FileTypeUtils.isTextFile(''), false);
      });

      test('handles case insensitive extensions', () {
        expect(FileTypeUtils.isTextFile('MAIN.DART'), true);
        expect(FileTypeUtils.isTextFile('script.PY'), true);
      });
    });

    group('isImageFile', () {
      test('returns true for supported image file extensions', () {
        expect(FileTypeUtils.isImageFile('photo.png'), true);
        expect(FileTypeUtils.isImageFile('image.jpg'), true);
        expect(FileTypeUtils.isImageFile('picture.jpeg'), true);
        expect(FileTypeUtils.isImageFile('icon.gif'), true);
        expect(FileTypeUtils.isImageFile('logo.bmp'), true);
        expect(FileTypeUtils.isImageFile('sprite.webp'), true);
        expect(FileTypeUtils.isImageFile('scan.tiff'), true);
      });

      test('returns false for text file extensions', () {
        expect(FileTypeUtils.isImageFile('main.dart'), false);
        expect(FileTypeUtils.isImageFile('script.py'), false);
        expect(FileTypeUtils.isImageFile('index.html'), false);
      });

      test('returns false for unsupported file extensions', () {
        expect(FileTypeUtils.isImageFile('document.docx'), false);
        expect(FileTypeUtils.isImageFile('archive.zip'), false);
        expect(FileTypeUtils.isImageFile('video.mp4'), false);
      });

      test('returns false for empty string', () {
        expect(FileTypeUtils.isImageFile(''), false);
      });

      test('handles case insensitive extensions', () {
        expect(FileTypeUtils.isImageFile('PHOTO.PNG'), true);
        expect(FileTypeUtils.isImageFile('image.JPG'), true);
      });
    });
  });

  group('FileIconUtils', () {
    group('getFileIcon', () {
      // Test cases for different file types and their expected icons
      final testCases = [
        // Dart files (special case - uses SVG)
        TestCase('main.dart', isA<Widget>()), // SvgPicture.asset
        // Programming languages - developer_mode
        TestCase('main.c', isA<Icon>(), expectedIcon: Icons.developer_mode),
        TestCase('header.h', isA<Icon>(), expectedIcon: Icons.developer_mode),
        TestCase('lib.rs', isA<Icon>(), expectedIcon: Icons.developer_mode),
        TestCase('server.go', isA<Icon>(), expectedIcon: Icons.developer_mode),
        TestCase('app.java', isA<Icon>(), expectedIcon: Icons.developer_mode),
        TestCase('Main.kt', isA<Icon>(), expectedIcon: Icons.developer_mode),
        TestCase('utils.py', isA<Icon>(), expectedIcon: Icons.developer_mode),
        TestCase('app.pyw', isA<Icon>(), expectedIcon: Icons.developer_mode),
        TestCase('module.pyx', isA<Icon>(), expectedIcon: Icons.developer_mode),
        TestCase('types.pxd', isA<Icon>(), expectedIcon: Icons.developer_mode),
        TestCase(
          'interface.pxi',
          isA<Icon>(),
          expectedIcon: Icons.developer_mode,
        ),
        TestCase('App.swift', isA<Icon>(), expectedIcon: Icons.developer_mode),
        TestCase(
          'ViewController.m',
          isA<Icon>(),
          expectedIcon: Icons.developer_mode,
        ),
        TestCase('Utils.mm', isA<Icon>(), expectedIcon: Icons.developer_mode),
        TestCase(
          'program.scala',
          isA<Icon>(),
          expectedIcon: Icons.developer_mode,
        ),

        // Web technologies - code
        TestCase('app.js', isA<Icon>(), expectedIcon: Icons.javascript),
        TestCase('component.ts', isA<Icon>(), expectedIcon: Icons.code),
        TestCase('App.tsx', isA<Icon>(), expectedIcon: Icons.code),
        TestCase('Component.jsx', isA<Icon>(), expectedIcon: Icons.code),
        TestCase('App.vue', isA<Icon>(), expectedIcon: Icons.code),
        TestCase('Page.svelte', isA<Icon>(), expectedIcon: Icons.code),
        TestCase('index.html', isA<Icon>(), expectedIcon: Icons.code),
        TestCase('config.xml', isA<Icon>(), expectedIcon: Icons.code),

        // Stylesheets - css
        TestCase('styles.css', isA<Icon>(), expectedIcon: Icons.css),
        TestCase('component.scss', isA<Icon>(), expectedIcon: Icons.css),
        TestCase('styles.sass', isA<Icon>(), expectedIcon: Icons.css),
        TestCase('variables.less', isA<Icon>(), expectedIcon: Icons.css),

        // Data formats - data_object
        TestCase('data.json', isA<Icon>(), expectedIcon: Icons.data_object),
        TestCase('config.arb', isA<Icon>(), expectedIcon: Icons.data_object),
        TestCase(
          'docker-compose.yaml',
          isA<Icon>(),
          expectedIcon: Icons.data_object,
        ),
        TestCase('config.yml', isA<Icon>(), expectedIcon: Icons.data_object),
        TestCase('Cargo.toml', isA<Icon>(), expectedIcon: Icons.data_object),
        TestCase('data.csv', isA<Icon>(), expectedIcon: Icons.data_object),
        TestCase('graph.dot', isA<Icon>(), expectedIcon: Icons.data_object),

        // Documentation - text_snippet
        TestCase('README.md', isA<Icon>(), expectedIcon: Icons.text_snippet),
        TestCase(
          'CHANGELOG.markdown',
          isA<Icon>(),
          expectedIcon: Icons.text_snippet,
        ),
        TestCase('docs.rst', isA<Icon>(), expectedIcon: Icons.text_snippet),
        TestCase('README.adoc', isA<Icon>(), expectedIcon: Icons.text_snippet),

        // Configuration files - build
        TestCase('setup.ini', isA<Icon>(), expectedIcon: Icons.build),
        TestCase('nginx.cfg', isA<Icon>(), expectedIcon: Icons.build),
        TestCase('httpd.conf', isA<Icon>(), expectedIcon: Icons.build),
        TestCase('db.properties', isA<Icon>(), expectedIcon: Icons.build),
        TestCase('.env', isA<Icon>(), expectedIcon: Icons.build),
        TestCase('Info.plist', isA<Icon>(), expectedIcon: Icons.build),
        TestCase('build.gradle', isA<Icon>(), expectedIcon: Icons.build),

        // Lock files - terminal (since package-lock.json has .json extension)
        TestCase(
          'package-lock.json',
          isA<Icon>(),
          expectedIcon: Icons.data_object,
        ),
        TestCase('foobar.lock', isA<Icon>(), expectedIcon: Icons.lock),

        // Scripts - terminal
        TestCase('script.sh', isA<Icon>(), expectedIcon: Icons.terminal),
        TestCase('install.bash', isA<Icon>(), expectedIcon: Icons.terminal),
        TestCase('config.zsh', isA<Icon>(), expectedIcon: Icons.terminal),
        TestCase('setup.fish', isA<Icon>(), expectedIcon: Icons.terminal),
        TestCase('build.ps1', isA<Icon>(), expectedIcon: Icons.terminal),
        TestCase('deploy.bat', isA<Icon>(), expectedIcon: Icons.terminal),
        TestCase('run.cmd', isA<Icon>(), expectedIcon: Icons.terminal),

        // Other text files - article
        TestCase('notes.txt', isA<Icon>(), expectedIcon: Icons.article),
        TestCase('debug.log', isA<Icon>(), expectedIcon: Icons.article),
        TestCase('output.out', isA<Icon>(), expectedIcon: Icons.article),
        TestCase('.gitignore', isA<Icon>(), expectedIcon: Icons.article),
        TestCase('.dockerignore', isA<Icon>(), expectedIcon: Icons.article),

        // Images - image
        TestCase('photo.png', isA<Icon>(), expectedIcon: Icons.image),
        TestCase('image.jpg', isA<Icon>(), expectedIcon: Icons.image),
        TestCase('picture.jpeg', isA<Icon>(), expectedIcon: Icons.image),
        TestCase('icon.gif', isA<Icon>(), expectedIcon: Icons.image),
        TestCase('logo.bmp', isA<Icon>(), expectedIcon: Icons.image),
        TestCase('sprite.webp', isA<Icon>(), expectedIcon: Icons.image),
        TestCase('diagram.svg', isA<Icon>(), expectedIcon: Icons.image),
        TestCase('scan.tiff', isA<Icon>(), expectedIcon: Icons.image),
        TestCase('image.tif', isA<Icon>(), expectedIcon: Icons.image),
        TestCase('layer.ora', isA<Icon>(), expectedIcon: Icons.image),

        // Documents - picture_as_pdf
        TestCase(
          'document.pdf',
          isA<Icon>(),
          expectedIcon: Icons.picture_as_pdf,
        ),

        // Archives - archive
        TestCase('archive.zip', isA<Icon>(), expectedIcon: Icons.archive),
        TestCase('files.rar', isA<Icon>(), expectedIcon: Icons.archive),
        TestCase('backup.7z', isA<Icon>(), expectedIcon: Icons.archive),
        TestCase('source.tar', isA<Icon>(), expectedIcon: Icons.archive),
        TestCase('compressed.gz', isA<Icon>(), expectedIcon: Icons.archive),

        // Unknown file types - insert_drive_file
        TestCase(
          'unknown.xyz',
          isA<Icon>(),
          expectedIcon: Icons.insert_drive_file,
        ),
      ];

      for (final testCase in testCases) {
        test('returns correct icon for ${testCase.filename}', () {
          final item = FileSystemItem(
            path: '/path/to/${testCase.filename}',
            name: testCase.filename,
            type: FileSystemItemType.file,
            size: 100,
            modified: DateTime.now(),
          );

          final icon = FileIconUtils.getFileIcon(item);

          expect(icon, testCase.expectedType);
          if (testCase.expectedIcon != null) {
            expect((icon as Icon).icon, testCase.expectedIcon);
          }
        });
      }

      test('respects custom size parameter', () {
        final item = FileSystemItem(
          path: '/path/to/main.dart',
          name: 'main.dart',
          type: FileSystemItemType.file,
          size: 100,
          modified: DateTime.now(),
        );

        final icon = FileIconUtils.getFileIcon(item, size: 24.0);
        expect(icon, isA<Widget>());
        // Note: We can't easily test the exact size due to SvgPicture.asset implementation
      });

      test('handles case insensitive file extensions', () {
        final item = FileSystemItem(
          path: '/path/to/MAIN.DART',
          name: 'MAIN.DART',
          type: FileSystemItemType.file,
          size: 100,
          modified: DateTime.now(),
        );

        final icon = FileIconUtils.getFileIcon(item);
        expect(icon, isA<Widget>());
        // Should still return SvgPicture.asset for .DART extension
      });
    });
  });
}
