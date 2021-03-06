import UIKit
import Combine
import SnapKit
import DifferenceKit

public extension UIView {
    enum PinningPoint {
        case right
    }

    func embedded(on point: PinningPoint) -> UIView {
        let container = UIView()
        container.addSubview(self)

        self.snp.makeConstraints { make in
            switch point {
            case .right:
                let flexibleSpace = FlexibleSpace()
                container.addSubview(flexibleSpace)
                flexibleSpace.snp.makeConstraints { $0.left.equalToSuperview() }

                make.top.equalToSuperview()
                make.left.greaterThanOrEqualTo(flexibleSpace.snp.right)
                make.right.equalToSuperview()
                make.bottom.equalToSuperview()
            }
        }

        return container
    }
}

public extension UIBezierPath {
    static func round(_ size: CGSize, rad: CGFloat) -> UIBezierPath {
        UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: rad)
    }
}

protocol ReusableView {}

extension ReusableView where Self: UIView {
    static var reuseIdentifier: String {
        return String(describing: self)
    }
}

extension UICollectionReusableView: ReusableView {}

public extension UICollectionView {
    func register<T: UICollectionViewCell>(_: T.Type) {
        register(T.self, forCellWithReuseIdentifier: T.reuseIdentifier)
    }

    func dequeueReusableCell<T: UICollectionViewCell>(forIndexPath indexPath: IndexPath) -> T {
        guard let cell = dequeueReusableCell(withReuseIdentifier: T.reuseIdentifier, for: indexPath) as? T else {
            fatalError("Could not dequeue cell with identifier: \(T.reuseIdentifier)")
        }

        return cell
    }

    func reload<C>(
        using stagedChangeset: StagedChangeset<C>,
        interrupt: ((Changeset<C>) -> Bool)? = nil,
        onInterruptedReload: (() -> Void)? = nil,
        completion: ((Bool) -> Void)? = nil,
        setData: (C) -> Void
    ) {
        if case .none = window, let data = stagedChangeset.last?.data {
            setData(data)
            if let onInterruptedReload = onInterruptedReload {
                onInterruptedReload()
            } else {
                reloadData()
            }
            completion?(false)
            return
        }

        let dispatchGroup: DispatchGroup? = completion != nil
        ? DispatchGroup()
        : nil
        let completionHandler: ((Bool) -> Void)? = completion != nil
        ? { _ in
            dispatchGroup!.leave()
        }
        : nil

        for changeset in stagedChangeset {
            if let interrupt = interrupt, interrupt(changeset), let data = stagedChangeset.last?.data {
                setData(data)
                if let onInterruptedReload = onInterruptedReload {
                    onInterruptedReload()
                } else {
                    reloadData()
                }
                completion?(false)
                return
            }

            performBatchUpdates({
                setData(changeset.data)
                dispatchGroup?.enter()

                if !changeset.sectionDeleted.isEmpty {
                    deleteSections(IndexSet(changeset.sectionDeleted))
                }

                if !changeset.sectionInserted.isEmpty {
                    insertSections(IndexSet(changeset.sectionInserted))
                }

                if !changeset.sectionUpdated.isEmpty {
                    reloadSections(IndexSet(changeset.sectionUpdated))
                }

                for (source, target) in changeset.sectionMoved {
                    moveSection(source, toSection: target)
                }

                if !changeset.elementDeleted.isEmpty {
                    deleteItems(at: changeset.elementDeleted.map {
                        IndexPath(item: $0.element, section: $0.section)
                    })
                }

                if !changeset.elementInserted.isEmpty {
                    insertItems(at: changeset.elementInserted.map {
                        IndexPath(item: $0.element, section: $0.section)
                    })
                }

                if !changeset.elementUpdated.isEmpty {
                    reloadItems(at: changeset.elementUpdated.map {
                        IndexPath(item: $0.element, section: $0.section)
                    })
                }

                for (source, target) in changeset.elementMoved {
                    moveItem(at: IndexPath(item: source.element, section: source.section), to: IndexPath(item: target.element, section: target.section))
                }
            }, completion: completionHandler)
        }
        dispatchGroup?.notify(queue: .main) {
            completion!(true)
        }
    }
}

public extension StagedChangeset {
    func flattenIfPossible() -> StagedChangeset {
        if count == 2,
           self[0].sectionChangeCount == 0,
           self[1].sectionChangeCount == 0,
           self[0].elementDeleted.count == self[0].elementChangeCount,
           self[1].elementInserted.count == self[1].elementChangeCount {
            return StagedChangeset(arrayLiteral: Changeset(data: self[1].data, elementDeleted: self[0].elementDeleted, elementInserted: self[1].elementInserted))
        }
        return self
    }
}

public extension UIControl {
    func publisher(for event: Event) -> EventPublisher {
        EventPublisher(
            control: self,
            event: event
        )
    }

    struct EventPublisher: Publisher {
        public typealias Output = Void
        public typealias Failure = Never

        fileprivate var control: UIControl
        fileprivate var event: Event

        public func receive<S: Subscriber>(
            subscriber: S
        ) where S.Input == Output, S.Failure == Failure {
            let subscription = EventSubscription<S>()
            subscription.target = subscriber
            subscriber.receive(subscription: subscription)

            control.addTarget(subscription,
                              action: #selector(subscription.trigger),
                              for: event
            )
        }
    }
}

private extension UIControl {
    class EventSubscription<Target: Subscriber>: Subscription
    where Target.Input == Void {

        var target: Target?

        func request(_ demand: Subscribers.Demand) {}

        func cancel() {
            target = nil
        }

        @objc func trigger() {
            _ = target?.receive(())
        }
    }
}

public extension UITextField {
    var textPublisher: AnyPublisher<String, Never> {
        publisher(for: .editingChanged)
            .map { self.text ?? "" }
            .eraseToAnyPublisher()
    }

    var returnPublisher: AnyPublisher<Void, Never> {
        publisher(for: .editingDidEndOnExit)
            .eraseToAnyPublisher()
    }
}

public extension UITextView {
    var textPublisher: Publishers.TextFieldPublisher {
        Publishers.TextFieldPublisher(textField: self)
    }
}

public extension Publishers {
    struct TextFieldPublisher: Publisher {
        public typealias Output = String
        public typealias Failure = Never

        private let textField: UITextView

        init(textField: UITextView) { self.textField = textField }

        public func receive<S>(subscriber: S) where S : Subscriber, Publishers.TextFieldPublisher.Failure == S.Failure, Publishers.TextFieldPublisher.Output == S.Input {
            let subscription = TextFieldSubscription(subscriber: subscriber, textField: textField)
            subscriber.receive(subscription: subscription)
        }
    }

    class TextFieldSubscription<S: Subscriber>: NSObject, Subscription, UITextViewDelegate where S.Input == String, S.Failure == Never  {

        private var subscriber: S?
        private weak var textField: UITextView?

        init(subscriber: S, textField: UITextView) {
            super.init()
            self.subscriber = subscriber
            self.textField = textField
            subscribe()
        }

        public func request(_ demand: Subscribers.Demand) { }

        public func cancel() {
            subscriber = nil
            textField = nil
        }

        private func subscribe() {
            textField?.delegate = self
        }

        public func textViewDidChange(_ textView: UITextView) {
            _ = subscriber?.receive(textView.text)
        }
    }
}
