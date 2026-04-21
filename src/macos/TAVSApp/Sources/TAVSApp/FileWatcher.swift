import Foundation

protocol FileWatcherProtocol: AnyObject {
    func start(watching directory: URL, onChange: @escaping () -> Void)
    func stop()
}

final class FileWatcher: FileWatcherProtocol {
    private let debounceInterval: TimeInterval
    private var source: DispatchSourceFileSystemObject?
    private var debounceWorkItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.cstelmach.tavs.filewatcher")

    init(debounceInterval: TimeInterval = 0.1) {
        self.debounceInterval = debounceInterval
    }

    func start(watching directory: URL, onChange: @escaping () -> Void) {
        stop()

        let fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.debounceWorkItem?.cancel()
            let work = DispatchWorkItem {
                onChange()
            }
            self.debounceWorkItem = work
            self.queue.asyncAfter(deadline: .now() + self.debounceInterval, execute: work)
        }

        source.setCancelHandler {
            close(fd)
        }

        self.source = source
        source.resume()
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
