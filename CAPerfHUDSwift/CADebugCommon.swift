// bomberfish
// CADebugCommon.swift – CAPerfHudSwift
// created on 2023-12-18

import Darwin
import Foundation
import QuartzCore
import SwiftUI

// pretty much a swift rewrite of https://github.com/khanhduytran0/CAPerfHUD/blob/main/Common/CADebugCommon.m

let CA_DEBUG_OPTION_PERF_HUD: Int32 = 0x24
let RLTD_LAZY: Int32 = 0x1
let RLTD_NOW: Int32 = 0x2

// Debug value indices for the perf HUD.
// Only index 1 (the level selector) is documented and honoured by iOS.
// The render server has no setters for font size, position, size, opacity or
// corner radius – these are hardcoded by QuartzCore. Writing unknown debug
// value slots only disturbs the render server (visible as wallpaper flicker).
let HUD_VALUE_INDEX_LEVEL: Int32 = 1

// thanks https://bryce.co/on-device-render-debugging/ for a full swift implementation
typealias getDebugOptType = @convention(c) (
    Int32, Int32) -> Int32

typealias getDebugValType = @convention(c) (
    Int32, Int32) -> Int32

typealias setDebugOptType = @convention(c) (
    Int32, Int32, Int32) -> Void

typealias setDebugValType = @convention(c) (
    Int32, Int32, Int32) -> Void

let CARenderServerGetDebugOption = unsafeBitCast(dlsym(dlopen("/System/Library/Frameworks/QuartzCore.framework/QuartzCore", RLTD_NOW), "CARenderServerGetDebugOption"), to: getDebugOptType.self)
let CARenderServerGetDebugValue = unsafeBitCast(dlsym(dlopen("/System/Library/Frameworks/QuartzCore.framework/QuartzCore", RLTD_NOW), "CARenderServerGetDebugValue"), to: getDebugOptType.self)

let CARenderServerSetDebugOption = unsafeBitCast(dlsym(dlopen("/System/Library/Frameworks/QuartzCore.framework/QuartzCore", RLTD_NOW), "CARenderServerSetDebugOption"), to: setDebugOptType.self)
let CARenderServerSetDebugValue = unsafeBitCast(dlsym(dlopen("/System/Library/Frameworks/QuartzCore.framework/QuartzCore", RLTD_NOW), "CARenderServerSetDebugValue"), to: setDebugOptType.self)

public struct CADebugCommon {
    static let perfHUDLevelNames = ["Off", "Basic", "Backdrop", "Particles", "Full", "Frequencies", "Power", "FPS only", "Display", "Glitches"]
    static func getPerfHUDLevel() -> Int32 {
        if CARenderServerGetDebugOption(0, CA_DEBUG_OPTION_PERF_HUD) == 0 {
            return 0
        }
        return CARenderServerGetDebugValue(0, 1)+1;
    }

    static func setPerfHUDLevel(_ level: Int32) {
        CARenderServerSetDebugOption(0, CA_DEBUG_OPTION_PERF_HUD, level)
        if level > 0 {
            CARenderServerSetDebugValue(0, 1, level-1)
        }
    }
    
    static var perfHUDLevel: Binding<Int32> {
        Binding<Int32>(
            get: { getPerfHUDLevel() },
            set: { setPerfHUDLevel($0) }
        )
    }
}

extension Int32 {
    /// Clamps a Double into the representable range of Int32.
    init(clamping value: Double) {
        if value.isNaN || value.isInfinite {
            self = 0
        } else if value > Double(Int32.max) {
            self = Int32.max
        } else if value < Double(Int32.min) {
            self = Int32.min
        } else {
            self = Int32(value)
        }
    }
}
