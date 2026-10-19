#import "LuduvoEngine.h"
#import "luduvo_engine_api.h"
#import <mach/mach_time.h>

@implementation LuduvoEngine {
    uint64_t _lastFrameTime;
    dispatch_queue_t _engineQueue;
    BOOL _paused;
}

+ (void)loadLibrary {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ldv_engine_load_library();
    });
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _engineQueue = dispatch_queue_create("com.luduvo.engine", DISPATCH_QUEUE_SERIAL);
        _lastFrameTime = mach_absolute_time();
        _paused = NO;
    }
    return self;
}

- (void)startWithConfigPath:(NSString *)configPath {
    dispatch_async(_engineQueue, ^{
        const char *path = [configPath UTF8String];
        int result = ldv_engine_init(path);

        BOOL success = (result == 0);
        if (success) {
            NSLog(@"[LuduvoEngine] Engine initialized successfully");
        } else {
            NSLog(@"[LuduvoEngine] Engine init failed: %d", result);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.isRunning = success;
            if ([self.delegate respondsToSelector:@selector(engineDidInitialize:)]) {
                [self.delegate engineDidInitialize:success];
            }
        });
    });
}

- (void)shutdown {
    dispatch_async(_engineQueue, ^{
        ldv_engine_shutdown();
        self.isRunning = NO;
        NSLog(@"[LuduvoEngine] Engine shut down");
    });
}

- (void)pause {
    _paused = YES;
}

- (void)resume {
    _paused = NO;
    _lastFrameTime = mach_absolute_time();
}

- (void)tickWithDeltaTime:(float)dt {
    if (_paused) return;
    dispatch_async(_engineQueue, ^{
        ldv_engine_tick(dt);
    });
}

- (void)resizeWithWidth:(NSInteger)width height:(NSInteger)height {
    dispatch_async(_engineQueue, ^{
        ldv_engine_resize((int)width, (int)height);
    });
}

- (void)touchDownWithTimestamp:(long long)timestamp touchId:(NSInteger)touchId fingerId:(NSInteger)fingerId x:(float)x y:(float)y pressure:(float)pressure {
    dispatch_async(_engineQueue, ^{
        ldv_input_finger_down((uint64_t)timestamp, (int)touchId, (int)fingerId, x, y, pressure);
    });
}

- (void)touchMoveWithTimestamp:(long long)timestamp touchId:(NSInteger)touchId fingerId:(NSInteger)fingerId x:(float)x y:(float)y dx:(float)dx dy:(float)dy pressure:(float)pressure {
    dispatch_async(_engineQueue, ^{
        ldv_input_finger_motion((uint64_t)timestamp, (int)touchId, (int)fingerId, x, y, dx, dy, pressure);
    });
}

- (void)touchUpWithTimestamp:(long long)timestamp touchId:(NSInteger)touchId fingerId:(NSInteger)fingerId x:(float)x y:(float)y pressure:(float)pressure {
    dispatch_async(_engineQueue, ^{
        ldv_input_finger_up((uint64_t)timestamp, (int)touchId, (int)fingerId, x, y, pressure);
    });
}

- (void)moveStick:(NSInteger)stick x:(float)x y:(float)y {
    // Synthetic stick state is forwarded as a virtual touchpad axis.
    uint32_t touchpad = (uint32_t)stick;
    dispatch_async(_engineQueue, ^{
        ldv_input_gamepad_touchpad_motion(touchpad, 0, 0, x, y, 0.0f, 0.0f, 0.0f);
    });
}

- (void)pressButton:(NSInteger)button pressed:(BOOL)pressed {
    // The engine maps button indices to jump/sprint/action/inventory/chat.
    if (pressed) {
        ldv_input_gamepad_touchpad_down(0, 0, (uint32_t)button, 0.0f, 0.0f, 1.0f);
    } else {
        ldv_input_gamepad_touchpad_up(0, 0, (uint32_t)button, 0.0f, 0.0f, 0.0f);
    }
}

- (void)touchStick:(LuduvoTouchStick)stick x:(float)x y:(float)y {
    [self moveStick:(NSInteger)stick x:x y:y];
}

- (void)touchButton:(LuduvoTouchButton)button pressed:(BOOL)pressed {
    [self pressButton:(NSInteger)button pressed:pressed];
}

- (void)gamepadDPadX:(float)x y:(float)y {
    // D-pad is forwarded as the movement stick.
    dispatch_async(_engineQueue, ^{
        ldv_input_gamepad_touchpad_motion(0, 0, 0, x, y, 0.0f, 0.0f, 0.0f);
    });
}

- (void)gamepadButton:(LuduvoGamepadButton)button value:(float)value pressed:(BOOL)pressed {
    [self pressButton:(NSInteger)button pressed:pressed];
}

- (void)gamepadTrigger:(LuduvoGamepadTrigger)trigger value:(float)value pressed:(BOOL)pressed {
    if (pressed) {
        ldv_input_gamepad_touchpad_down((uint32_t)trigger, 0, 0, value, 0.0f, value);
    } else {
        ldv_input_gamepad_touchpad_up((uint32_t)trigger, 0, 0, value, 0.0f, 0.0f);
    }
}

- (void)gamepadDisconnected {
    NSLog(@"[LuduvoEngine] Gamepad disconnected");
}

- (void)keyDownWithScancode:(int)scancode keycode:(int)keycode modifiers:(int)modifiers {
    dispatch_async(_engineQueue, ^{
        ldv_input_key_down(scancode, keycode, modifiers);
    });
}

- (void)keyUpWithScancode:(int)scancode keycode:(int)keycode modifiers:(int)modifiers {
    dispatch_async(_engineQueue, ^{
        ldv_input_key_up(scancode, keycode, modifiers);
    });
}

- (void)textInput:(NSString *)text {
    dispatch_async(_engineQueue, ^{
        ldv_input_text([text UTF8String]);
    });
}

- (void)focusLost {
    dispatch_async(_engineQueue, ^{
        ldv_input_focus_lost();
    });
}

- (void)focusGained {
    dispatch_async(_engineQueue, ^{
        ldv_input_focus_gained();
    });
}

@end
