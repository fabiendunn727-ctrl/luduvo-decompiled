import UIKit

protocol TouchControlDelegate: AnyObject {
    func touchControl(_ control: TouchControlOverlay, didMoveStick stick: Stick, x: Float, y: Float)
    func touchControl(_ control: TouchControlOverlay, didPressButton button: Button, pressed: Bool)
}

class TouchControlOverlay: UIView {

    enum Stick { case left, right }
    enum Button { case jump, sprint, action, inventory, chat }

    weak var delegate: TouchControlDelegate?

    private var leftStick: VirtualStick!
    private var rightStick: VirtualStick!
    private var buttons: [Button: VirtualButton] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = true
        setupSticks()
        setupButtons()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSticks()
        setupButtons()
    }

    private func setupSticks() {
        let stickSize: CGFloat = min(bounds.width, bounds.height) * 0.25
        let margin: CGFloat = 24

        leftStick = VirtualStick(frame: CGRect(
            x: margin,
            y: bounds.height - stickSize - margin,
            width: stickSize,
            height: stickSize
        ))
        leftStick.stickType = .left
        leftStick.delegate = self
        addSubview(leftStick)

        rightStick = VirtualStick(frame: CGRect(
            x: bounds.width - stickSize - margin,
            y: bounds.height - stickSize - margin,
            width: stickSize,
            height: stickSize
        ))
        rightStick.stickType = .right
        rightStick.delegate = self
        addSubview(rightStick)
    }

    private func setupButtons() {
        let buttonSize: CGFloat = 64
        let margin: CGFloat = 24
        let spacing: CGFloat = 16

        // Jump button (bottom right cluster)
        let jumpFrame = CGRect(
            x: bounds.width - buttonSize - margin,
            y: bounds.height - buttonSize * 2 - margin * 2 - spacing,
            width: buttonSize,
            height: buttonSize
        )
        let jumpButton = VirtualButton(frame: jumpFrame, type: .jump)
        jumpButton.delegate = self
        buttons[.jump] = jumpButton
        addSubview(jumpButton)

        // Sprint button
        let sprintFrame = CGRect(
            x: bounds.width - buttonSize * 2 - margin - spacing,
            y: bounds.height - buttonSize * 2 - margin * 2 - spacing,
            width: buttonSize,
            height: buttonSize
        )
        let sprintButton = VirtualButton(frame: sprintFrame, type: .sprint)
        sprintButton.delegate = self
        buttons[.sprint] = sprintButton
        addSubview(sprintButton)

        // Action button
        let actionFrame = CGRect(
            x: bounds.width - buttonSize * 3 - margin - spacing * 2,
            y: bounds.height - buttonSize * 2 - margin * 2 - spacing,
            width: buttonSize,
            height: buttonSize
        )
        let actionButton = VirtualButton(frame: actionFrame, type: .action)
        actionButton.delegate = self
        buttons[.action] = actionButton
        addSubview(actionButton)

        // Inventory button (top right)
        let inventoryFrame = CGRect(
            x: bounds.width - buttonSize - margin,
            y: margin + 44, // Below status bar
            width: buttonSize,
            height: buttonSize
        )
        let inventoryButton = VirtualButton(frame: inventoryFrame, type: .inventory)
        inventoryButton.delegate = self
        buttons[.inventory] = inventoryButton
        addSubview(inventoryButton)

        // Chat button
        let chatFrame = CGRect(
            x: bounds.width - buttonSize * 2 - margin - spacing,
            y: margin + 44,
            width: buttonSize,
            height: buttonSize
        )
        let chatButton = VirtualButton(frame: chatFrame, type: .chat)
        chatButton.delegate = self
        buttons[.chat] = chatButton
        addSubview(chatButton)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Reposition on rotation
        setupSticks()
        setupButtons()
    }

    func update(dt: Float) {
        leftStick?.update(dt: dt)
        rightStick?.update(dt: dt)
        buttons.values.forEach { $0.update(dt: dt) }
    }
}

extension TouchControlOverlay: VirtualStickDelegate {
    func virtualStick(_ stick: VirtualStick, didMove x: Float, y: Float) {
        delegate?.touchControl(self, didMoveStick: stick.stickType, x: x, y: y)
    }
}

extension TouchControlOverlay: VirtualButtonDelegate {
    func virtualButton(_ button: VirtualButton, didPress pressed: Bool) {
        delegate?.touchControl(self, didPressButton: button.type, pressed: pressed)
    }
}

// MARK: - Virtual Stick

protocol VirtualStickDelegate: AnyObject {
    func virtualStick(_ stick: VirtualStick, didMove x: Float, y: Float)
}

class VirtualStick: UIView {

    enum StickType { case left, right }
    var stickType: StickType = .left
    weak var delegate: VirtualStickDelegate?

    private var baseView: UIView!
    private var knobView: UIView!
    private var trackingTouch: UITouch?
    private var centerPoint: CGPoint = .zero
    private let radius: CGFloat

    init(frame: CGRect) {
        self.radius = min(frame.width, frame.height) / 2
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        self.radius = 0
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear

        baseView = UIView(frame: bounds)
        baseView.backgroundColor = UIColor(white: 0.2, alpha: 0.5)
        baseView.layer.cornerRadius = radius
        baseView.layer.borderWidth = 2
        baseView.layer.borderColor = UIColor(red: 0x7C/255, green: 0x4D/255, blue: 0xFF/255, alpha: 0.8).cgColor
        addSubview(baseView)

        let knobSize = radius * 0.6
        knobView = UIView(frame: CGRect(x: 0, y: 0, width: knobSize, height: knobSize))
        knobView.center = baseView.center
        knobView.backgroundColor = UIColor(red: 0x7C/255, green: 0x4D/255, blue: 0xFF/255, alpha: 0.9)
        knobView.layer.cornerRadius = knobSize / 2
        knobView.layer.shadowColor = UIColor.black.cgColor
        knobView.layer.shadowOpacity = 0.5
        knobView.layer.shadowRadius = 4
        knobView.layer.shadowOffset = CGSize(width: 0, height: 2)
        addSubview(knobView)

        centerPoint = baseView.center
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard trackingTouch == nil, let touch = touches.first else { return }
        let location = touch.location(in: self)
        if baseView.frame.contains(location) {
            trackingTouch = touch
            updateKnob(for: location)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackingTouch, let location = touches.first?.location(in: self) else { return }
        updateKnob(for: location)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = trackingTouch, touches.contains(touch) else { return }
        trackingTouch = nil
        resetKnob()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func updateKnob(for location: CGPoint) {
        let dx = location.x - centerPoint.x
        let dy = location.y - centerPoint.y
        let distance = hypot(dx, dy)

        let clampedDistance = min(distance, radius)
        let angle = atan2(dy, dx)

        let newX = centerPoint.x + cos(angle) * clampedDistance
        let newY = centerPoint.y + sin(angle) * clampedDistance
        knobView.center = CGPoint(x: newX, y: newY)

        // Normalize to -1...1
        let normX = Float(clampedDistance * cos(angle) / radius)
        let normY = Float(clampedDistance * sin(angle) / radius)

        delegate?.virtualStick(self, didMove: normX, y: normY)
    }

    private func resetKnob() {
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseOut]) {
            self.knobView.center = self.centerPoint
        }
        delegate?.virtualStick(self, didMove: 0, y: 0)
    }

    func update(dt: Float) {
        // Auto-center decay if needed
    }
}

// MARK: - Virtual Button

protocol VirtualButtonDelegate: AnyObject {
    func virtualButton(_ button: VirtualButton, didPress pressed: Bool)
}

class VirtualButton: UIView {

    enum ButtonType { case jump, sprint, action, inventory, chat }
    var type: ButtonType
    weak var delegate: VirtualButtonDelegate?

    private var isPressed = false
    private var pressStartTime: CFTimeInterval = 0

    init(frame: CGRect, type: ButtonType) {
        self.type = type
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        self.type = .action
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = UIColor(white: 0.15, alpha: 0.7)
        layer.cornerRadius = bounds.width / 2
        layer.borderWidth = 2
        layer.borderColor = UIColor(red: 0, green: 0xE5/255, blue: 1, alpha: 0.6).cgColor

        let icon = iconImage(for: type)
        let imageView = UIImageView(image: icon)
        imageView.tintColor = UIColor(red: 0, green: 0xE5/255, blue: 1, alpha: 1)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5),
            imageView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5)
        ])
    }

    private func iconImage(for type: ButtonType) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        switch type {
        case .jump: return UIImage(systemName: "arrow.up.circle.fill", withConfiguration: config)
        case .sprint: return UIImage(systemName: "hare.fill", withConfiguration: config)
        case .action: return UIImage(systemName: "hand.tap.fill", withConfiguration: config)
        case .inventory: return UIImage(systemName: "bag.fill", withConfiguration: config)
        case .chat: return UIImage(systemName: "message.fill", withConfiguration: config)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isPressed = true
        pressStartTime = CACurrentMediaTime()
        animatePress(true)
        delegate?.virtualButton(self, didPress: true)

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isPressed = false
        animatePress(false)
        delegate?.virtualButton(self, didPress: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func animatePress(_ pressed: Bool) {
        UIView.animate(withDuration: 0.1) {
            self.transform = pressed ? CGAffineTransform(scaleX: 0.9, y: 0.9) : .identity
            self.alpha = pressed ? 0.8 : 1.0
        }
    }

    func update(dt: Float) {
        // Long press detection if needed
    }
}