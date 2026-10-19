#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

// Forward declare C++ engine
class LuduvoEngineImpl;

@protocol LuduvoEngineDelegate <NSObject>
@optional
- (void)engineDidInitialize:(BOOL)success;
- (void)engineDidReceiveError:(NSError *)error;
- (void)engineDidUpdateFPS:(float)fps;
@end

@interface LuduvoEngine : NSObject

@property (nonatomic, weak) id<LuduvoEngineDelegate> delegate;
@property (nonatomic, strong) MTKView *metalView;
@property (nonatomic, assign) BOOL isRunning;

+ (void)loadLibrary;

- (instancetype)init;
- (void)startWithConfigPath:(NSString *)configPath;
- (void)shutdown;
- (void)pause;
- (void)resume;
- (void)tickWithDeltaTime:(float)dt;
- (void)resizeWithWidth:(NSInteger)width height:(NSInteger)height;

// Touch input
- (void)touchDownWithTimestamp:(long long)timestamp touchId:(NSInteger)touchId fingerId:(NSInteger)fingerId x:(float)x y:(float)y pressure:(float)pressure;
- (void)touchMoveWithTimestamp:(long long)timestamp touchId:(NSInteger)touchId fingerId:(NSInteger)fingerId x:(float)x y:(float)y dx:(float)dx dy:(float)dy pressure:(float)pressure;
- (void)touchUpWithTimestamp:(long long)timestamp touchId:(NSInteger)touchId fingerId:(NSInteger)fingerId x:(float)x y:(float)y pressure:(float)pressure;

// Virtual stick input
- (void)moveStick:(NSInteger)stick x:(float)x y:(float)y; // 0=move, 1=look
- (void)pressButton:(NSInteger)button pressed:(BOOL)pressed; // 0=jump, 1=sprint, 2=action, 3=inventory, 4=chat

// Gamepad input
- (void)gamepadDPadX:(float)x y:(float)y;
- (void)gamepadButton:(NSInteger)button value:(float)value pressed:(BOOL)pressed; // 0=A, 1=B, 2=X, 3=Y
- (void)gamepadTrigger:(NSInteger)trigger value:(float)value; // 0=left, 1=right
- (void)gamepadDisconnected;

// Keyboard/text input
- (void)keyDownWithScancode:(NSInteger)scancode keycode:(NSInteger)keycode modifiers:(NSInteger)modifiers;
- (void)keyUpWithScancode:(NSInteger)scancode keycode:(NSInteger)keycode modifiers:(NSInteger)modifiers;
- (void)textInput:(NSString *)text;

// Focus
- (void)focusLost;
- (void)focusGained;

@end

NS_ASSUME_NONNULL_END