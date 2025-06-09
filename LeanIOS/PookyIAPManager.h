//
//  PookyIAPManager.h
//  LeanIOS
//
//  Created for Pooky App IAP Integration
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@protocol PookyIAPManagerDelegate <NSObject>
- (void)purchaseCompleted:(NSString *)productId transactionId:(NSString *)transactionId receipt:(NSString *)receipt;
- (void)purchaseFailed:(NSString *)error;
- (void)restoreCompleted:(NSArray *)restoredProducts;
- (void)productsLoaded:(NSArray *)products;
@end

@interface PookyIAPManager : NSObject <SKProductsRequestDelegate, SKPaymentTransactionObserver>

@property (weak, nonatomic) id<PookyIAPManagerDelegate> delegate;

+ (instancetype)sharedManager;

// Product management
- (void)loadProducts:(NSArray *)productIds;
- (void)purchaseProduct:(NSString *)productId;
- (void)restorePurchases;

// Utilities
- (BOOL)canMakePayments;
- (NSString *)receiptString;

@end 