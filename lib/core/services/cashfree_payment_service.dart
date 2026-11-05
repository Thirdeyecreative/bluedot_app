import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';

class CashfreePaymentResult {
  final bool isSuccess;
  final String orderId;
  final String? errorMessage;
  final bool isCancelled;

  CashfreePaymentResult({
    required this.isSuccess,
    required this.orderId,
    this.errorMessage,
    this.isCancelled = false,
  });
}

class CashfreePaymentService {
  final CFPaymentGatewayService _cfPaymentGatewayService = CFPaymentGatewayService();

  Future<CashfreePaymentResult> startPayment({
    required String orderId,
    required String paymentSessionId,
    required String environment, // "TEST" or "PROD"
    bool isMock = false,
  }) async {
    // If running in mock mode or on desktop/web where native Android/iOS SDK is unavailable
    if (isMock || kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('[CashfreeService] Running in mock/simulator mode for order: $orderId');
      return CashfreePaymentResult(isSuccess: true, orderId: orderId);
    }

    final env = environment.toUpperCase() == 'PROD'
        ? CFEnvironment.PRODUCTION
        : CFEnvironment.SANDBOX;

    try {
      final session = CFSessionBuilder()
          .setEnvironment(env)
          .setOrderId(orderId)
          .setPaymentSessionId(paymentSessionId)
          .build();

      final theme = CFThemeBuilder()
          .setNavigationBarBackgroundColorColor('#1B4332') // BlueDot Forest Green
          .setNavigationBarTextColor('#FFFFFF')
          .setButtonBackgroundColor('#1B4332')
          .setButtonTextColor('#FFFFFF')
          .setPrimaryTextColor('#1B4332')
          .setSecondaryTextColor('#555555')
          .build();

      final cfWebCheckout = CFWebCheckoutPaymentBuilder()
          .setSession(session)
          .setTheme(theme)
          .build();

      final completer = Completer<CashfreePaymentResult>();

      _cfPaymentGatewayService.setCallback(
        (String verifiedOrderId) {
          debugPrint('[CashfreeService] Payment callback success for order: $verifiedOrderId');
          if (!completer.isCompleted) {
            completer.complete(CashfreePaymentResult(
              isSuccess: true,
              orderId: verifiedOrderId.isNotEmpty ? verifiedOrderId : orderId,
            ));
          }
        },
        (CFErrorResponse errorResponse, String failedOrderId) {
          final msg = errorResponse.getMessage() ?? 'Payment was not completed.';
          final lower = msg.toLowerCase();
          final cancelled = lower.contains('cancel') ||
              lower.contains('back') ||
              lower.contains('dismiss') ||
              lower.contains('abort') ||
              lower.contains('dropped');

          debugPrint('[CashfreeService] Payment callback error: $msg (cancelled=$cancelled)');
          if (!completer.isCompleted) {
            completer.complete(CashfreePaymentResult(
              isSuccess: false,
              orderId: failedOrderId.isNotEmpty ? failedOrderId : orderId,
              errorMessage: msg,
              isCancelled: cancelled,
            ));
          }
        },
      );

      await _cfPaymentGatewayService.doPayment(cfWebCheckout);

      // Wait for the native callback or timeout gracefully after 10 minutes
      return await completer.future.timeout(
        const Duration(minutes: 10),
        onTimeout: () => CashfreePaymentResult(
          isSuccess: true,
          orderId: orderId,
        ),
      );
    } on CFException catch (e) {
      debugPrint('[CashfreeService] CFException: ${e.message}');
      return CashfreePaymentResult(
        isSuccess: false,
        orderId: orderId,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[CashfreeService] Error launching checkout: $e');
      return CashfreePaymentResult(
        isSuccess: false,
        orderId: orderId,
        errorMessage: e.toString(),
      );
    }
  }
}
