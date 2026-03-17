import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../config/feature_flags.dart';
import 'user_service.dart';

/// In-app purchase product IDs.
/// These must match the product IDs configured in the App Store / Google Play.
abstract class ProductIds {
  /// +1 extra send today
  static const String extraSend1 = 'thinking_of_u_extra_send_1';

  /// +3 extra sends today
  static const String extraSend3 = 'thinking_of_u_extra_send_3';

  /// +1 day extension (delays reset for unreciprocated sends)
  static const String extension1Day = 'thinking_of_u_extension_1day';

  /// +3 day extension bundle
  static const String extension3Days = 'thinking_of_u_extension_3days';

  static const Set<String> all = {
    extraSend1,
    extraSend3,
    extension1Day,
    extension3Days,
  };
}

/// Service for managing in-app purchases.
class PurchaseService {
  final InAppPurchase _iap;
  final UserService _userService;

  late StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;

  final _purchaseController = StreamController<PurchaseResult>.broadcast();

  /// Stream of purchase results for the UI to react to.
  Stream<PurchaseResult> get purchaseResults => _purchaseController.stream;

  /// Currently loaded products from the store.
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  String? _currentUserHash;

  PurchaseService({
    InAppPurchase? iap,
    required UserService userService,
  })  : _iap = iap ?? InAppPurchase.instance,
        _userService = userService;

  /// Initialize the purchase service. Call once at app startup.
  Future<void> initialize(String userHash) async {
    if (!FeatureFlags.enableInAppPurchases) return;

    _currentUserHash = userHash;

    // Listen for purchase updates
    _purchaseSubscription =
        _iap.purchaseStream.listen(_handlePurchaseUpdate, onDone: () {
      _purchaseSubscription.cancel();
    }, onError: (error) {
      debugPrint('Purchase stream error: $error');
    });

    await loadProducts();

    // Restore any pending purchases
    await _iap.restorePurchases();
  }

  /// Load available products from the store.
  Future<void> loadProducts() async {
    final response = await _iap.queryProductDetails(ProductIds.all);
    if (response.error != null) {
      debugPrint('Product load error: ${response.error}');
    }
    _products = response.productDetails;
    debugPrint('Loaded ${_products.length} products');
  }

  /// Initiate a purchase for the given product.
  Future<void> purchase(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    if (product.id == ProductIds.extraSend1 ||
        product.id == ProductIds.extraSend3 ||
        product.id == ProductIds.extension1Day ||
        product.id == ProductIds.extension3Days) {
      await _iap.buyConsumable(purchaseParam: param);
    }
  }

  /// Handle incoming purchase updates.
  Future<void> _handlePurchaseUpdate(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        _purchaseController
            .add(PurchaseResult(status: PurchaseResultStatus.pending));
      } else if (purchase.status == PurchaseStatus.error) {
        _purchaseController.add(PurchaseResult(
          status: PurchaseResultStatus.error,
          message: purchase.error?.message ?? 'Purchase failed',
        ));
        await _iap.completePurchase(purchase);
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final valid = await _verifyAndApplyPurchase(purchase);
        if (valid) {
          _purchaseController
              .add(PurchaseResult(status: PurchaseResultStatus.success));
        } else {
          _purchaseController.add(PurchaseResult(
            status: PurchaseResultStatus.error,
            message: 'Could not verify purchase.',
          ));
        }
        await _iap.completePurchase(purchase);
      }
    }
  }

  /// Verify and apply the benefits of a completed purchase.
  Future<bool> _verifyAndApplyPurchase(PurchaseDetails purchase) async {
    if (_currentUserHash == null) return false;

    try {
      switch (purchase.productID) {
        case ProductIds.extraSend1:
          await _userService.increaseDailyLimit(_currentUserHash!, 1);
          break;
        case ProductIds.extraSend3:
          await _userService.increaseDailyLimit(_currentUserHash!, 3);
          break;
        case ProductIds.extension1Day:
          await _userService.addExtensionDays(_currentUserHash!, 1);
          break;
        case ProductIds.extension3Days:
          await _userService.addExtensionDays(_currentUserHash!, 3);
          break;
        default:
          debugPrint('Unknown product: ${purchase.productID}');
          return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error applying purchase: $e');
      return false;
    }
  }

  void dispose() {
    _purchaseSubscription.cancel();
    _purchaseController.close();
  }
}

class PurchaseResult {
  final PurchaseResultStatus status;
  final String? message;

  const PurchaseResult({required this.status, this.message});
}

enum PurchaseResultStatus { pending, success, error }
