#import "MetalRenderer.h"
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

@interface MetalRenderer ()
@property (nonatomic, strong) MTKView *metalView;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLDepthStencilState> depthStencilState;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) CFTimeInterval lastFrameTime;
@property (nonatomic, assign) NSUInteger frameCount;
@property (nonatomic, assign) float fps;
@end

@implementation MetalRenderer

- (instancetype)initWithMetalView:(MTKView *)view {
    self = [super init];
    if (self) {
        _metalView = view;
        _device = view.device ?: MTLCreateSystemDefaultDevice();
        _commandQueue = [_device newCommandQueue];

        view.delegate = self;
        view.device = _device;
        view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
        view.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        view.sampleCount = 4;
        view.preferredFramesPerSecond = 60;

        [self setupPipeline];
        [self setupDepthStencil];
        [self startFPSCounter];
    }
    return self;
}

- (void)setupPipeline {
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = nil; // Will be set by engine
    desc.fragmentFunction = nil;
    desc.colorAttachments[0].pixelFormat = _metalView.colorPixelFormat;
    desc.depthAttachmentPixelFormat = _metalView.depthStencilPixelFormat;
    desc.sampleCount = _metalView.sampleCount;

    NSError *error = nil;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:desc error:&error];
    if (!_pipelineState) {
        NSLog(@"[MetalRenderer] Failed to create pipeline state: %@", error);
    }
}

- (void)setupDepthStencil {
    MTLDepthStencilDescriptor *desc = [[MTLDepthStencilDescriptor alloc] init];
    desc.depthCompareFunction = MTLCompareFunctionLess;
    desc.isDepthWriteEnabled = YES;
    _depthStencilState = [_device newDepthStencilStateWithDescriptor:desc];
}

- (void)startFPSCounter {
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFPS:)];
    _displayLink.preferredFramesPerSecond = 60;
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    _lastFrameTime = CACurrentMediaTime();
    _frameCount = 0;
}

- (void)updateFPS:(CADisplayLink *)link {
    _frameCount++;
    CFTimeInterval now = link.timestamp;
    if (now - _lastFrameTime >= 1.0) {
        _fps = _frameCount / (now - _lastFrameTime);
        _frameCount = 0;
        _lastFrameTime = now;

        if ([self.delegate respondsToSelector:@selector(renderer:didUpdateFPS:)]) {
            [self.delegate renderer:self didUpdateFPS:_fps];
        }
    }
}

#pragma mark - MTKViewDelegate

- (void)drawInMTKView:(MTKView *)view {
    // The engine renders directly via MoltenVK/Vulkan backend
    // This is a placeholder - the actual rendering happens in the C++ engine
    // which uses MoltenVK to submit to Metal
    [self drawFrame];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    [self resizeWithWidth:(NSInteger)size.width height:(NSInteger)size.height];
}

- (void)drawFrame {
    // Engine renders via MoltenVK - this is a no-op for the Metal view
    // The engine's Vulkan backend (via MoltenVK) will present to the CAMetalLayer
    // We just ensure the drawable is available
    if (_metalView.currentDrawable) {
        // Present handled by engine
    }
}

- (void)resizeWithWidth:(NSInteger)width height:(NSInteger)height {
    _metalView.drawableSize = CGSizeMake(width, height);
    // Engine will handle resize via its own resize callback
}

@end