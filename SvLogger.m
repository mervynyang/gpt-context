#import "SvLogger.h"

@implementation SvLogger

static BOOL logEnabled = NO;

+ (void)enableLog:(BOOL)enable {
    logEnabled = enable;
}

+ (BOOL)isLogEnabled {
    return logEnabled;
}

@end

void EnableLog(bool enable) {
    [SvLogger enableLog:enable];
}
