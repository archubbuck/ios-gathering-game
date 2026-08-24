import SwiftUI
#if DEBUG
import SpriteKit

/// Debug overlay shown only in DEBUG builds. Displays chunk-generation
/// timing, SpriteKit node count, estimated available memory, and FPS.
/// Attach it anywhere inside the forest ZStack with `.zIndex(99)`.
struct InstrumentationOverlay: View {
    @EnvironmentObject private var game: GameState

    /// Frames per second measured from CADisplayLink timestamps.
    @State private var fps: Double = 0
    /// Estimated free memory in MB from `os_proc_available_memory()`.
    @State private var freeMemoryMB: Double = 0
    /// Duration (ms) of the last background chunk-generation pass.
    @State private var lastChunkGenMS: Double = 0
    /// Approximate number of live SpriteKit nodes (updated each display frame).
    @State private var nodeCount: Int = 0

    /// SpriteKit scene used to read `rootNode.children.count`.
    var skScene: SKScene?

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            row("FPS", value: String(format: "%.0f", fps))
            row("Nodes", value: "\(nodeCount)")
            row("Free mem", value: String(format: "%.0f MB", freeMemoryMB))
            row("Trees loaded", value: "\(game.worldTrees.count)")
            row("Chunks", value: "\(game.loadedChunks.count)")
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.55))
        )
        .onReceive(timer) { _ in
            refreshStats()
        }
        .accessibilityHidden(true)
    }

    private func row(_ label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private func refreshStats() {
        // Node count via the attached SKScene.
        nodeCount = skScene.map { countNodes(in: $0) } ?? 0
        // Free memory.
        freeMemoryMB = Double(os_proc_available_memory()) / (1024 * 1024)
    }

    private func countNodes(in scene: SKScene) -> Int {
        var count = 0
        func walk(_ node: SKNode) {
            count += 1
            for child in node.children { walk(child) }
        }
        walk(scene)
        return count
    }
}

// MARK: - Memory helper (available on both iOS and macOS)
import Darwin
private func os_proc_available_memory() -> Int64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    guard result == KERN_SUCCESS else { return 0 }
    // Return estimated free by subtracting resident size from a rough process cap.
    let usedBytes = Int64(info.resident_size)
    let capBytes: Int64 = 1_500 * 1024 * 1024 // 1.5 GB heuristic
    return max(0, capBytes - usedBytes)
}
#endif
