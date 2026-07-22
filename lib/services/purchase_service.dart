import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/revenue_cat_config.dart';

class PurchaseService {
  static bool _initialized = false;

  static Future<void> initialize(String userId) async {
    if (_initialized) return;
    final apiKey = Platform.isIOS
        ? RevenueCatConfig.apiKeyIos
        : RevenueCatConfig.apiKeyAndroid;
    if (apiKey.isEmpty) return;
    await Purchases.setLogLevel(LogLevel.debug);
    final config = PurchasesConfiguration(apiKey);
    await Purchases.configure(config);
    if (userId.isNotEmpty) {
      await Purchases.logIn(userId);
    }
    _initialized = true;
  }

  static Future<bool> isPremium() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(RevenueCatConfig.entitlementId);
    } catch (_) {
      return false;
    }
  }

  static Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> purchasePackage(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      return result.customerInfo.entitlements.active.containsKey(RevenueCatConfig.entitlementId);
    } catch (e) {
      if (e is PurchasesErrorCode && e == PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      rethrow;
    }
  }

  static Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(RevenueCatConfig.entitlementId);
    } catch (_) {
      return false;
    }
  }
}
