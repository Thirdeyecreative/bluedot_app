import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/config/api_config.dart';
import '../models/certificate_model.dart';

class CertificatePdfService {
  CertificatePdfService._();

  static const _primaryBlue = PdfColor.fromInt(0xFF3C4FAF);
  static const _primaryYellow = PdfColor.fromInt(0xFFE8BB49);
  static const _forestGreen = PdfColor.fromInt(0xFF566D5B);
  static const _darkGrey = PdfColor.fromInt(0xFF2C2C2C);
  static const _slateGrey = PdfColor.fromInt(0xFF6F7DA2);
  static const _creamBg = PdfColor.fromInt(0xFFFCFAF4);
  static const _borderGold = PdfColor.fromInt(0xFFDFC27D);

  /// Generates the raw PDF bytes for an official volunteer certificate.
  static Future<Uint8List> generatePdf({
    required VolunteerCertificate cert,
    required String recipientName,
  }) async {
    final pdf = pw.Document(
      title: 'BlueDot Certificate - ${cert.certificateNo}',
      author: 'BlueDot Foundation',
      creator: 'BlueDot Climate Action Network',
    );

    // Load fonts resiliently per weight with fallback to standard Helvetica
    pw.Font fontRegular;
    pw.Font fontBold;
    final pw.Font fontItalic = pw.Font.helveticaOblique();

    try {
      fontRegular = await PdfGoogleFonts.outfitRegular();
    } catch (_) {
      fontRegular = pw.Font.helvetica();
    }

    try {
      fontBold = await PdfGoogleFonts.outfitBold();
    } catch (_) {
      fontBold = pw.Font.helveticaBold();
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              color: _creamBg,
              borderRadius: pw.BorderRadius.circular(16),
              border: pw.Border.all(color: _borderGold, width: 3),
            ),
            child: pw.Container(
              margin: const pw.EdgeInsets.all(8),
              padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 24),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: _forestGreen.shade(0.3), width: 1),
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // ── Top Header ─────────────────────────────────────────────
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BLUEDOT FOUNDATION',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 14,
                              letterSpacing: 2,
                              color: _primaryBlue,
                            ),
                          ),
                          pw.Text(
                            'Turn Climate Action into a Movement',
                            style: pw.TextStyle(
                              font: fontItalic,
                              fontSize: 9,
                              color: _slateGrey,
                            ),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: _forestGreen.shade(0.1),
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(color: _forestGreen.shade(0.3), width: 0.8),
                        ),
                        child: pw.Text(
                          'OFFICIAL RECORD: ${cert.certificateNo}',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 9,
                            letterSpacing: 1,
                            color: _forestGreen,
                          ),
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 10),

                  // ── Title & Citation ───────────────────────────────────────
                  pw.Column(
                    children: [
                      pw.Text(
                        'CERTIFICATE OF CONTRIBUTION',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 22,
                          letterSpacing: 3,
                          color: _forestGreen,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'This is to proudly certify that',
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 12,
                          color: _slateGrey,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        recipientName.toUpperCase(),
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 26,
                          letterSpacing: 1.5,
                          color: _primaryBlue,
                        ),
                      ),
                      pw.Container(
                        margin: const pw.EdgeInsets.symmetric(vertical: 8),
                        height: 2,
                        width: 180,
                        color: _primaryYellow,
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 40),
                        child: pw.RichText(
                          textAlign: pw.TextAlign.center,
                          text: pw.TextSpan(
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 11,
                              color: _darkGrey,
                              height: 1.5,
                            ),
                            children: [
                              const pw.TextSpan(text: 'has actively contributed as a '),
                              pw.TextSpan(
                                text: '${cert.role} ',
                                style: pw.TextStyle(font: fontBold, color: _forestGreen),
                              ),
                              const pw.TextSpan(text: 'at the environmental initiative\n'),
                              pw.TextSpan(
                                text: '"${cert.eventTitle}" ',
                                style: pw.TextStyle(font: fontBold, color: _primaryBlue),
                              ),
                              pw.TextSpan(
                                text: 'organized at ${cert.siteName} on ${cert.dateLabel}.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 12),

                  // ── Impact Stats Strip ─────────────────────────────────────
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(12),
                      border: pw.Border.all(color: _borderGold.shade(0.5), width: 1),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat('Trees Planted', '${cert.treesPlanted}', fontBold, fontRegular, _forestGreen),
                        _buildDivider(),
                        _buildStat('Hours Volunteered', '${cert.hours} Hours', fontBold, fontRegular, _primaryBlue),
                        _buildDivider(),
                        _buildStat('Date Recorded', cert.dateLabel, fontBold, fontRegular, _darkGrey),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 14),

                  // ── Footer: Signature, Seal & QR Verification ──────────────
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      // Signature block
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: 140,
                            height: 1,
                            color: _slateGrey.shade(0.5),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Executive Director',
                            style: pw.TextStyle(font: fontBold, fontSize: 10, color: _darkGrey),
                          ),
                          pw.Text(
                            'BlueDot Ecological Initiatives',
                            style: pw.TextStyle(font: fontRegular, fontSize: 8, color: _slateGrey),
                          ),
                        ],
                      ),

                      // Seal badge
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(color: _primaryYellow, width: 2),
                          color: _forestGreen.shade(0.08),
                        ),
                        child: pw.Text(
                          'VERIFIED\nIMPACT',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 7,
                            letterSpacing: 1,
                            color: _forestGreen,
                          ),
                        ),
                      ),

                      // Verification ID block
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'VERIFICATION CODE',
                            style: pw.TextStyle(font: fontBold, fontSize: 8, letterSpacing: 1, color: _slateGrey),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            cert.certificateNo,
                            style: pw.TextStyle(font: fontBold, fontSize: 10, color: _primaryBlue),
                          ),
                          pw.Text(
                            'Verify at: https://bluedot.eco/verify',
                            style: pw.TextStyle(font: fontRegular, fontSize: 7, color: _slateGrey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildStat(
    String label,
    String value,
    pw.Font fontBold,
    pw.Font fontRegular,
    PdfColor color,
  ) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 16,
            color: color,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            font: fontRegular,
            fontSize: 8,
            letterSpacing: 1,
            color: _slateGrey,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildDivider() {
    return pw.Container(
      height: 24,
      width: 1,
      color: _borderGold.shade(0.4),
    );
  }

  /// Fetches the server's official verified PDF with BlueDot seal and verification QR code,
  /// falling back gracefully to local client rendering if offline.
  static Future<Uint8List> getCertificateBytes({
    required VolunteerCertificate cert,
    required String recipientName,
    String? token,
  }) async {
    if (cert.downloadUrl != null && cert.downloadUrl!.isNotEmpty) {
      try {
        final cleanBase = ApiConfig.baseUrl.endsWith('/')
            ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
            : ApiConfig.baseUrl;
        final endpoint = cert.downloadUrl!.startsWith('/') ? cert.downloadUrl! : '/${cert.downloadUrl!}';
        var finalUrl = '$cleanBase$endpoint';
        final headers = <String, String>{};
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
          final sep = finalUrl.contains('?') ? '&' : '?';
          finalUrl = '$finalUrl${sep}token=$token';
        }
        final res = await http.get(Uri.parse(finalUrl), headers: headers).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          return res.bodyBytes;
        }
      } catch (_) {
        // Fall back gracefully to local client rendering
      }
    }
    return generatePdf(cert: cert, recipientName: recipientName);
  }

  /// Opens the native platform print and PDF viewer dialog, allowing the user
  /// to save the PDF directly to storage (Downloads, iCloud, Drive, etc.).
  static Future<void> downloadCertificate({
    required VolunteerCertificate cert,
    required String recipientName,
    String? token,
  }) async {
    final pdfBytes = await getCertificateBytes(
      cert: cert,
      recipientName: recipientName,
      token: token,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'BlueDot_Certificate_${cert.certificateNo}.pdf',
    );
  }

  /// Opens the native platform share sheet with the generated PDF attached.
  static Future<void> shareCertificate({
    required VolunteerCertificate cert,
    required String recipientName,
    String? token,
  }) async {
    final bytes = await getCertificateBytes(
      cert: cert,
      recipientName: recipientName,
      token: token,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'BlueDot_Certificate_${cert.certificateNo}.pdf',
    );
  }
}
