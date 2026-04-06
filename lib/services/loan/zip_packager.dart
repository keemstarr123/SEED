import 'dart:typed_data';
import 'package:archive/archive.dart';

Future<Uint8List> createLoanZip(Map<String, Uint8List> files) async {
  final archive = Archive();
  files.forEach((filename, bytes) {
    archive.addFile(ArchiveFile(filename, bytes.length, bytes));
  });
  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded);
}
