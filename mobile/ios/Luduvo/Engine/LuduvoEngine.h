#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

// Opaque C++ engine implementation (defined in the native engine library).
typedef struct LuduvoEngineImpl LuduvoEngineImpl;

@class MetalRenderer;

// Virtual analog stick (left = movement, right = camera look).
typedef NS_ENUM(NSInteger, LuduvoTouchStick) {
    LuduvoTouchStickMove = 0,
    LuduvoTouchStickLook = 1
};

// On-screen action buttons.
typedef NS_ENUM(NSInteger, LuduvoTouchButton) {
    LuduvoTouchButtonJump = 0,
    LuduvoTouchButtonSprint = 1,
    LuduvoTouchButtonAction = 2,
    LuduvoTouchButtonInventory = 3,
    LuduvoTouchButtonChat = 4
};

// Physical gamepad buttons.
// The case names are spelled out because the Swift importer keeps a
// single-letter remainder (A, B, X, Y) instead of stripping the prefix.
typedef NS_ENUM(NSInteger, LuduvoGamepadButton) {
    LuduvoGamepadButtonCross = 0,
    LuduvoGamepadButtonCircle = 1,
    LuduvoGamepadButtonSquare = 2,
    LuduvoGamepadButtonTriangle = 3
};

// Physical gamepad triggers.
typedef NS_ENUM(NSInteger, LuduvoGamepadTrigger) {
    LuduvoGamepadTriggerLeft = 0,
    LuduvoGamepadTriggerRight = 1
};

@protocol LuduvoEngineDelegate <NSObject>
@optional
- (void)engineDidInitialize:(BOOL)success;
- (void)engineDidReceiveError:(NSError *)error;
- (void)engineDidUpdateFPS:(float)fps;
@end

@interface LuduvoEngine : NSObject

@property (nonatomic, weak) id<LuduvoEngineDelegate> delegate;
@property (nonatomic, strong) MTKView *metalView;
@property (nonatomic, strong) MetalRenderer *renderer;
@property (nonatomic, assign) BOOL isRunning;

+ (void)loadLibrary;

- (instancetype)init;
- (void)startWithConfigPath:(NSString *)configPath NS_SWIFT_NAME(start(configPath:));
- (void)shutdown;
- (void)pause;
- (void)resume;
- (void)tickWithDeltaTime:(float)dt NS_SWIFT_NAME(tick(dt:));
- (void)resizeWithWidth:(NSInteger)width height:(NSInteger)height NS_SWIFT_NAME(resize(width:height:));

// Touch input
- (void)touchDownWithTimestamp:(long long)timestamp touchId:(NSInteger)touchId fingerId:(NSInteger)fingerId x:(float)x y:(float)y pressure:(float)pressure;
- (void)touchMoveWithTimestamp:(long long)timestamp touchId:(NSInteger)touchId fingerId:(NSInteger)fingerId x:(float)x y:(float)y dx:(float)dx dy:(float)dy pressure:(float)pressure;
- (void)touchUpWithTimestamp:(long long)timestamp touchId:(NSInteger)touchId fingerId:(NSInteger)fingerId x:(float)x y:(float)y pressure:(float)pressure;

// Virtual stick input
- (void)moveStick:(NSInteger)stick x:(float)x y:(float)y;
- (void)pressButton:(NSInteger)button pressed:(BOOL)pressed;
- (void)touchStick:(LuduvoTouchStick)stick x:(float)x y:(float)y;
- (void)touchButton:(LuduvoTouchButton)button pressed:(BOOL)pressed;

// Gamepad input
- (void)gamepadDPadX:(float)x y:(float)y NS_SWIFT_NAME(gamepadDPad(x:y:));
- (void)gamepadButton:(LuduvoGamepadButton)button value:(float)value pressed:(BOOL)pressed;
- (void)gamepadTrigger:(LuduvoGamepadTrigger)trigger value:(float)value pressed:(BOOL)pressed;
- (void)gamepadDisconnected;

// Keyboard/text input
- (void)keyDownWithScancode:(int)scancode keycode:(int)keycode modifiers:(int)modifiers;
- (void)keyUpWithScancode:(int)scancode keycode:(int)keycode modifiers:(int)modifiers;
- (void)textInput:(NSString *)text;

// Focus
- (void)focusLost;
- (void)focusGained;

@end

NS_ASSUME_NONNULL_END
