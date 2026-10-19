#import "MetalRenderer.h"
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

@interface MetalRenderer ()
@property (nonatomic, strong) MTKView *metalView;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) MTLDepthStencilState *depthStencilState;
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
        view.sampleCount = 1;
        view.preferredFramesPerSecond = 60;

        [self setupPipeline];
        [self setupDepthStencil];
        [self startFPSCounter];
    }
    return self;
}

- (void)setupPipeline {
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];

    // Load the compiled shader from the default library.
    id<MTLLibrary> library = [_device newDefaultLibrary];
    if (!library) {
        NSLog(@"[MetalRenderer] No default Metal library - skipping pipeline");
        return;
    }

    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"ldv_shell_vertex"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"ldv_shell_fragment"];

    if (!vertexFunction || !fragmentFunction) {
        NSLog(@"[MetalRenderer] Shader functions missing - skipping pipeline");
        return;
    }

    desc.vertexFunction = vertexFunction;
    desc.fragmentFunction = fragmentFunction;
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
    // The engine renders directly via MoltenVK/Vulkan backend when the native
    // engine library is present. Without it we draw the shell gradient so the
    // client is visibly alive.
    [self drawFrame];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    [self resizeWithWidth:(NSInteger)size.width height:(NSInteger)size.height];
}

- (void)drawFrame {
    if (!_pipelineState) {
        return;
    }

    MTLRenderPassDescriptor *renderPassDescriptor = _metalView.currentRenderPassDescriptor;
    if (!renderPassDescriptor) {
        return;
    }

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];

    [encoder setRenderPipelineState:_pipelineState];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [encoder endEncoding];

    [commandBuffer presentDrawable:_metalView.currentDrawable];
    [commandBuffer commit];
}

- (void)resizeWithWidth:(NSInteger)width height:(NSInteger)height {
    _metalView.drawableSize = CGSizeMake(width, height);
    // Engine will handle resize via its own resize callback
}

@end
