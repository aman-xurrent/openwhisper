import Foundation

@MainActor
final class EngineLoader<Engine> {
    private var make: () throws -> Engine
    private var engine: Engine?
    private var loadTask: Task<Engine, Error>?

    init(make: @escaping () throws -> Engine) {
        self.make = make
    }

    var loaded: Engine? {
        engine
    }

    var isLoading: Bool {
        loadTask != nil
    }

    func preload() {
        _ = load()
    }

    func value() async throws -> Engine {
        if let engine { return engine }
        return try await load().value
    }

    func reset(make newMake: @escaping () throws -> Engine) {
        engine = nil
        loadTask?.cancel()
        loadTask = nil
        make = newMake
    }

    func unload() {
        engine = nil
        loadTask?.cancel()
        loadTask = nil
    }

    private func load() -> Task<Engine, Error> {
        if let loadTask { return loadTask }
        let make = self.make
        let task = Task.detached(priority: .userInitiated) { try make() }
        loadTask = task
        Task { [weak self] in
            let result = try? await task.value
            await MainActor.run {
                guard let self, self.loadTask == task else { return }
                self.engine = result
                self.loadTask = nil
            }
        }
        return task
    }
}
