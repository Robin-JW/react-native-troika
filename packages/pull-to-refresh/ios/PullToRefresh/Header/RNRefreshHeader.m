#import "RNRefreshHeader.h"
#import "RNRefreshState.h"
#import "RNRefreshingEvent.h"
#import "RNRefreshOffsetChangedEvent.h"
#import "RNRefreshStateChangedEvent.h"
#import "RNRefreshHeaderLocalData.h"

#import <React/RCTRefreshableProtocol.h>
#import <React/UIView+React.h>
#import <React/RCTRootContentView.h>
#import <React/RCTTouchHandler.h>
#import <React/RCTUIManager.h>
#import <React/RCTLog.h>

@interface RNRefreshHeader () <RCTRefreshableProtocol>

@property(nonatomic, assign) RNRefreshState state;
@property(nonatomic, assign) CGFloat topInset;
@property(nonatomic, weak) RCTBridge *bridge;

@end

@implementation RNRefreshHeader {
    BOOL _isInitialRender;
    BOOL _hasObserver;
    __weak RCTRootContentView *_rootView;
}

- (instancetype)initWithBridge:(RCTBridge *)bridge {
    if (self = [super init]) {
        _isInitialRender = YES;
        _hasObserver = NO;
        _state = RNRefreshStateIdle;
        _bridge = bridge;
        
        // 移除初始化时的隐藏设置，保持与Footer一致
        // self.hidden = YES;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // 设置Header的frame位置，确保默认状态下完全隐藏（与Footer逻辑一致）
    if (self.scrollView && self.state != RNRefreshStateRefreshing) {
        CGRect frame = self.frame;
        // 非刷新状态时，隐藏在ScrollView内容顶部之上
        frame.origin.y = -frame.size.height;
        [super setFrame:frame];
    }
    
    [self setLocalData];
    
    if (self.backgroundColor == nil) {
        self.backgroundColor = [UIColor clearColor];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.state == RNRefreshStateRefreshing && self->_isInitialRender) {
            [self settleToRefreshing];
        }
        self->_isInitialRender = NO;
    });
}

- (void)reactSetFrame:(CGRect)frame {
    [super reactSetFrame:frame];
    [self setLocalData];
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    [self setLocalData];
}

- (void)setLocalData {
    if (self.scrollView && self.frame.size.height != 0) {
        if (self.frame.origin.y != -self.frame.size.height) {
            RNRefreshHeaderLocalData *localData = [[RNRefreshHeaderLocalData alloc] initWithHeaderHeight:self.frame.size.height];
            [self.bridge.uiManager setLocalData:localData forView:self];
        }
    }
}

- (void)setScrollView:(UIScrollView *)scrollView {
    [self removeObserver];
    _scrollView = scrollView;
    [self addObserver];
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    [super willMoveToWindow:newWindow];
    if (newWindow) {
        [self addObserver];
    } else {
        [self removeObserver];
    }
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) {
        [self cacheRootView];
    }
}

- (void)addObserver {
    if (!_hasObserver && self.scrollView) {
        NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld;
        [self.scrollView addObserver:self forKeyPath:@"contentOffset" options:options context:nil];
        _hasObserver = YES;
    }
}

- (void)removeObserver {
    if (_hasObserver && self.scrollView) {
        [self.scrollView removeObserver:self forKeyPath:@"contentOffset" context:nil];
        _hasObserver = NO;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"contentOffset"]) {
        CGFloat offsetY = self.scrollView.contentOffset.y;
        CGFloat insetT = -self.scrollView.contentInset.top;
        
        if (fabs(offsetY) > 0) {
            if (self.onOffsetChanged) {
                self.onOffsetChanged(@{@"offset": @(fabs(offsetY))});
            }
        }
        
        if (self.state == RNRefreshStateRefreshing) {
            return;
        }
        
        if (offsetY > insetT) {
            return;
        }
        
        CGFloat range = self.scrollView.contentInset.top + self.bounds.size.height;
        
        if (self.scrollView.isDragging) {
            [self cancelRootViewTouches];
            // 拖拽过程中：只要向下（offsetY <= insetT），就显示Header；否则隐藏
            self.hidden = !(offsetY <= insetT);
            
            if (self.state == RNRefreshStateIdle && fabs(offsetY) >= range) {
                self.state = RNRefreshStateComing;
            } else if (self.state == RNRefreshStateComing && fabs(offsetY) <= range) {
                // 回退到未达临界，但仍在负offset范围内，保持显示由上面逻辑决定
                self.state = RNRefreshStateIdle;
            }
            return;
        }
        
        if (self.state == RNRefreshStateComing) {
            // 松开手
            [self beginRefreshing];
            return;
        }
    }
}

@dynamic refreshing;

- (BOOL)isRefreshing {
    return self.state == RNRefreshStateRefreshing;
}

- (void)setRefreshing:(BOOL)refreshing {
    if (refreshing) {
        [self beginRefreshing];
    } else {
        [self endRefreshing];
    }
}

- (void)beginRefreshing {
    [self setState:RNRefreshStateRefreshing];
}

- (void)endRefreshing {
    [self setState:RNRefreshStateIdle];
}

- (void)setState:(RNRefreshState)state {
    if (_isInitialRender) {
        _state = state;
        return;
    }
    
    if (_state == state || !self.scrollView) {
        return;
    }
    
    RNRefreshState old = _state;
    _state = state;

    if (state == RNRefreshStateIdle && old == RNRefreshStateRefreshing) {
        [self settleToIdle];
        return;
    }
    
    if (state == RNRefreshStateRefreshing) {
        [self settleToRefreshing];
        return;
    }
    
    // 显隐改由offset观察者管理，避免在阈值回退时立刻隐藏
    // 状态只负责触发刷新与事件回调
    
    RCTLogInfo(@"[pull-to-refresh] publish comming event");
    if (self.onStateChanged) {
        self.onStateChanged(@{@"state": @(state)});
    }
}

- (void)settleToRefreshing {
    RCTLogInfo(@"[pull-to-refresh] settleToRefreshing");
    [self animateToRefreshingState:^(BOOL finished) {
        if (self.state == RNRefreshStateRefreshing) {
            RCTLogInfo(@"[pull-to-refresh] publish refresh event");
            if (self.onStateChanged) {
        self.onStateChanged(@{@"state": @(RNRefreshStateRefreshing)});
    }
    if (self.onRefresh) {
        self.onRefresh(@{});
    }
        }
    }];
}

- (void)settleToIdle {
    RCTLogInfo(@"[pull-to-refresh] settleToIdle");
    [self animateToIdleState:^(BOOL finished) {
        if (self.state == RNRefreshStateIdle) {
            RCTLogInfo(@"[pull-to-refresh] publish idle event");
            if (self.onStateChanged) {
        self.onStateChanged(@{@"state": @(RNRefreshStateIdle)});
    }
        }
    }];
}

- (void)animateToIdleState:(void (^ __nullable)(BOOL finished))completion {
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        UIScrollView *scrollView = self.scrollView;
        UIEdgeInsets insets = scrollView.contentInset;
        scrollView.contentInset = UIEdgeInsetsMake(self.topInset, insets.left, insets.bottom, insets.right);
    } completion:^(BOOL finished) {
        // 回到空闲后，强制将Header移出可视区并隐藏，避免遮挡列表
        CGRect frame = self.frame;
        frame.origin.y = -frame.size.height;
        [super setFrame:frame];
        self.hidden = YES;
        if (completion) { completion(finished); }
    }];
}

- (void)animateToRefreshingState:(void (^ __nullable)(BOOL finished))completion {
    // 移除hidden控制，保持与Footer一致
    // self.hidden = NO;
    [UIView animateWithDuration:0.2 animations:^{
        UIScrollView *scrollView = self.scrollView;
        CGFloat range = scrollView.contentInset.top + self.bounds.size.height;
        UIEdgeInsets insets = scrollView.contentInset;
        self.topInset = insets.top;
        [scrollView setContentInset:UIEdgeInsetsMake(range, insets.left, insets.bottom, insets.right)];
        CGPoint offset = {scrollView.contentOffset.x, -range};
        [scrollView setContentOffset:offset animated:NO];
    } completion:completion];
}

- (void)cacheRootView {
  UIView *rootView = self;
  while (rootView.superview && ![rootView isReactRootView]) {
    rootView = rootView.superview;
  }
  _rootView = (RCTRootContentView *)rootView;
}

- (void)cancelRootViewTouches {
    RCTRootContentView *rootView = (RCTRootContentView *)_rootView;
    
    // Check if the rootView responds to touchHandler before calling it
    if ([rootView respondsToSelector:@selector(touchHandler)]) {
        RCTTouchHandler *touchHandler = [rootView performSelector:@selector(touchHandler)];
        if (touchHandler && [touchHandler respondsToSelector:@selector(cancel)]) {
            [touchHandler cancel];
        }
    }
}

@end
