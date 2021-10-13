import Combine
import Foundation
import DifferenceKit

struct ChatSection: Equatable, Differentiable {
    var date: Date
    var differenceIdentifier: Date { date }
}

enum MessageStatus {
    case sent
    case received
}

struct ChatItem: Equatable, Differentiable {
    let date: Date
    let identity: UUID
    let text: String
    var status: MessageStatus

    var differenceIdentifier: UUID { identity }
}

class ViewModel {
    var messages: AnyPublisher<[ArraySection<ChatSection, ChatItem>], Never> {
        relay.eraseToAnyPublisher()
    }

    private let relay = CurrentValueSubject<[ArraySection<ChatSection, ChatItem>], Never>([
        .init(model: .init(date: Date()), elements: [
            .init(date: Date(), identity: UUID(), text: "Hey", status: .sent),
            .init(date: Date(), identity: UUID(), text: "How are you", status: .received),
            .init(date: Date(), identity: UUID(), text: "I'm good, you?", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Good too", status: .received),
            .init(date: Date(), identity: UUID(), text: "Nice convo...", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Yep.. that's what I thought", status: .received),
            .init(date: Date(), identity: UUID(), text: "Who was that?", status: .sent),
            .init(date: Date(), identity: UUID(), text: "That who?", status: .received),
            .init(date: Date(), identity: UUID(), text: "Nvm...", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Aight..", status: .received),
            .init(date: Date(), identity: UUID(), text: "Bye", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Bye bye", status: .received),
            .init(date: Date(), identity: UUID(), text: "Hey", status: .sent),
            .init(date: Date(), identity: UUID(), text: "How are you", status: .received),
            .init(date: Date(), identity: UUID(), text: "I'm good, you?", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Good too", status: .received),
            .init(date: Date(), identity: UUID(), text: "Nice convo...", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Yep.. that's what I thought", status: .received),
            .init(date: Date(), identity: UUID(), text: "Who was that?", status: .sent),
            .init(date: Date(), identity: UUID(), text: "That who?", status: .received),
            .init(date: Date(), identity: UUID(), text: "Nvm...", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Aight..", status: .received),
            .init(date: Date(), identity: UUID(), text: "Bye", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Bye bye", status: .received),
            .init(date: Date(), identity: UUID(), text: "Hey", status: .sent),
            .init(date: Date(), identity: UUID(), text: "How are you", status: .received),
            .init(date: Date(), identity: UUID(), text: "I'm good, you?", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Good too", status: .received),
            .init(date: Date(), identity: UUID(), text: "Nice convo...", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Yep.. that's what I thought", status: .received),
            .init(date: Date(), identity: UUID(), text: "Who was that?", status: .sent),
            .init(date: Date(), identity: UUID(), text: "That who?", status: .received),
            .init(date: Date(), identity: UUID(), text: "Nvm...", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Aight..", status: .received),
            .init(date: Date(), identity: UUID(), text: "Bye", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Bye bye", status: .received),
            .init(date: Date(), identity: UUID(), text: "Hey", status: .sent),
            .init(date: Date(), identity: UUID(), text: "How are you", status: .received),
            .init(date: Date(), identity: UUID(), text: "I'm good, you?", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Good too", status: .received),
            .init(date: Date(), identity: UUID(), text: "Nice convo...", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Yep.. that's what I thought", status: .received),
            .init(date: Date(), identity: UUID(), text: "Who was that?", status: .sent),
            .init(date: Date(), identity: UUID(), text: "That who?", status: .received),
            .init(date: Date(), identity: UUID(), text: "Nvm...", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Aight..", status: .received),
            .init(date: Date(), identity: UUID(), text: "Bye", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Bye bye", status: .received),
            .init(date: Date(), identity: UUID(), text: "Hey", status: .sent),
            .init(date: Date(), identity: UUID(), text: "How are you", status: .received),
            .init(date: Date(), identity: UUID(), text: "I'm good, you?", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Good too", status: .received),
            .init(date: Date(), identity: UUID(), text: "Nice convo...", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Yep.. that's what I thought", status: .received),
            .init(date: Date(), identity: UUID(), text: "Who was that?", status: .sent),
            .init(date: Date(), identity: UUID(), text: "That who?", status: .received),
            .init(date: Date(), identity: UUID(), text: "Nvm...", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Aight..", status: .received),
            .init(date: Date(), identity: UUID(), text: "Bye", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Bye bye", status: .received),
            .init(date: Date(), identity: UUID(), text: "Hey", status: .sent),
            .init(date: Date(), identity: UUID(), text: "How are you", status: .received),
            .init(date: Date(), identity: UUID(), text: "I'm good, you?", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Good too", status: .received),
            .init(date: Date(), identity: UUID(), text: "Nice convo...", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Yep.. that's what I thought", status: .received),
            .init(date: Date(), identity: UUID(), text: "Who was that?", status: .sent),
            .init(date: Date(), identity: UUID(), text: "That who?", status: .received),
            .init(date: Date(), identity: UUID(), text: "Nvm...", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Aight..", status: .received),
            .init(date: Date(), identity: UUID(), text: "Bye", status: .sent),
            .init(date: Date(), identity: UUID(), text: "Bye bye", status: .received)
        ])
    ])

    func send(_ text: String) {
        var current = relay.value

        current.append(.init(model: .init(date: Date()), elements: [
            .init(date: Date(), identity: UUID(), text: text, status: .sent),
        ]))

        relay.send(current)
    }
}

