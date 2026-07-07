// Adapté de NotchDrop (github.com/Lakr233/NotchDrop, licence MIT).
import AppKit
import Combine

final class EventMonitor {
    private var globalMonitor: AnyObject?
    private var localMonitor: AnyObject?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit { stop() }

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) as AnyObject?
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handler(event)
            return event
        } as AnyObject?
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        globalMonitor = nil
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        localMonitor = nil
    }
}

// Flux d'événements globaux partagés (souris).
@MainActor
final class EventMonitors {
    static let shared = EventMonitors()

    private var mouseMoveEvent: EventMonitor!
    private var mouseDownEvent: EventMonitor!
    private var mouseDragEvent: EventMonitor!

    let mouseLocation = CurrentValueSubject<NSPoint, Never>(.zero)
    let mouseDown = PassthroughSubject<Void, Never>()
    let mouseDraggingFile = PassthroughSubject<Void, Never>()

    private init() {
        mouseMoveEvent = EventMonitor(mask: .mouseMoved) { [weak self] _ in
            self?.mouseLocation.send(NSEvent.mouseLocation)
        }
        mouseMoveEvent.start()

        mouseDownEvent = EventMonitor(mask: .leftMouseDown) { [weak self] _ in
            self?.mouseDown.send()
        }
        mouseDownEvent.start()

        mouseDragEvent = EventMonitor(mask: .leftMouseDragged) { [weak self] _ in
            self?.mouseDraggingFile.send()
        }
        mouseDragEvent.start()
    }
}
