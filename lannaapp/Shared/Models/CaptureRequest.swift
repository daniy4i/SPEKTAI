import Foundation

enum CaptureActionType {
    case listen
    case watch
}

struct CaptureRequest: Equatable {
    let id: UUID
    let conversationId: String
    let type: CaptureActionType
}
