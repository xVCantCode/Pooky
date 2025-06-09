//
//  PookyIAPManager.m
//  LeanIOS
//
//  Created for Pooky App IAP Integration
//

#import "PookyIAPManager.h"

@interface PookyIAPManager()
@property (strong, nonatomic) NSArray *availableProducts;
@property (strong, nonatomic) SKProductsRequest *productsRequest;
@end

@implementation PookyIAPManager

+ (instancetype)sharedManager {
    static PookyIAPManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[PookyIAPManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

#pragma mark - Public Methods

- (BOOL)canMakePayments {
    return [SKPaymentQueue canMakePayments];
}

- (void)loadProducts:(NSArray *)productIds {
    if (![self canMakePayments]) {
        if ([self.delegate respondsToSelector:@selector(purchaseFailed:)]) {
            [self.delegate purchaseFailed:@"In-app purchases are disabled"];
        }
        return;
    }
    
    NSSet *productIdsSet = [NSSet setWithArray:productIds];
    self.productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdsSet];
    self.productsRequest.delegate = self;
    [self.productsRequest start];
}

- (void)purchaseProduct:(NSString *)productId {
    if (![self canMakePayments]) {
        if ([self.delegate respondsToSelector:@selector(purchaseFailed:)]) {
            [self.delegate purchaseFailed:@"In-app purchases are disabled"];
        }
        return;
    }
    
    SKProduct *product = [self productWithId:productId];
    if (product) {
        SKPayment *payment = [SKPayment paymentWithProduct:product];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    } else {
        if ([self.delegate respondsToSelector:@selector(purchaseFailed:)]) {
            [self.delegate purchaseFailed:@"Product not found"];
        }
    }
}

- (void)restorePurchases {
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (NSString *)receiptString {
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    if (!receiptData) {
        return nil;
    }
    return [receiptData base64EncodedStringWithOptions:0];
}

#pragma mark - Private Methods

- (SKProduct *)productWithId:(NSString *)productId {
    for (SKProduct *product in self.availableProducts) {
        if ([product.productIdentifier isEqualToString:productId]) {
            return product;
        }
    }
    return nil;
}

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    self.availableProducts = response.products;
    
    NSMutableArray *productArray = [NSMutableArray array];
    for (SKProduct *product in response.products) {
        NSMutableDictionary *productDict = [NSMutableDictionary dictionary];
        productDict[@"productId"] = product.productIdentifier;
        productDict[@"title"] = product.localizedTitle;
        productDict[@"description"] = product.localizedDescription;
        productDict[@"price"] = [product.price stringValue];
        productDict[@"priceLocale"] = product.priceLocale.localeIdentifier;
        
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterCurrencyStyle;
        formatter.locale = product.priceLocale;
        productDict[@"localizedPrice"] = [formatter stringFromNumber:product.price];
        
        [productArray addObject:productDict];
    }
    
    if ([self.delegate respondsToSelector:@selector(productsLoaded:)]) {
        [self.delegate productsLoaded:productArray];
    }
    
    if (response.invalidProductIdentifiers.count > 0) {
        NSLog(@"Invalid product identifiers: %@", response.invalidProductIdentifiers);
    }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(purchaseFailed:)]) {
        [self.delegate purchaseFailed:error.localizedDescription];
    }
}

#pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
                break;
            case SKPaymentTransactionStateDeferred:
                // Transaction is in the queue, but its final status is pending external action
                break;
            case SKPaymentTransactionStatePurchasing:
                // Transaction is being processed by the App Store
                break;
        }
    }
}

- (void)completeTransaction:(SKPaymentTransaction *)transaction {
    NSString *productId = transaction.payment.productIdentifier;
    NSString *transactionId = transaction.transactionIdentifier;
    NSString *receipt = [self receiptString];
    
    if ([self.delegate respondsToSelector:@selector(purchaseCompleted:transactionId:receipt:)]) {
        [self.delegate purchaseCompleted:productId transactionId:transactionId receipt:receipt];
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)restoreTransaction:(SKPaymentTransaction *)transaction {
    NSString *productId = transaction.originalTransaction.payment.productIdentifier;
    NSString *transactionId = transaction.originalTransaction.transactionIdentifier;
    NSString *receipt = [self receiptString];
    
    if ([self.delegate respondsToSelector:@selector(purchaseCompleted:transactionId:receipt:)]) {
        [self.delegate purchaseCompleted:productId transactionId:transactionId receipt:receipt];
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)failedTransaction:(SKPaymentTransaction *)transaction {
    NSString *error = @"Purchase failed";
    if (transaction.error) {
        error = transaction.error.localizedDescription;
    }
    
    if ([self.delegate respondsToSelector:@selector(purchaseFailed:)]) {
        [self.delegate purchaseFailed:error];
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

@end 