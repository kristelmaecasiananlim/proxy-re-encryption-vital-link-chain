import 'dart:html' as html;
import 'dart:typed_data';

class DownloadHelper {
  static void downloadWeb(Uint8List bytes, String filename) {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor =
        html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();

    html.Url.revokeObjectUrl(url);
  }
}
