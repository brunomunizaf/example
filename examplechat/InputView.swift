import UIKit
import SnapKit

final class BubbleView<Content: UIView>: UIView {

    let content: Content
    let padding: CGFloat

    init(_ content: Content, padding: CGFloat = 0) {
        self.content = content
        self.padding = padding
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        layer.cornerRadius = 4
        clipsToBounds = true
        addSubview(content)

        content.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(padding)
            make.bottom.trailing.equalToSuperview().offset(-padding)
        }
    }
}

final class InputView: UIToolbar {

    let send = UIButton()
    let text = UITextView()
    let hStack = UIStackView()
    let vStack = UIStackView()
    lazy var bubble = BubbleView(vStack, padding: 4)

    var maxHeight: () -> CGFloat = { 150 }

    private var computedTextHeight: CGFloat {
        let textWidth = text.frame.size.width
        let textSize = text.sizeThatFits(CGSize(width: textWidth,
                                                height: .greatestFiniteMagnitude))
        return textSize.height
    }

    init() {
        super.init(frame: .zero)
        layoutIfNeeded() // ← required on iOS 12, without it the view ignores touches
        setup()
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateHeight()
    }

    func updateHeight() {
        let computedTextHeight = self.computedTextHeight
        let computedHeight = computedTextHeight
        let maxHeight = self.maxHeight()

        if computedHeight < maxHeight {
            text.snp.updateConstraints { $0.height.equalTo(computedTextHeight) }
            text.isScrollEnabled = false
        } else {
            text.snp.updateConstraints { $0.height.equalTo(maxHeight) }
            text.isScrollEnabled = true
        }
    }

    private func setup() {
        text.backgroundColor = .clear
        barTintColor = UIColor.lightGray
        text.textColor = UIColor.black
        bubble.backgroundColor = UIColor.white
        text.autocorrectionType = .default

        isTranslucent = false

        send.setImage(UIImage(named: "send"), for: .normal)

        vStack.addArrangedSubview(text)

        hStack.addArrangedSubview(bubble)
        hStack.addArrangedSubview(send)
        addSubview(hStack)

        translatesAutoresizingMaskIntoConstraints = false

        vStack.axis = .vertical

        hStack.spacing = 8
        hStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-8)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-8)
        }

        text.setContentHuggingPriority(.defaultLow, for: .horizontal)
        send.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        send.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
