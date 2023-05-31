#import "SurveyPopupView.h"

@interface SurveyPopupView ()

@property (nonatomic, weak) WKUserContentController *userContentController;

@end

@implementation SurveyPopupView

static SurveyPopupView *_sharedInstance;

+ (SurveyPopupView *)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[SurveyPopupView alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.primaryBgColor = [UIColor whiteColor];
        self.defaultTitle = @"MUR Survey";
        self.refreshText = @"刷新";
        self.closeText = @"关闭";
        self.loadingFailedText = @"问卷内容加载失败";
        self.loadingText = @"内容加载中...";
        self.surveyEnv = @"production";
        self.popupWidthRatio = 0.8;
        self.popupHeightRatio = 0.8;

        [self initPupupView];
        [self initWebview:self.popupView];
    }
    return self;
}

- (void)setSurveyPopupConfig:(NSString *)configJson {
    NSData *data = [configJson dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError = nil;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];

    if (jsonError) {
        SvLog(@"setSurveyPopupConfig JSON Parsing Error: %@", jsonError);
        return;
    }

    if (jsonDict[@"primaryBgColor"]) {
        self.primaryBgColor = [self parseRgbaString:jsonDict[@"primaryBgColor"]];
    }
    if (jsonDict[@"defaultTitle"]) {
        self.defaultTitle = jsonDict[@"defaultTitle"];
    }
    if (jsonDict[@"loadingFailedText"]) {
        self.loadingFailedText = jsonDict[@"loadingFailedText"];
    }
    if (jsonDict[@"refreshText"]) {
        self.refreshText = jsonDict[@"refreshText"];
    }
    if (jsonDict[@"closeText"]) {
        self.closeText = jsonDict[@"closeText"];
    }
    if (jsonDict[@"loadingText"]) {
        self.loadingText = jsonDict[@"loadingText"];
    }
    if (jsonDict[@"surveyEnv"]) {
        self.surveyEnv = jsonDict[@"surveyEnv"];
    }
    if (jsonDict[@"popupWidthRatio"]) {
        self.popupWidthRatio = [jsonDict[@"popupWidthRatio"] floatValue];
    }
    if (jsonDict[@"popupHeightRatio"]) {
        self.popupHeightRatio = [jsonDict[@"popupHeightRatio"] floatValue];
    }
}

- (UIColor *)parseRgbaString:(NSString *)rgbaString {
    NSArray *components = [rgbaString componentsSeparatedByString:@","];

    if (components.count == 4) {
        CGFloat red = [components[0] floatValue] / 255.0;
        CGFloat green = [components[1] floatValue] / 255.0;
        CGFloat blue = [components[2] floatValue] / 255.0;
        CGFloat alpha = [components[3] floatValue];

        return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
    }
    return [UIColor whiteColor];
}

- (void)open:(const char *)surveyId withParams:(const char *)params {
    NSString *nsparams = [NSString stringWithUTF8String:params];
    NSString *encodedParams = [nsparams stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *prefix =
        [self.surveyEnv isEqualToString:@"production"] ? @"https://in.weisurvey.com/ingame/?sid=" : @"https://test.a.imur.tencent.com/ingame/?sid=";
    NSString *nsSurveyId = [NSString stringWithUTF8String:surveyId];

    // If the params string starts with '?', replace it with '&'
    // If the params string starts with letter (not '&' or '?'), prepend it with
    // '&'
    if ([encodedParams hasPrefix:@"?"]) {
        encodedParams = [@"&" stringByAppendingString:[encodedParams substringFromIndex:1]];
    } else if (![encodedParams hasPrefix:@"&"]) {
        encodedParams = [@"&" stringByAppendingString:encodedParams];
    }

    NSString *urlString = [NSString stringWithFormat:@"%@%@%@", prefix, nsSurveyId, encodedParams];
    NSURL *urlObject = [NSURL URLWithString:urlString];
    if (!urlObject) {
        SvLog(@"Invalid URL: %@", urlString);
        return;
    }

    [self.popupView addSubview:self.activityIndicatorView];
    [self.popupView addSubview:self.webView];
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    [window addSubview:self.popupView];
    [self.webView loadRequest:[NSURLRequest requestWithURL:urlObject]];
}

- (void)close {
    [self.popupView removeFromSuperview];
}

- (void)closeErrorView {
    if (self.errorView) {
        [self.errorView removeFromSuperview];
        self.errorView = nil;
    }
}

- (void)reload {
    [self.webView reload];
}

- (void)initPupupView {
    CGFloat width = [[UIScreen mainScreen] bounds].size.width * _popupWidthRatio;
    CGFloat height = [[UIScreen mainScreen] bounds].size.height * _popupHeightRatio;
    self.popupView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    self.popupView.center = CGPointMake([UIScreen mainScreen].bounds.size.width / 2, [UIScreen mainScreen].bounds.size.height / 2);

    self.activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.activityIndicatorView.center = CGPointMake(CGRectGetMidX(self.popupView.bounds), CGRectGetMidY(self.popupView.bounds));
    SvLog(@"PupupView initialized, width: %.2f, height: %.2f, popupWidthRatio: "
          @"%.2f, popupHeightRatio: %.2f",
        width, height, _popupWidthRatio, _popupHeightRatio);
}

- (void)initWebview:(UIView *)pupupView {
    // 配置与 JS 交互的对象
    WKUserContentController *userContentController = [[WKUserContentController alloc] init];
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.userContentController = userContentController;

    // 注册要供 JS 调用的方法
    [configuration.userContentController addScriptMessageHandler:self name:@"ImurSurveyBridge"];
    self.userContentController = userContentController;

    // 创建 WKWebView
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    self.webView.navigationDelegate = self;

    // 将 WKWebView 的背景色和 opaque 属性都设置为 clearColor 和 NO
    self.webView.backgroundColor = [UIColor clearColor];
    self.webView.opaque = NO;
    self.webView.scrollView.backgroundColor = [UIColor clearColor];
    self.webView.scrollView.scrollEnabled = NO;
    self.webView.frame = pupupView.bounds;
    SvLog(@"Webview initialized");
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    self.activityIndicatorView.center = CGPointMake(self.popupView.bounds.size.width / 2, self.popupView.bounds.size.height / 2);
    self.popupView.backgroundColor = self.primaryBgColor;
    [self.activityIndicatorView startAnimating];
    [self closeErrorView];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.popupView.backgroundColor = [UIColor clearColor];
    [self.activityIndicatorView stopAnimating];
    SvLog(@"webView didFinishNavigation, currentURL: %@", webView.URL.absoluteString);
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    SvLog(@"didFailProvisionalNavigation error: %@", [error localizedDescription]);
    [self handleWebViewLoadError:error];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    SvLog(@"didFailNavigation error: %@", [error localizedDescription]);
    [self handleWebViewLoadError:error];
}

- (void)handleWebViewLoadError:(NSError *)error {
    // 自定义错误处理
    SvLog(@"WebView Load error: %@", error);
    [self.activityIndicatorView stopAnimating];

    // 创建一个新的UIView
    UIView *errorView = [[UIView alloc] initWithFrame:self.popupView.bounds];
    errorView.backgroundColor = [UIColor whiteColor];

    // 创建一个UILabel
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, errorView.bounds.size.width, 36)];
    titleLabel.text = self.defaultTitle;
    titleLabel.font = [UIFont systemFontOfSize:20];
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [errorView addSubview:titleLabel];

    // 创建一个UIImageView
    UIImageView *imageView =
        [[UIImageView alloc] initWithFrame:CGRectMake((errorView.bounds.size.width - 120) / 2, titleLabel.frame.size.height + 30, 120, 120)];
    NSBundle *frameworkBundle = [NSBundle bundleForClass:[SurveyPopupView class]];
    NSString *imagePath = [frameworkBundle pathForResource:@"no-data" ofType:@"png"];
    UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
    imageView.image = image;
    [errorView addSubview:imageView];

    // 创建一个UILabel，显示加载失败文案
    UILabel *contentLabel =
        [[UILabel alloc] initWithFrame:CGRectMake(0, imageView.frame.origin.y + imageView.frame.size.height, errorView.bounds.size.width, 36)];
    contentLabel.text = self.loadingFailedText;
    contentLabel.font = [UIFont systemFontOfSize:18];
    contentLabel.textColor = [UIColor grayColor];
    contentLabel.textAlignment = NSTextAlignmentCenter;
    [errorView addSubview:contentLabel];

    // 创建两个UIButton
    UIGraphicsBeginImageContext(CGSizeMake(1, 1));
    [[UIColor colorWithRed:34 / 255.0 green:187 / 255.0 blue:130 / 255.0 alpha:1.0] set];
    UIRectFill(CGRectMake(0, 0, 1, 1));
    UIImage *colorImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    UIButton *closeButton = [[UIButton alloc] initWithFrame:CGRectMake((errorView.bounds.size.width - 220) / 2,
                                                                contentLabel.frame.origin.y + contentLabel.frame.size.height + 24, 110, 32)];
    [closeButton setTitle:self.closeText forState:UIControlStateNormal];
    closeButton.backgroundColor = [UIColor colorWithRed:36 / 255.0 green:198 / 255.0 blue:138 / 255.0 alpha:1.0];
    [closeButton setBackgroundImage:colorImage forState:UIControlStateHighlighted];
    [closeButton addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [errorView addSubview:closeButton];

    UIButton *refreshButton = [[UIButton alloc]
        initWithFrame:CGRectMake(closeButton.frame.origin.x + closeButton.frame.size.width + 20, closeButton.frame.origin.y, 110, 32)];
    [refreshButton setTitle:self.refreshText forState:UIControlStateNormal];
    refreshButton.backgroundColor = [UIColor colorWithRed:36 / 255.0 green:198 / 255.0 blue:138 / 255.0 alpha:1.0];
    [refreshButton setBackgroundImage:colorImage forState:UIControlStateHighlighted];
    [refreshButton addTarget:self action:@selector(reload) forControlEvents:UIControlEventTouchUpInside];
    [errorView addSubview:refreshButton];

    self.errorView = errorView;
    [self.popupView addSubview:self.errorView];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"ImurSurveyBridge"]) {
        NSString *command = message.body;
        if ([command isEqualToString:@"closeWebView"]) {
            [self close];
        }
    }
}

@end

#ifdef __cplusplus
extern "C" {
#endif
void _OpenSurvey(const char *surveyId, const char *params) {
    [[SurveyPopupView sharedInstance] open:surveyId withParams:params];
}

void _CloseSurvey(void) {
    [[SurveyPopupView sharedInstance] close];
}

void _SetSurveyPopupConfig(const char *configJson) {
    NSString *configJsonStr = [NSString stringWithUTF8String:configJson];
    [[SurveyPopupView sharedInstance] setSurveyPopupConfig:configJsonStr];
}
#ifdef __cplusplus
}
#endif
