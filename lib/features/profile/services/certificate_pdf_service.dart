import 'dart:typed_data';

import 'package:printing/printing.dart';

import '../../../core/services/api_client.dart';
import '../models/certificate_model.dart';

class CertificatePdfService {
  const CertificatePdfService(this._api);

  final ApiClient _api;

  Future<Uint8List> getCertificateBytes(VolunteerCertificate cert) {
    final url = cert.downloadUrl;
    if (url == null || url.isEmpty) {
      throw const FormatException('Certificate download is unavailable');
    }
    return _api.downloadApiPdf(url);
  }

  Future<void> downloadCertificate(VolunteerCertificate cert) async {
    final bytes = await getCertificateBytes(cert);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'BlueDot_Certificate_${cert.certificateNo}.pdf',
    );
  }

  Future<void> shareCertificate(VolunteerCertificate cert) async {
    final bytes = await getCertificateBytes(cert);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'BlueDot_Certificate_${cert.certificateNo}.pdf',
    );
  }
}
