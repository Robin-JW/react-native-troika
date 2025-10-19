#import "RNRefreshHeaderShadowView.h"
#import "RNRefreshHeaderLocalData.h"

#import <Yoga/YGValue.h>

@implementation RNRefreshHeaderShadowView

- (instancetype)init {
    if (self = [super init]) {
        // Header不应占据布局空间，使用绝对定位并移出屏幕上方
        self.top = (YGValue){-10000, YGUnitPoint};
        self.bottom = YGValueUndefined;
        self.left = YGValueZero;
        self.right = YGValueZero;
        self.position = YGPositionTypeAbsolute;
    }
    return self;
}

- (void)setLocalData:(RNRefreshHeaderLocalData *)localData {
    // 保持绝对定位，避免占位导致顶部空白
    self.top = (YGValue){-10000, YGUnitPoint};
    self.bottom = YGValueUndefined;
    self.left = YGValueZero;
    self.right = YGValueZero;
    self.position = YGPositionTypeAbsolute;
}

@end
