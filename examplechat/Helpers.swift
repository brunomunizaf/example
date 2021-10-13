import UIKit
import Foundation

public final class SetActor<Option: SetAlgebra, ReactionType> {
    public enum Action {
        case onEmpty
        case onChange
        case onRemoval(_ option: Option)
        case onInsertion(_ option: Option)
    }

    public enum ExecutionType {
        case once
        case eternal
    }

    public final class Reaction {
        public let action: Action
        public let type: ReactionType
        public let actionBlock: () -> Void
        public let executionType: ExecutionType

        public init(
            type: ReactionType,
            action: Action,
            executionType: ExecutionType = .once,
            actionBlock: @escaping () -> Void
        ) {
            self.type = type
            self.action = action
            self.executionType = executionType
            self.actionBlock = actionBlock
        }
    }

    public var options: Option {
        didSet { optionsChanged(oldOptions: oldValue) }
    }

    public private(set) var reactions: [Reaction]

    public init(options: Option = [], reactions: [Reaction] = []) {
        self.options = options
        self.reactions = reactions
        optionsChanged(oldOptions: [])
    }

    public func add(reaction: Reaction) {
        reactions.append(reaction)
    }

    public func remove(reaction: Reaction) {
        reactions.removeAll(where: { $0 === reaction })
    }

    public func removeAllReactions(where shouldBeRemoved: (Reaction) throws -> Bool) throws {
        try reactions.removeAll(where: shouldBeRemoved)
    }

    public func removeAllReactions() {
        reactions.removeAll()
    }

    private func optionsChanged(oldOptions: Option) {
        let reactions = self.reactions
        let onChangeReactions = reactions.filter {
            guard case .onChange = $0.action else {
                return false
            }
            return true
        }

        onChangeReactions.forEach { reaction in
            reaction.actionBlock()
            if reaction.executionType == .once {
                self.reactions.removeAll(where: { $0 === reaction })
            }
        }

        if options.isEmpty {
            let onEmptyReactions = reactions.filter {
                guard case .onEmpty = $0.action else {
                    return false
                }
                return true
            }
            onEmptyReactions.forEach { reaction in
                reaction.actionBlock()
                if reaction.executionType == .once {
                    self.reactions.removeAll(where: { $0 === reaction })
                }
            }
        }

        let insertedOptions = options.subtracting(oldOptions)
        for option in [insertedOptions] {
            let onEmptyReactions = reactions.filter {
                guard case let .onInsertion(newOption) = $0.action,
                      newOption == option else {
                          return false
                      }
                return true
            }
            onEmptyReactions.forEach { reaction in
                reaction.actionBlock()
                if reaction.executionType == .once {
                    self.reactions.removeAll(where: { $0 === reaction })
                }
            }
        }

        let removedOptions = oldOptions.subtracting(options)
        for option in [removedOptions] {
            let onEmptyReactions = reactions.filter {
                guard case let .onRemoval(newOption) = $0.action,
                      newOption == option else {
                          return false
                      }
                return true
            }

            onEmptyReactions.forEach { reaction in
                reaction.actionBlock()
                if reaction.executionType == .once {
                    self.reactions.removeAll(where: { $0 === reaction })
                }
            }
        }
    }
}

extension SetActor where ReactionType: Equatable {
    public func removeAllReactions(_ type: ReactionType) {
        reactions.removeAll(where: { $0.type == type })
    }
}

final class ManualAnimator {
    enum AnimationCurve {
        case linear, parametric, easeInOut, easeIn, easeOut

        func modify(_ x: CGFloat) -> CGFloat {
            switch self {
            case .linear:
                return x
            case .parametric:
                return x.parametric
            case .easeInOut:
                return x.quadraticEaseInOut
            case .easeIn:
                return x.quadraticEaseIn
            case .easeOut:
                return x.quadraticEaseOut
            }
        }
    }

    private var displayLink: CADisplayLink?
    private var start = Date()
    private var total = TimeInterval(0)
    private var closure: ((CGFloat) -> Void)?
    private var animationCurve: AnimationCurve = .linear

    func animate(duration: TimeInterval, curve: AnimationCurve = .linear, _ animations: @escaping (CGFloat) -> Void) {
        guard duration > 0 else {
            animations(1.0); return
        }
        reset()
        start = Date()
        closure = animations
        total = duration
        animationCurve = curve
        let d = CADisplayLink(target: self, selector: #selector(tick))
        d.add(to: .current, forMode: .common)
        displayLink = d
    }

    @objc private func tick() {
        let delta = Date().timeIntervalSince(start)
        var percentage = animationCurve.modify(CGFloat(delta) / CGFloat(total))
        if percentage < 0.0 {
            percentage = 0.0
        } else if percentage >= 1.0 {
            percentage = 1.0
            reset()
        }

        closure?(percentage)
    }

    private func reset() {
        displayLink?.invalidate()
        displayLink = nil
    }
}

extension CGFloat {
    fileprivate var parametric: CGFloat {
        guard self > 0.0 else { return 0.0 }
        guard self < 1.0 else { return 1.0 }

        return ((self * self) / (2.0 * ((self * self) - self) + 1.0))
    }

    fileprivate var quadraticEaseInOut: CGFloat {
        guard self > 0.0 else { return 0.0 }
        guard self < 1.0 else { return 1.0 }

        if self < 0.5 {
            return 2 * self * self
        }

        return (-2 * self * self) + (4 * self) - 1
    }

    fileprivate var quadraticEaseOut: CGFloat {
        guard self > 0.0 else { return 0.0 }
        guard self < 1.0 else { return 1.0 }

        return -self * (self - 2)
    }

    fileprivate var quadraticEaseIn: CGFloat {
        guard self > 0.0 else { return 0.0 }
        guard self < 1.0 else { return 1.0 }

        return self * self
    }
}

protocol KeyboardListenerDelegate: AnyObject {
    func keyboardDidHide(info: KeyboardInfo)
    func keyboardDidShow(info: KeyboardInfo)
    func keyboardWillShow(info: KeyboardInfo)
    func keyboardWillHide(info: KeyboardInfo)
    func keyboardDidChangeFrame(info: KeyboardInfo)
    func keyboardWillChangeFrame(info: KeyboardInfo)
}

extension KeyboardListenerDelegate {
    func keyboardDidHide(info: KeyboardInfo) {}
    func keyboardDidShow(info: KeyboardInfo) {}
    func keyboardWillHide(info: KeyboardInfo) {}
    func keyboardWillShow(info: KeyboardInfo) {}
    func keyboardWillChangeFrame(info: KeyboardInfo) {}
    func keyboardDidChangeFrame(info: KeyboardInfo) {}
}

final class KeyboardListener {
    static let shared = KeyboardListener()

    private(set) var keyboardRect: CGRect?
    private(set) var isKeyboardVisible: Bool = false

    private var delegates = NSHashTable<AnyObject>.weakObjects()

    private init() { subscribeToKeyboardNotifications() }

    func add(delegate: KeyboardListenerDelegate) {
        delegates.add(delegate)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else {
            return
        }

        keyboardRect = info.frameEnd
        isKeyboardVisible = true
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardWillShow(info: info)
        }
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else { return }

        keyboardRect = info.frameEnd
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardWillChangeFrame(info: info)
        }
    }

    @objc private func keyboardDidChangeFrame(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else { return }

        keyboardRect = info.frameEnd
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardDidChangeFrame(info: info)
        }
    }

    @objc private func keyboardDidShow(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else { return }

        keyboardRect = info.frameEnd
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardDidShow(info: info)
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else { return }

        keyboardRect = info.frameEnd
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardWillHide(info: info)
        }
    }

    @objc private func keyboardDidHide(_ notification: Notification) {
        guard let info = KeyboardInfo(notification) else { return }

        keyboardRect = info.frameEnd
        isKeyboardVisible = false
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardDidHide(info: info)
        }
    }

    private func subscribeToKeyboardNotifications() {
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(keyboardWillShow(_:)),
                         name: UIResponder.keyboardWillShowNotification,
                         object: nil)
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(keyboardDidShow(_:)),
                         name: UIResponder.keyboardDidShowNotification,
                         object: nil)
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(keyboardWillHide(_:)),
                         name: UIResponder.keyboardWillHideNotification,
                         object: nil)
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(keyboardDidHide(_:)),
                         name: UIResponder.keyboardDidHideNotification,
                         object: nil)
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(keyboardWillChangeFrame(_:)),
                         name: UIResponder.keyboardWillChangeFrameNotification,
                         object: nil)
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(keyboardDidChangeFrame(_:)),
                         name: UIResponder.keyboardDidChangeFrameNotification,
                         object: nil)
    }

}

struct KeyboardInfo: Equatable {
    let isLocal: Bool
    let frameEnd: CGRect
    let frameBegin: CGRect
    let animationDuration: Double
    let animationCurve: UIView.AnimationCurve

    init?(_ notification: Notification) {
        guard let userInfo: NSDictionary = notification.userInfo as NSDictionary?,
              let keyboardAnimationCurve = (userInfo.object(forKey: UIResponder.keyboardAnimationCurveUserInfoKey) as? NSValue) as? Int,
              let keyboardAnimationDuration = (userInfo.object(forKey: UIResponder.keyboardAnimationDurationUserInfoKey) as? NSValue) as? Double,
              let keyboardIsLocal = (userInfo.object(forKey: UIResponder.keyboardIsLocalUserInfoKey) as? NSValue) as? Bool,
              let keyboardFrameBegin = (userInfo.object(forKey: UIResponder.keyboardFrameBeginUserInfoKey) as? NSValue)?.cgRectValue,
              let keyboardFrameEnd = (userInfo.object(forKey: UIResponder.keyboardFrameEndUserInfoKey) as? NSValue)?.cgRectValue else {
                  return nil
              }

        self.animationDuration = keyboardAnimationDuration
        var animationCurve = UIView.AnimationCurve.easeInOut
        NSNumber(value: keyboardAnimationCurve).getValue(&animationCurve)
        self.animationCurve = animationCurve
        self.isLocal = keyboardIsLocal
        self.frameBegin = keyboardFrameBegin
        self.frameEnd = keyboardFrameEnd
    }
}
