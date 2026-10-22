// bomberfish
// PerformanceMonitor.swift – CAPerfHudSwift
// created on 2026-10-22

import Combine
import Foundation
import QuartzCore

/// Collects real performance data inside the app process.
///
/// Note: only data readable from a normal sandboxed app is available here.
/// GPU counters and other internal metrics shown by the system HUD live in
/// the render-server / SpringBoard process and cannot be read by an app.
final class PerformanceMonitor: NSObject, ObservableObject {
    static let shared = PerformanceMonitor()

    /// Frames per second measured with CADisplayLink.
    @Published private(set) var fps: Double = 0
    /// Physical memory footprint of this app in megabytes.
    @Published private(set) var memoryMB: Double = 0

    private var displayLink: CADisplayLink?
    private var frameCount = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var statsTimer: Timer?
    private var running = false

    private override init() {
        super.init()
    }

    // MARK: - Lifecycle

    func start() {
        guard !running else { return }
        running = true

        let link = CADisplayLink(target: self, selector: #selector(displayLinkTick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link

        let timer = Timer(timeInterval: 1.0, target: self, selector: #selector(refreshStats), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        statsTimer = timer
    }

    func stop() {
        running = false
        displayLink?.invalidate()
        displayLink = nil
        statsTimer?.invalidate()
        statsTimer = nil
        frameCount = 0
        lastTimestamp = 0
    }

    // MARK: - Sampling

    @objc private func displayLinkTick(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            frameCount = 0
            return
        }
        frameCount += 1
        let elapsed = link.timestamp - lastTimestamp
        if elapsed >= 0.5 {
            fps = Double(frameCount) / elapsed
            frameCount = 0
            lastTimestamp = link.timestamp
        }
    }

    @objc private func refreshStats() {
        memoryMB = Self.memoryFootprintMB()
    }

    // MARK: - Memory

    private static func memoryFootprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / 1024.0 / 1024.0
    }
}
