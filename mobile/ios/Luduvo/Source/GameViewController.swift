import UIKit
import MetalKit
import GameController

class GameViewController: UIViewController {

    private var metalView: MTKView!
    private var renderer: MetalRenderer!
    private var engine: LuduvoEngine!
    private var touchControls: TouchControlOverlay!
    private var displayLink: CADisplayLink?
    private var lastFrameTime: CFTimeInterval = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        setupMetalView()
        setupRenderer()
        setupEngine()
        setupTouchControls()
        setupGameController()
        startDisplayLink()
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    private func setupMetalView() {
        metalView = MTKView(frame: view.bounds)
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.sampleCount = 4
        metalView.preferredFramesPerSecond = 60
        metalView.enableSetNeedsDisplay = false
        metalView.isPaused = false
        metalView.framebufferOnly = false
        metalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        view.addSubview(metalView)
        view.sendSubviewToBack(metalView)
    }

    private func setupRenderer() {
        renderer = MetalRenderer(metalView: metalView)
        metalView.delegate = renderer
    }

    private func setupEngine() {
        engine = LuduvoEngine()
        engine.metalView = metalView
        engine.renderer = renderer

        // Load join config if exists
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let configURL = documents.appendingPathComponent("luduvo_join.json")
            if FileManager.default.fileExists(atPath: configURL.path) {
                engine.start(configPath: configURL.path)
            }
        }
    }

    private func setupTouchControls() {
        touchControls = TouchControlOverlay(frame: view.bounds)
        touchControls.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        touchControls.delegate = self
        view.addSubview(touchControls)
    }

    private func setupGameController() {
        GCController.startWirelessControllerDiscovery(completionHandler: nil)

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.configureController(notification.object as? GCController)
        }

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.engine?.gamepadDisconnected()
        }

        // Configure already connected controllers
        GCController.controllers().forEach(configureController)
    }

    private func configureController(_ controller: GCController?) {
        guard let controller = controller else { return }
        controller.microGamepad?.allowsRotation = true
        controller.microGamepad?.reportsAbsoluteDpadValues = true
        controller.microGamepad?.dpad.valueChangedHandler = { [weak self] dpad, x, y in
            self?.engine?.gamepadDPad(x: x, y: y)
        }
        controller.microGamepad?.buttonA.valueChangedHandler = { [weak self] _, value, pressed in
            self?.engine?.gamepadButton(.a, value: value, pressed: pressed)
        }
        controller.microGamepad?.buttonB.valueChangedHandler = { [weak self] _, value, pressed in
            self?.engine?.gamepadButton(.b, value: value, pressed: pressed)
        }
        controller.microGamepad?.buttonX.valueChangedHandler = { [weak self] _, value, pressed in
            self?.engine?.gamepadButton(.x, value: value, pressed: pressed)
        }
        controller.microGamepad?.buttonY.valueChangedHandler = { [weak self] _, value, pressed in
            self?.engine?.gamepadButton(.y, value: value, pressed: pressed)
        }
        controller.microGamepad?.leftTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            self?.engine?.gamepadTrigger(.left, value: value)
        }
        controller.microGamepad?.rightTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            self?.engine?.gamepadTrigger(.right, value: value)
        }
    }

    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick(_:)))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func displayLinkTick(_ link: CADisplayLink) {
        let currentTime = link.timestamp
        let dt = lastFrameTime > 0 ? Float(currentTime - lastFrameTime) : 1.0/60.0
        lastFrameTime = currentTime

        engine?.tick(dt: dt)
        touchControls?.update(dt: dt)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            self.engine?.resize(width: Int(size.width), height: Int(size.height))
        }
    }

    deinit {
        displayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
        GCController.stopWirelessControllerDiscovery()
    }
}

extension GameViewController: TouchControlDelegate {
    func touchControl(_ control: TouchControlOverlay, didMoveStick stick: TouchControlOverlay.Stick, x: Float, y: Float) {
        engine?.touchStick(stick == .left ? .move : .look, x: x, y: y)
    }

    func touchControl(_ control: TouchControlOverlay, didPressButton button: TouchControlOverlay.Button, pressed: Bool) {
        engine?.touchButton(button, pressed: pressed)
    }
}