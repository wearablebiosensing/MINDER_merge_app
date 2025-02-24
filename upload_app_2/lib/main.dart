import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MaterialApp(
    home: UploadPage(userId: '12345'),
    debugShowCheckedModeBanner: false,
  ));
}

class UploadPage extends StatefulWidget {
  final String userId;
  const UploadPage({super.key, required this.userId});

  @override
  _UploadPageState createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  bool _isUploadButtonEnabled = false;
  final bool _isNextButtonEnabled = false;
  bool _isMergeButtonEnabled = false;
  double _mergeProgress = 0.0;
  final double _uploadProgress = 0.0;
  String _fileContent = '';
  final List<String> _statusMessages = [];
  late Timer _usbCheckTimer;

  @override
  void initState() {
    super.initState();
    _requestPermission();
    _checkUsbStorage();
    _startUsbCheckTimer();
  }

  void _startUsbCheckTimer() {
    _usbCheckTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _checkUsbStorage();
    });
  }

  @override
  void dispose() {
    _usbCheckTimer.cancel();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted) {
        print('Storage permission denied');
        return;
      }
    }
    print('Storage permission granted');
    _checkUsbStorage();
  }

  Future<void> _checkUsbStorage() async {
    final directoryPath = '/mnt/media_rw/42C5-B60E';
    final filePath = '$directoryPath/sample.txt';

    if (await Directory(directoryPath).exists()) {
      if (await File(filePath).exists()) {
        final fileContent = await File(filePath).readAsString();
        setState(() {
          _fileContent = fileContent;
          _isMergeButtonEnabled = true;
        });
      } else {
        setState(() {
          _fileContent = 'sample.txt not found.';
        });
        _showSampleFileDialog();
      }
    } else {
      setState(() {
        _isMergeButtonEnabled = false;
      });
      _showUsbDialog();
    }
  }

  void _showUsbDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('USB Storage not detected'),
          content: Text('Please insert a USB storage device to continue.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _checkUsbStorage();
              },
              child: Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  void _showSampleFileDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('sample.txt not found'),
          content: Text(
              'Please make sure the USB storage device contains a sample.txt file.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _checkUsbStorage();
              },
              child: Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _convertTsvToCsv(File tsvFile, Directory mergedDir) async {
    final input = tsvFile.openRead();
    final fields = await input
        .transform(utf8.decoder)
        .transform(LineSplitter())
        .map((line) => line.split('\t'))
        .toList();

    String csv = const ListToCsvConverter().convert(fields);

    String fileName = tsvFile.uri.pathSegments.last.replaceAll('.tsv', '.csv');
    File csvFile = File('${mergedDir.path}/$fileName');

    await csvFile.writeAsString(csv);

    setState(() {
      _statusMessages
          .add('Converted $fileName to CSV and saved in Merged directory.');
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'TSV file ${tsvFile.uri.pathSegments.last} converted to CSV and saved in Merged directory.'),
    ));
  }

  Future<void> _startMerge() async {
    if (!_isMergeButtonEnabled) {
      _showUsbDialog();
      return;
    }

    setState(() {
      _mergeProgress = 0.0;
      _isUploadButtonEnabled = false;
      _statusMessages.clear();
    });

    final usbDirectoryPath = '/mnt/media_rw/42C5-B60E';
    final documentsDir = Directory('/storage/emulated/0/Documents');
    final mergedDir = Directory('${documentsDir.path}/Merged');
    final usbDirectory = Directory(usbDirectoryPath);

    if (!await documentsDir.exists()) await documentsDir.create(recursive: true);
    if (!await mergedDir.exists()) await mergedDir.create(recursive: true);

    if (await usbDirectory.exists()) {
      List<FileSystemEntity> files = usbDirectory.listSync();
      int totalFiles = files
          .where((file) => file is File && file.path.endsWith('.tsv'))
          .length;
      int processedFiles = 0;

      for (FileSystemEntity file in files) {
        if (file is File && file.path.endsWith('.tsv')) {
          final fileName = file.uri.pathSegments.last;
          final copiedFilePath = '${documentsDir.path}/$fileName';

          try {
            await file.copy(copiedFilePath);
            setState(() {
              _statusMessages.add('Copied $fileName to Documents directory.');
            });

            await _convertTsvToCsv(File(copiedFilePath), mergedDir);
          } catch (e) {
            print('Error processing $fileName: $e');
            setState(() {
              _statusMessages.add('Error processing $fileName.');
            });
          }

          processedFiles++;
          setState(() {
            _mergeProgress = processedFiles / totalFiles;
          });
        }
      }
    } else {
      _showUsbDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upload & Merge TSV Files')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isMergeButtonEnabled ? _startMerge : null,
              child: Text('Merge TSV to CSV'),
            ),
            SizedBox(height: 16.0),
            LinearProgressIndicator(value: _mergeProgress),
            SizedBox(height: 16.0),
            Text('File Content: $_fileContent'),
            Expanded(
              child: ListView.builder(
                itemCount: _statusMessages.length,
                itemBuilder: (context, index) {
                  return ListTile(title: Text(_statusMessages[index]));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
