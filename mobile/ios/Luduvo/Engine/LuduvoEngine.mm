#import "LuduvoEngine.h"
#import <SDL3/SDL.h>
#import <dlfcn.h>
#import <mach/mach_time.h>

// C++ engine interface (from decompiled source)
extern "C" {
    int  ldv_engine_init(const char* config_path);
    void ldv_engine_shutdown();
    void ldv_engine_tick(float dt);
    void ldv_engine_resize(int width, int height);

    void ldv_input_finger_down(uint64_t timestamp, int touch_id, int finger_id, float x, float y, float pressure);
    void ldv_input_finger_motion(uint64_t timestamp, int touch_id, int finger_id, float x, float y, float dx, float dy, float pressure);
    void ldv_input_finger_up(uint64_t timestamp, int touch_id, int finger_id, float x, float y, float pressure);

    void ldv_input_gamepad_touchpad_down(uint64_t timestamp, int touchpad, int finger, float x, float y, float pressure);
    void ldv_input_gamepad_touchpad_motion(uint64_t timestamp, int touchpad, int finger, float x, float y, float pressure);
    void ldv_input_gamepad_touchpad_up(uint64_t timestamp, int touchpad, int finger, float x, float y, float pressure);

    void ldv_input_key_down(int scancode, int keycode, int modifiers);
    void ldv_input_key_up(int scancode, int keycode, int modifiers);
    void ldv_input_text(const char* text);

    void ldv_input_focus_lost();
    void ldv_input_focus_gained();
}

@implementation LuduvoEngine {
    LuduvoEngineImpl* _impl;
    uint64_t _lastFrameTime;
    dispatch_queue_t _engineQueue;
    BOOL _paused;
}

+ (void)loadLibrary {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Load the native engine library
        // In production, this would be @rpath/libluduvo.dylib
        void* handle = dlopen("libluduvo.dylib", RTLD_LAZY | RTLD_LOCAL);
        if (!handle) {
            handle = dlopen("@rpath/libluduvo.dylib", RTLD_LAZY | RTLD_LOCAL);
        }
        if (!handle) {
            handle = dlopen("/usr/local/lib/libluduvo.dylib", RTLD_LAZY | RTLD_LOCAL);
        }
        if (!handle) {
            NSLog(@"[LuduvoEngine] Warning: Could not load libluduvo.dylib: %s", dlerror());
        } else {
            NSLog(@"[LuduvoEngine] Native library loaded");
        }
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
        const char* path = [configPath UTF8String];
        int result = ldv_engine_init(path);

        BOOL success = (result == 0);
        if (success) {
            NSLog(@"[LuduvoEngine] Engine initialized successfully");
        } else {
            NSLog(@"[LuduvoEngine] Engine init failed: %d", result);
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(engineDidInitialize:)]) {
                [self.delegate engineDidInitialize:success];
            }
        });
    });
}

- (void)shutdown {
    dispatch_async(_engineQueue, ^{
        ldv_engine_shutdown();
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
        ldv_engine_resize(width, height);
    });
}

- (void)touchDownWithTimestamp:(long long)timestamp touchId:(NSInteger)touchId fingerId:(NSInteger)fingerId x:(float)x y:(float)y pressure:(float)pressure {
    dispatch_async(_engineQueue, ^{
        ldv_input_finger_down((uint64_t)timestamp, touchId, fingerId, x, y, pressure);
    });
}

- (void)touchMoveWithTimestamp:(long long)timestamp touchId:(NSInteger)touchId fingerId:(NSInteger)fingerId x:(float)x y:(float)y dx:(float)dx dy:(float)dy pressure:(float)pressure {
    dispatch_async(_engineQueue, ^{
        ldv_input_finger_motion((uint64_t)timestamp, touchId, fingerId, x, y, dx, dy, pressure);
    });
}

- (void)touchUpWithTimestamp:(long long)timestamp touchId:(NSInteger)touchId fingerId:(NSInteger)fingerId x:(float)x y:(float)y pressure:(float)pressure {
    dispatch_async(_engineQueue, ^{
        ldv_input_finger_up((uint64_t)timestamp, touchId, fingerId, x, y, pressure);
    });
}

- (void)moveStick:(NSInteger)stick x:(float)x y:(float)y {
    // Convert stick movement to synthetic touch/finger events
    // Left stick (0) = movement, Right stick (1) = look
    // This is handled by the engine's internal input system
    // For now, we forward as synthetic touch events on a virtual touchpad
    // The engine expects SDL_EVENT_FINGER_* format
}

- (void)pressButton:(NSInteger)button pressed:(BOOL)pressed {
    // Map buttons to engine actions
    // 0=jump, 1=sprint, 2=action, 3=inventory, 4=chat
    // These would map to SDL keycodes or custom engine actions
}

- (void)gamepadDPadX:(float)x y:(float)y {
    // Convert to synthetic stick input
}

- (void)gamepadButton:(NSInteger)button value:(float)value pressed:(BOOL)pressed {
    // Map gamepad buttons to engine actions
}

- (void)gamepadTrigger:(NSInteger)trigger value:(float)value {
    // Map triggers
}

- (void)gamepadDisconnected {
    // Handle disconnect
}

- (void)keyDownWithScancode:(NSInteger)scancode keycode:(NSInteger)keycode modifiers:(NSInteger)modifiers {
    dispatch_async(_engineQueue, ^{
        ldv_input_key_down((int)scancode, (int)keycode, (int)modifiers);
    });
}

- (void)keyUpWithScancode:(NSInteger)scancode keycode:(NSInteger)keycode modifiers:(NSInteger)modifiers {
    dispatch_async(_engineQueue, ^{
        ldv_input_key_up((int)scancode, (int)keycode, (int)modifiers);
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