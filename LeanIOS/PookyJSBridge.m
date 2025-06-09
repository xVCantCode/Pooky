//
//  PookyJSBridge.m
//  LeanIOS
//
//  JavaScript Bridge for IAP Integration
//

#import "PookyJSBridge.h"

@implementation PookyJSBridge

- (instancetype)initWithWebView:(WKWebView *)webView {
    self = [super init];
    if (self) {
        self.webView = webView;
        [PookyIAPManager sharedManager].delegate = self;
        [self registerJSCallbacks];
    }
    return self;
}

- (void)registerJSCallbacks {
    // Register window.PookyIAP object in JavaScript
    NSString *jsCode = @"window.PookyIAP = {"
                       @"  loadProducts: function(productIds) {"
                       @"    window.webkit.messageHandlers.loadProducts.postMessage(productIds);"
                       @"  },"
                       @"  purchaseProduct: function(productId) {"
                       @"    window.webkit.messageHandlers.purchaseProduct.postMessage(productId);"
                       @"  },"
                       @"  restorePurchases: function() {"
                       @"    window.webkit.messageHandlers.restorePurchases.postMessage('');"
                       @"  },"
                       @"  canMakePayments: function() {"
                       @"    window.webkit.messageHandlers.canMakePayments.postMessage('');"
                       @"  }"
                       @"};";
    
    [self.webView evaluateJavaScript:jsCode completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"Error registering PookyIAP JS interface: %@", error.description);
        }
    }];
}

- (void)loadProducts:(NSArray *)productIds {
    [[PookyIAPManager sharedManager] loadProducts:productIds];
}

- (void)purchaseProduct:(NSString *)productId {
    [[PookyIAPManager sharedManager] purchaseProduct:productId];
}

- (void)restorePurchases {
    [[PookyIAPManager sharedManager] restorePurchases];
}

- (void)canMakePayments {
    BOOL canMake = [[PookyIAPManager sharedManager] canMakePayments];
    [self callJSCallback:@"onCanMakePayments" withData:@{@"canMakePayments": @(canMake)}];
}

#pragma mark - PookyIAPManagerDelegate

- (void)purchaseCompleted:(NSString *)productId transactionId:(NSString *)transactionId receipt:(NSString *)receipt {
    NSDictionary *data = @{
        @"productId": productId,
        @"transactionId": transactionId,
        @"receipt": receipt ?: @""
    };
    [self callJSCallback:@"onPurchaseCompleted" withData:data];
}

- (void)purchaseFailed:(NSString *)error {
    [self callJSCallback:@"onPurchaseFailed" withData:@{@"error": error}];
}

- (void)restoreCompleted:(NSArray *)restoredProducts {
    [self callJSCallback:@"onRestoreCompleted" withData:@{@"products": restoredProducts}];
}

- (void)productsLoaded:(NSArray *)products {
    [self callJSCallback:@"onProductsLoaded" withData:@{@"products": products}];
}

#pragma mark - Helper Methods

- (void)callJSCallback:(NSString *)functionName withData:(NSDictionary *)data {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:0 error:&error];
    if (error) {
        NSLog(@"Error serializing data: %@", error.description);
        return;
    }
    
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSString *jsCode = [NSString stringWithFormat:@"if (window.PookyIAP && window.PookyIAP.%@) { window.PookyIAP.%@(%@); }", functionName, functionName, jsonString];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.webView evaluateJavaScript:jsCode completionHandler:^(id result, NSError *error) {
            if (error) {
                NSLog(@"Error calling JS callback %@: %@", functionName, error.description);
            }
        }];
    });
}

@end 