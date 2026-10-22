// bomberfish
// HudOverlayView.swift – CAPerfHudSwift
// created on 2026-10-22

import SwiftUI

/// A self-drawn HUD that honours every appearance setting.
///
/// This is *not* the system Core Animation HUD: an app cannot draw above other
/// apps, so this overlay is only visible while CAPerfHudSwift is on screen.
/// Data is sampled inside this process (FPS / memory).
struct HudOverlayView: View {
    @EnvironmentObject var settings: HudSettings
    @EnvironmentObject var loc: LocalizationManager
    @ObservedObject var monitor = PerformanceMonitor.shared

    /// Preview mode is not draggable and is laid out inside a settings row.
    var isPreview: Bool = false

    @State private var dragStart: CGPoint?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            metricRow(
                label: loc.string(.overlayFPS),
                value: String(format: "%.0f", monitor.fps)
            )
            metricRow(
                label: loc.string(.overlayMemory),
                value: String(format: "%.0f MB", monitor.memoryMB)
            )
        }
        .font(.system(size: settings.fontSize, weight: .semibold, design: .monospaced))
        .foregroundColor(settings.textColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: settings.windowWidth, height: settings.windowHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
                .fill(settings.bgColor.opacity(settings.backgroundOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
                .strokeBorder(
                    settings.showBorder ? settings.textColor.opacity(0.6) : Color.clear,
                    lineWidth: settings.showBorder ? settings.borderWidth : 0
                )
        )
        .animation(settings.animateChanges ? .easeInOut(duration: 0.2) : nil, value: settings.windowWidth)
        .animation(settings.animateChanges ? .easeInOut(duration: 0.2) : nil, value: settings.windowHeight)
        .animation(settings.animateChanges ? .easeInOut(duration: 0.2) : nil, value: settings.fontSize)
        .animation(settings.animateChanges ? .easeInOut(duration: 0.2) : nil, value: settings.backgroundOpacity)
        .animation(settings.animateChanges ? .easeInOut(duration: 0.2) : nil, value: settings.cornerRadius)
        .animation(settings.animateChanges ? .easeInOut(duration: 0.2) : nil, value: settings.textColorHex)
        .animation(settings.animateChanges ? .easeInOut(duration: 0.2) : nil, value: settings.bgColorHex)
        .gesture(dragGesture, including: isPreview ? GestureMask.none : GestureMask.all)
        .accessibilityElement(children: .combine)
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .opacity(0.75)
            Spacer(minLength: 0)
            Text(value)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStart == nil {
                    dragStart = CGPoint(x: settings.positionX, y: settings.positionY)
                }
                guard let start = dragStart else { return }
                settings.positionX = clamped(start.x + value.translation.width)
                settings.positionY = clamped(start.y + value.translation.height)
            }
            .onEnded { _ in
                dragStart = nil
            }
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, -300), 300)
    }
}

#Preview {
    HudOverlayView(isPreview: true)
        .environmentObject(HudSettings.shared)
        .environmentObject(LocalizationManager.shared)
        .padding()
        .background(Color.gray)
}
