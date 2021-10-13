import UIKit
import SnapKit

protocol CollectionCellContent: UIView {
    func prepareForReuse()
}

extension FlexibleSpace: CollectionCellContent {
    func prepareForReuse() {}
}

final class CollectionCell<LeftView: CollectionCellContent, RightView: CollectionCellContent>: UICollectionViewCell {

    // MARK: Properties

    let leftView = LeftView(frame: .zero)
    let rightView = RightView(frame: .zero)

    private let container = UIView()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    override func prepareForReuse() {
        super.prepareForReuse()
        leftView.prepareForReuse()
        rightView.prepareForReuse()
        container.transform = .identity
    }

    // MARK: Private

    private func setup() {
        contentView.addSubview(container)
        container.addSubview(leftView)
        container.addSubview(rightView)

        container.snp.makeConstraints { $0.edges.equalToSuperview() }

        leftView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        rightView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.right.equalToSuperview()
            make.left.equalTo(leftView.snp.right)
            make.bottom.equalToSuperview()
        }
    }
}

public final class FlexibleSpace: UIView {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    public convenience init() {
        self.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }
}

final class StackMessageView: UIView, CollectionCellContent {
    // MARK: UI

    let date = UILabel()
    let text = TextView()
    private let stack = UIStackView()
    private let shape = CAShapeLayer()
    private let bottomStack = UIStackView()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePath()
    }

    required init?(coder: NSCoder) { nil }

    func prepareForReuse() {
        date.text = nil
        text.text = nil
        text.resignFirstResponder()
    }

    // MARK: Private

    private func setup() {
        layoutMargins = UIEdgeInsets(top: 8, left: 15, bottom: 8, right: 15)

        bottomStack.spacing = 3
        bottomStack.addArrangedSubview(date.embedded(on: .right))

        stack.spacing = 6
        stack.axis = .vertical
        stack.addArrangedSubview(text)
        stack.addArrangedSubview(bottomStack)

        addSubview(stack)
        setupConstraints()
    }

    private func setupConstraints() {
        translatesAutoresizingMaskIntoConstraints = false
        insetsLayoutMarginsFromSafeArea = false

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor, constant: 5).isActive = true
        stack.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: -3).isActive = true
        stack.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor).isActive = true
        stack.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor).isActive = true
        stack.widthAnchor.constraint(lessThanOrEqualToConstant: 300).isActive = true
    }

    private func updatePath() {
        UIView.performWithoutAnimation {
            shape.frame = bounds
            shape.path = UIBezierPath.round(bounds.size, rad: 13).cgPath
            layer.mask = shape
        }
    }
}

/// UITextView avoiding selection

final class TextView: UITextView {
    // MARK: Properties

    override var isFocused: Bool { false }
    override var canBecomeFirstResponder: Bool { false }
    override var canBecomeFocused: Bool { false }
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool { false }

    // MARK: Lifecycle

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    // MARK: Private

    private func setup() {
        bounces = false
        isEditable = false
        bouncesZoom = false
        scrollsToTop = false
        isScrollEnabled = false
        isExclusiveTouch = true
        spellCheckingType = .no
        dataDetectorTypes = .all
        backgroundColor = .clear
        textContainerInset = .zero
        showsVerticalScrollIndicator = false
        textContainer.lineFragmentPadding = 0
        showsHorizontalScrollIndicator = false
        layoutManager.allowsNonContiguousLayout = true
    }
}
