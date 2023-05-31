#import <SurveyPopupView/SvLogger.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SurveyPopupView : NSObject <WKNavigationDelegate, WKScriptMessageHandler>

// 问卷弹窗配置
@property (nonatomic, strong) UIColor *primaryBgColor;
@property (nonatomic, strong) NSString *defaultTitle;
@property (nonatomic, strong) NSString *refreshText;
@property (nonatomic, strong) NSString *loadingFailedText;
@property (nonatomic, strong) NSString *closeText;
@property (nonatomic, strong) NSString *loadingText;
@property (nonatomic, strong) NSString *surveyEnv;
@property (nonatomic, assign) CGFloat popupWidthRatio;
@property (nonatomic, assign) CGFloat popupHeightRatio;

@property (nonatomic, strong) UIView *popupView;
@property (nonatomic, strong, nullable) UIView *errorView;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;

+ (instancetype)sharedInstance;
- (void)open:(const char *)surveyId withParams:(const char *)params;
- (void)close;

@end

NS_ASSUME_NONNULL_END
