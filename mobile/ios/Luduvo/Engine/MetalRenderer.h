#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MetalRendererDelegate <NSObject>
@optional
- (void)renderer:(id)renderer didUpdateFPS:(float)fps;
@end

@interface MetalRenderer : NSObject <MTKViewDelegate>

@property (nonatomic, weak) id<MetalRendererDelegate> delegate;
@property (nonatomic, readonly) MTKView *metalView;
@property (nonatomic, readonly) id<MTLDevice> device;
@property (nonatomic, readonly) id<MTLCommandQueue> commandQueue;
@property (nonatomic, assign) float fps;

- (instancetype)initWithMetalView:(MTKView *)view;
- (void)drawFrame;
- (void)resizeWithWidth:(NSInteger)width height:(NSInteger)height;

@end

NS_ASSUME_NONNULL_END