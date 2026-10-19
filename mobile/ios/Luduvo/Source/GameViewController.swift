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

    init(engine: LuduvoEngine) {
        self.engine = engine
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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
        metalView.sampleCount = 1
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
        ) { [weak self] _ in
            self?.engine?.gamepadDisconnected()
        }

        // Configure already connected controllers
        GCController.controllers().forEach(configureController)
    }

    private func configureController(_ controller: GCController?) {
        guard let controller else { return }
        controller.microGamepad?.allowsRotation = true
        controller.microGamepad?.reportsAbsoluteDpadValues = true

        // GCMicroGamepad only exposes the d-pad and the A/B buttons. The full
        // button set and the triggers live on the extended gamepad, so prefer
        // it and fall back to the plain gamepad.
        if let pad = controller.extendedGamepad {
            pad.dpad.valueChangedHandler = { [weak self] _, x, y in
                self?.engine?.gamepadDPad(x: x, y: y)
            }
            pad.buttonA.valueChangedHandler = { [weak self] _, value, pressed in
                self?.engine?.gamepadButton(.a, value: value, pressed: pressed)
            }
            pad.buttonB.valueChangedHandler = { [weak self] _, value, pressed in
                self?.engine?.gamepadButton(.b, value: value, pressed: pressed)
            }
            pad.buttonX.valueChangedHandler = { [weak self] _, value, pressed in
                self?.engine?.gamepadButton(.x, value: value, pressed: pressed)
            }
            pad.buttonY.valueChangedHandler = { [weak self] _, value, pressed in
                self?.engine?.gamepadButton(.y, value: value, pressed: pressed)
            }
            pad.leftTrigger.valueChangedHandler = { [weak self] _, value, pressed in
                self?.engine?.gamepadTrigger(.left, value: value, pressed: pressed)
            }
            pad.rightTrigger.valueChangedHandler = { [weak self] _, value, pressed in
                self?.engine?.gamepadTrigger(.right, value: value, pressed: pressed)
            }
        } else if let pad = controller.gamepad {
            pad.dpad.valueChangedHandler = { [weak self] _, x, y in
                self?.engine?.gamepadDPad(x: x, y: y)
            }
            pad.buttonA.valueChangedHandler = { [weak self] _, value, pressed in
                self?.engine?.gamepadButton(.a, value: value, pressed: pressed)
            }
            pad.buttonB.valueChangedHandler = { [weak self] _, value, pressed in
                self?.engine?.gamepadButton(.b, value: value, pressed: pressed)
            }
            pad.buttonX.valueChangedHandler = { [weak self] _, value, pressed in
                self?.engine?.gamepadButton(.x, value: value, pressed: pressed)
            }
            pad.buttonY.valueChangedHandler = { [weak self] _, value, pressed in
                self?.engine?.gamepadButton(.y, value: value, pressed: pressed)
            }
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
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.engine?.resize(width: Int(size.width), height: Int(size.height))
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
        let engineStick: LuduvoTouchStick = (stick == .left) ? .move : .look
        engine?.touchStick(engineStick, x: x, y: y)
    }

    func touchControl(_ control: TouchControlOverlay, didPressButton button: TouchControlOverlay.Button, pressed: Bool) {
        let engineButton: LuduvoTouchButton
        switch button {
        case .jump: engineButton = .jump
        case .sprint: engineButton = .sprint
        case .action: engineButton = .action
        case .inventory: engineButton = .inventory
        case .chat: engineButton = .chat
        }
        engine?.touchButton(engineButton, pressed: pressed)
    }
}
