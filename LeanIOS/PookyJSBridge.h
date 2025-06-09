//
//  PookyJSBridge.h
//  LeanIOS
//
//  JavaScript Bridge for IAP Integration
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "PookyIAPManager.h"

@interface PookyJSBridge : NSObject <PookyIAPManagerDelegate>

@property (weak, nonatomic) WKWebView *webView;

- (instancetype)initWithWebView:(WKWebView *)webView;
- (void)registerJSCallbacks;

// JavaScript callable methods
- (void)loadProducts:(NSArray *)productIds;
- (void)purchaseProduct:(NSString *)productId;
- (void)restorePurchases;
- (void)canMakePayments;

@end 