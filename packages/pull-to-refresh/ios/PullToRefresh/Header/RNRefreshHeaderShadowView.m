#import "RNRefreshHeaderShadowView.h"
#import "RNRefreshHeaderLocalData.h"

#import <Yoga/YGValue.h>

@implementation RNRefreshHeaderShadowView

- (instancetype)init {
    if (self = [super init]) {
        // Header使用相对定位，不设置绝对位置
        self.top = YGValueUndefined;
        self.bottom = YGValueUndefined;
        self.left = YGValueZero;
        self.right = YGValueZero;
        self.position = YGPositionTypeRelative;
    }
    return self;
}

- (void)setLocalData:(RNRefreshHeaderLocalData *)localData {
    // Header使用相对定位，让UI View控制实际位置
    self.top = YGValueUndefined;
    self.bottom = YGValueUndefined;
    self.left = YGValueZero;
    self.right = YGValueZero;
    self.position = YGPositionTypeRelative;
}

@end
