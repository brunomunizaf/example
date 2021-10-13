import UIKit
import Combine
import Foundation
import ChatLayout
import DifferenceKit
import InputBarAccessoryView

typealias OutgoingTextCell = CollectionCell<FlexibleSpace, StackMessageView>
typealias IncomingTextCell = CollectionCell<StackMessageView, FlexibleSpace>

class ViewController: UIViewController {
    private enum ReactionTypes {
        case delayedUpdate
    }

    private enum InterfaceActions {
        case changingKeyboardFrame
        case changingContentInsets
        case changingFrameSize
        case sendingMessage
        case scrollingToTop
        case scrollingToBottom
        case showingPreview
        case showingAccessory
    }

    private enum ControllerActions {
        case loadingInitialMessages
        case loadingPreviousMessages
    }

    public override var inputAccessoryView: UIView? {
        return inputBarView
    }

    public override var canBecomeFirstResponder: Bool {
        return true
    }

    private let viewModel = ViewModel()
    private let chatLayout = ChatLayout()
    private var animator: ManualAnimator?
    private var collectionView: UICollectionView!
    private let inputBarView = InputBarAccessoryView()
    private var currentInterfaceActions: SetActor<Set<InterfaceActions>, ReactionTypes> = SetActor()
    private var currentControllerActions: SetActor<Set<ControllerActions>, ReactionTypes> = SetActor()

    private var cancellables = Set<AnyCancellable>()
    private var sections = [ArraySection<ChatSection, ChatItem>]()

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        collectionView.collectionViewLayout.invalidateLayout()
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        guard isViewLoaded else {
            return
        }
        currentInterfaceActions.options.insert(.changingFrameSize)
        let positionSnapshot = chatLayout.getContentOffsetSnapshot(from: .bottom)
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.setNeedsLayout()
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.performBatchUpdates(nil)
        }, completion: { _ in
            if let positionSnapshot = positionSnapshot,
               !self.isUserInitiatedScrolling {
                self.chatLayout.restoreContentOffset(with: positionSnapshot)
            }
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.currentInterfaceActions.options.remove(.changingFrameSize)
        })

        super.viewWillTransition(to: size, with: coordinator)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        inputBarView.delegate = self
        inputBarView.shouldAnimateTextDidChangeLayout = true

        chatLayout.settings.interItemSpacing = 8
        chatLayout.settings.interSectionSpacing = 8
        chatLayout.settings.additionalInsets = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5)
        chatLayout.keepContentOffsetAtBottomOnBatchUpdates = true

        collectionView = UICollectionView(frame: view.frame, collectionViewLayout: chatLayout)
        view.addSubview(collectionView)
        collectionView.alwaysBounceVertical = true
        collectionView.dataSource = self
        chatLayout.delegate = self
        collectionView.keyboardDismissMode = .interactive

        collectionView.isPrefetchingEnabled = false
        collectionView.contentInsetAdjustmentBehavior = .always
        collectionView.automaticallyAdjustsScrollIndicatorInsets = true

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.frame = view.bounds
        collectionView.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
        collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0).isActive = true
        collectionView.backgroundColor = UIColor.white
        collectionView.showsHorizontalScrollIndicator = false

        collectionView.register(IncomingTextCell.self)
        collectionView.register(OutgoingTextCell.self)

        KeyboardListener.shared.add(delegate: self)

        viewModel.messages
            .receive(on: DispatchQueue.main)
            .filter {
                !$0.isEmpty
            }
            .print()
            .sink { [unowned self] sections in
                //                    guard !self.sections.isEmpty && isViewLoaded else {
                //                        self.sections = sections
                //                        collectionView.reloadData()
                //                        return
                //                    }

                func process() {
                    let changeSet = StagedChangeset(source: self.sections, target: sections).flattenIfPossible()
                    collectionView.reload(
                        using: changeSet,
                        interrupt: { changeSet in
                            guard !self.sections.isEmpty else {
                                return true
                            }
                            return false
                        }, onInterruptedReload: {
                            guard let lastSection = self.sections.last else {
                                return
                            }
                            let positionSnapshot = ChatLayoutPositionSnapshot(indexPath: IndexPath(item: lastSection.elements.count - 1, section: self.sections.count - 1), kind: .cell, edge: .bottom)
                            self.collectionView.reloadData()
                            self.chatLayout.restoreContentOffset(with: positionSnapshot)
                        },
                        completion: nil,
                        setData: { self.sections = $0 }
                    )
                }

                guard currentInterfaceActions.options.isEmpty else {
                    print(currentInterfaceActions.options)

                    let reaction = SetActor<Set<InterfaceActions>, ReactionTypes>.Reaction(
                        type: .delayedUpdate,
                        action: .onEmpty,
                        executionType: .once,
                        actionBlock: { [weak self] in
                            guard let _ = self else {
                                return
                            }
                            process()
                        }
                    )

                    currentInterfaceActions.add(reaction: reaction)
                    return
                }

                process()
            }
            .store(in: &cancellables)
    }
}

extension ViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didChangeIntrinsicContentTo size: CGSize) {
        guard !currentInterfaceActions.options.contains(.sendingMessage) else {
            return
        }

        scrollToBottom()
    }

    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        let messageText = inputBar.inputTextView.text
        currentInterfaceActions.options.insert(.sendingMessage)

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) { [weak self] in
            guard let self = self else {
                return
            }

            guard let messageText = messageText else {
                self.currentInterfaceActions.options.remove(.sendingMessage)
                return
            }

            self.scrollToBottom(completion: {
                self.currentInterfaceActions.options.remove(.sendingMessage)
                self.viewModel.send(messageText)
            })
        }

        inputBar.inputTextView.text = String()
        inputBar.invalidatePlugins()
    }

    func scrollToBottom(completion: (() -> Void)? = nil) {
        let contentOffsetAtBottom = CGPoint(x: collectionView.contentOffset.x,
                                            y: chatLayout.collectionViewContentSize.height - collectionView.frame.height + collectionView.adjustedContentInset.bottom)

        guard contentOffsetAtBottom.y > collectionView.contentOffset.y else {
            completion?()
            return
        }

        let initialOffset = collectionView.contentOffset.y
        let delta = contentOffsetAtBottom.y - initialOffset
        if abs(delta) > chatLayout.visibleBounds.height {
            animator = ManualAnimator()
            animator?.animate(duration: TimeInterval(0.25), curve: .easeInOut) { [weak self] percentage in
                guard let self = self else {
                    return
                }
                self.collectionView.contentOffset = CGPoint(x: self.collectionView.contentOffset.x, y: initialOffset + (delta * percentage))
                if percentage == 1.0 {
                    self.animator = nil
                    let positionSnapshot = ChatLayoutPositionSnapshot(indexPath: IndexPath(item: 0, section: 0), kind: .footer, edge: .bottom)
                    self.chatLayout.restoreContentOffset(with: positionSnapshot)
                    self.currentInterfaceActions.options.remove(.scrollingToBottom)
                    completion?()
                }
            }
        } else {
            currentInterfaceActions.options.insert(.scrollingToBottom)
            UIView.animate(withDuration: 0.25, animations: { [weak self] in
                self?.collectionView.setContentOffset(contentOffsetAtBottom, animated: true)
            }, completion: { [weak self] _ in
                self?.currentInterfaceActions.options.remove(.scrollingToBottom)
                completion?()
            })
        }
    }
}

extension ViewController: KeyboardListenerDelegate {
    fileprivate var isUserInitiatedScrolling: Bool {
        return collectionView.isDragging || collectionView.isDecelerating
    }

    func keyboardWillChangeFrame(info: KeyboardInfo) {
        guard !currentInterfaceActions.options.contains(.changingFrameSize),
              collectionView.contentInsetAdjustmentBehavior != .never,
              let keyboardFrame = UIApplication.shared.keyWindow?.convert(info.frameEnd, to: view),
              collectionView.convert(collectionView.bounds, to: UIApplication.shared.keyWindow).maxY > info.frameEnd.minY else {
                  return
              }
        currentInterfaceActions.options.insert(.changingKeyboardFrame)
        let newBottomInset = collectionView.frame.minY + collectionView.frame.size.height - keyboardFrame.minY - collectionView.safeAreaInsets.bottom
        if newBottomInset > 0,
           collectionView.contentInset.bottom != newBottomInset {
            let positionSnapshot = chatLayout.getContentOffsetSnapshot(from: .bottom)

            currentInterfaceActions.options.insert(.changingContentInsets)
            UIView.animate(withDuration: info.animationDuration, animations: {
                self.collectionView.performBatchUpdates({
                    self.collectionView.contentInset.bottom = newBottomInset
                    self.collectionView.verticalScrollIndicatorInsets.bottom = newBottomInset
                }, completion: nil)

                if let positionSnapshot = positionSnapshot, !self.isUserInitiatedScrolling {
                    self.chatLayout.restoreContentOffset(with: positionSnapshot)
                }
                if #available(iOS 13.0, *) {
                    //
                } else {
                    self.collectionView.collectionViewLayout.invalidateLayout()
                }
            }, completion: { _ in
                self.currentInterfaceActions.options.remove(.changingContentInsets)
            })
        }
    }

    func keyboardDidChangeFrame(info: KeyboardInfo) {
        guard currentInterfaceActions.options.contains(.changingKeyboardFrame) else {
            return
        }
        currentInterfaceActions.options.remove(.changingKeyboardFrame)
    }
}

extension ViewController: ChatLayoutDelegate {
    public func alignmentForItem(
        _ chatLayout: ChatLayout,
        of kind: ItemKind,
        at indexPath: IndexPath
    ) -> ChatItemAlignment {

        switch kind {
        case .cell:
            return .fullWidth
        case .footer, .header:
            return .center
        }
    }
}

extension ViewController: UICollectionViewDataSource {
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].elements.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = sections[indexPath.section].elements[indexPath.item]

        if item.status == .received {
            let cell: IncomingTextCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
            cell.leftView.backgroundColor = UIColor.darkGray
            cell.leftView.text.textColor = UIColor.white
            cell.leftView.date.textColor = UIColor.white
            cell.leftView.date.text = "1:23pm"
            cell.leftView.text.text = item.text
            return cell
        } else {
            let cell: OutgoingTextCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
            cell.rightView.backgroundColor = UIColor.blue
            cell.rightView.text.textColor = UIColor.white
            cell.rightView.date.textColor = UIColor.white
            cell.rightView.date.text = "1:23pm"
            cell.rightView.text.text = item.text
            return cell
        }
    }
}
