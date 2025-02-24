import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
    
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Merge Files App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainPage(),
    );
  }
}
// fdfdfdkfjdkfjsjfsdijfiosjfoisrjfiowjerdiojs TEST 
// fdfdfdkfjdkfjsjfsdijfiosjfoisrjfiowjerdiojs TEST 
// fdfdfdkfjdkfjsjfsdijfiosjfoisrjfiowjerdiojs TEST 
// fdfdfdkfjdkfjsjfsdijfiosjfoisrjfiowjerdiojs TEST 
// fdfdfdkfjdkfjsjfsdijfiosjfoisrjfiowjerdiojs TEST 
// fdfdfdkfjdkfjsjfsdijfiosjfoisrjfiowjerdiojs TEST 
// fdfdfdkfjdkfjsjfsdijfiosjfoisrjfiowjerdiojs TEST 
// fdfdfdkfjdkfjsjfsdijfiosjfoisrjfiowjerdiojs TEST 
// fdfdfdkfjdkfjsjfsdijfiosjfoisrjfiowjerdiojs TEST 
// fdfdfdkfjdkfjsjfsdijfiosjfoisrjfiowjerdiojs TEST 
// fdfdfdkfjdkfjsjfsdijfiosjfoisrjfiowjerdiojs TEST 
// fdfdfdkfjdkfjsjfsdijfiosjfoisrjfiowjerdiojs TEST 
// fdfdfdkfjdkfjsjfsdijfiosjfoisrjfiowjerdiojs TEST 
// fdfdfdkfjdkfjsjfsdijfiosjfoisrjfiowjerdiojs TEST 
// fdfdfdkfjdkfjsjfsdijfiosjfoisrjfiowjerdiojs TEST 
// fdfdfdkfjdkfjsjfsdijfiosjfoisrjfiowjerdiojs TEST 
// fdfdfdkfjdkfjsjfsdijfiosjfoisrjfiowjerdiojs TEST 

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);
    
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool _isMergeButtonEnabled = false;
  double _mergeProgress = 0.0;
  List<String> _statusMessages = [];
  late Timer _usbCheckTimer;
  int hello = 2;
  @override
  void initState() {
    super.initState();
    _requestPermission();
    _startUsbCheckTimer();
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
    }
    _checkUsbStorage();
  }

  void _startUsbCheckTimer() {
    _usbCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkUsbStorage();
    });
  }

  Future<void> _checkUsbStorage() async {
    final directoryPath = '/mnt/media_rw/42C5-B60E';
    if (await Directory(directoryPath).exists()) {
      setState(() {
        _isMergeButtonEnabled = true;
      });
    } else {
      setState(() {
        _isMergeButtonEnabled = false;
      });
    }
  }

  Future<void> _startMerge() async {
    setState(() {
      _mergeProgress = 0.0;
      _statusMessages.clear();
    });

    final usbDirectoryPath = '/mnt/media_rw/42C5-B60E';
    final documentsDir = Directory('/storage/emulated/0/Documents');
    final usbDirectory = Directory(usbDirectoryPath);

    if (await usbDirectory.exists()) {
      List<FileSystemEntity> files = usbDirectory.listSync();
      int totalFiles = files.where((file) => file is File && file.path.endsWith('.csv')).length;
      int processedFiles = 0;

      // Copy all CSV files from the USB drive to the Documents folder.
      for (FileSystemEntity file in files) {
        if (file is File && file.path.endsWith('.csv')) {
          final fileName = file.uri.pathSegments.last;
          final copiedFilePath = '${documentsDir.path}/$fileName';

          try {
            await file.copy(copiedFilePath);
            setState(() {
              _statusMessages.add('Copied $fileName to Documents.');
            });
          } catch (e) {
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

      // Merge rows from daniel.csv into the appropriate destination file.
      await _mergeDanielCsv(documentsDir);
      
      setState(() {
        _mergeProgress = 1.0;
      });
    }
  }

  /// Merges data from daniel.csv into destination files.
  ///
  /// For each data row (skipping the header) in daniel.csv:
  /// 1. Parse the timestamp from column 1.
  /// 2. Choose the destination file based on its file-name timestamp.
  /// 3. In that destination file (which is assumed to already have a header row):
  ///    - For each row, if it has fewer than 23 columns, pad it (without trimming extra columns).
  ///    - In the header row (row 0), update columns 18–23 (indices 17–22) to have the expected header names.
  ///    - Then, search through the data rows (starting at row 1) for a row where the value in column 17 (index 16)
  ///      matches the daniel row's timestamp.
  ///    - When found, write the six columns from the daniel row into columns 18–23 of that row.
  /// The daniel.csv file is not modified.
  Future<void> _mergeDanielCsv(Directory documentsDir) async {
  // Get all CSV files in Documents except daniel.csv.
  List<File> destFiles = documentsDir
      .listSync()
      .where((entity) =>
          entity is File &&
          entity.path.endsWith('.csv') &&
          !entity.path.toLowerCase().contains('daniel'))
      .map((e) => e as File)
      .toList();

  // Build a list of (timestamp, File) pairs from file names.
  List<MapEntry<int, File>> fileEntries = [];
  for (File file in destFiles) {
    String fileName = file.uri.pathSegments.last;
    String timestampStr = fileName.replaceAll('.csv', '');
    try {
      int timestamp = int.parse(timestampStr);
      fileEntries.add(MapEntry(timestamp, file));
    } catch (e) {
      setState(() {
        _statusMessages.add('Skipping $fileName: invalid timestamp.');
      });
    }
  }
  fileEntries.sort((a, b) => a.key.compareTo(b.key));

  // Read daniel.csv (do not modify this file).
  File danielFile = File('${documentsDir.path}/daniel.csv');
  if (!await danielFile.exists()) {
    setState(() {
      _statusMessages.add('daniel.csv not found in Documents.');
    });
    return;
  }
  String danielContent = await danielFile.readAsString();
  List<List<dynamic>> danielRows =
      const CsvToListConverter().convert(danielContent);

  // Expected header values for destination columns 18–23.
  List<String> expectedHeaders = [
    "Timestamp",
    "Event Description",
    "SessionID",
    "ParticipantID",
    "ExperimenterID",
    "DeviceID"
  ];

  // Process each data row in daniel.csv (skip header row).
  for (var dRow in danielRows.skip(1)) {
    if (dRow.isEmpty) continue;
    int dTimestamp;
    try {
      dTimestamp = int.parse(dRow[0].toString());
    } catch (e) {
      setState(() {
        _statusMessages.add('Invalid timestamp in daniel row: $dRow');
      });
      continue;
    }

    // Choose destination file using the same logic as before.
    int? candidateIndex;
    for (int i = 0; i < fileEntries.length; i++) {
      if (fileEntries[i].key > dTimestamp) {
        candidateIndex = i;
        break;
      }
    }
    File? destinationFile;
    if (candidateIndex != null && candidateIndex > 0) {
      destinationFile = fileEntries[candidateIndex - 1].value;
    } else if (candidateIndex == null && fileEntries.isNotEmpty) {
      destinationFile = fileEntries.last.value;
    } else {
      setState(() {
        _statusMessages.add('No suitable destination for daniel row with timestamp $dTimestamp.');
      });
      continue;
    }
    File destFile = destinationFile!;

    // Read destination file. Enforce a newline at the end.
    String destContent = await destFile.readAsString();
    if (!destContent.endsWith("\n")) {
      destContent += "\n";
    }
    List<List<dynamic>> destRows =
        const CsvToListConverter().convert(destContent);

    // If the file is empty, log and skip merging.
    if (destRows.isEmpty) {
      setState(() {
        _statusMessages.add('Destination file ${destFile.uri.pathSegments.last} is empty, skipping merge.');
      });
      continue;
    }

    // Always assume the first row is the header.
    // Pad header row to at least 23 columns and update columns 18–23.
    while (destRows[0].length < 23) {
      destRows[0].add('');
    }
    for (int i = 0; i < expectedHeaders.length; i++) {
      destRows[0][17 + i] = expectedHeaders[i];
    }

    // For each data row (starting at index 1), pad to at least 23 columns.
    for (int i = 1; i < destRows.length; i++) {
      if (destRows[i].length < 23) {
        destRows[i] = List<dynamic>.from(destRows[i]) +
            List<dynamic>.filled(23 - destRows[i].length, '');
      }
    }

    // Search for a matching destination row.
    bool foundMatch = false;
    // Data rows always start at index 1.
    for (int i = 1; i < destRows.length; i++) {
      // We assume the destination timestamp is in column 17 (index 16).
      if (destRows[i].length < 17) continue;
      try {
        int destTimestamp = int.parse(destRows[i][16].toString());
        if (destTimestamp == dTimestamp) {
          // Found the matching row. Update columns 18–23 (indices 17–22)
          // with the six columns from the daniel row.
          for (int j = 0; j < 6; j++) {
            destRows[i][17 + j] = dRow[j];
          }
          foundMatch = true;
          break;
        }
      } catch (e) {
        continue;
      }
    }
    if (!foundMatch) {
      setState(() {
        _statusMessages.add(
            'No matching destination row (col 17) found for daniel row timestamp $dTimestamp in ${destFile.uri.pathSegments.last}.');
      });
    } else {
      String updatedCsv = const ListToCsvConverter().convert(destRows);
      await destFile.writeAsString(updatedCsv);
      setState(() {
        _statusMessages.add('Merged daniel row with timestamp $dTimestamp into ${destFile.uri.pathSegments.last}.');
      });
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge Files App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_statusMessages.isNotEmpty) ...[
              const Text('Status:'),
              for (var message in _statusMessages) Text(message),
              const SizedBox(height: 16.0),
            ],
            LinearProgressIndicator(
              value: _mergeProgress,
              minHeight: 20,
              backgroundColor: Colors.grey[300],
              color: Colors.blue,
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _isMergeButtonEnabled ? _startMerge : null,
              child: const Text('Merge Files'),
            ),
          ],
        ),
      ),
    );
  }
}
