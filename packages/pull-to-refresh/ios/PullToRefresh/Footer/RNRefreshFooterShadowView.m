#import "RNRefreshFooterShadowView.h"
#import "RNRefreshFooterLocalData.h"

@implementation RNRefreshFooterShadowView

- (instancetype)init {
    if (self = [super init]) {
        // Footer应该初始化时就隐藏在屏幕下方
        self.top = (YGValue){10000, YGUnitPoint};
        self.bottom = YGValueUndefined;
        self.left = YGValueZero;
        self.right = YGValueZero;
        self.position = YGPositionTypeAbsolute;
    }
    return self;
}

- (void)setLocalData:(RNRefreshFooterLocalData *)localData {
    // Footer应该始终隐藏在屏幕下方，不要根据内容大小调整位置
    self.top = (YGValue){10000, YGUnitPoint};
    self.bottom = YGValueUndefined;
    self.left = YGValueZero;
    self.right = YGValueZero;
    self.position = YGPositionTypeAbsolute;
}

@end
