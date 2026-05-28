//
//  OverlayColorTheme.swift
//  alarm
//

import AppKit
import SwiftUI

struct CodableColor: Equatable, Codable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, opacity: opacity)
    }

    init(_ color: Color) {
        let ns = NSColor(color)
        guard let rgb = ns.usingColorSpace(.sRGB) else {
            red = 1
            green = 1
            blue = 1
            opacity = 1
            return
        }
        red = Double(rgb.redComponent)
        green = Double(rgb.greenComponent)
        blue = Double(rgb.blueComponent)
        opacity = Double(rgb.alphaComponent)
    }

    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

struct OverlayColorPalette: Equatable, Codable {
    var usesSystemAppearance: Bool = false
    var trackRing: CodableColor
    var progressRing: CodableColor
    var progressRingFiring: CodableColor
    var countdown: CodableColor
    var countdownFiring: CodableColor
    var subtitle: CodableColor
    var controlLabel: CodableColor
    var controlLabelFiring: CodableColor
    var statusLabel: CodableColor
    var countdownShadow: Bool = false

    enum CodingKeys: String, CodingKey {
        case usesSystemAppearance
        case trackRing
        case progressRing
        case progressRingFiring
        case countdown
        case countdownFiring
        case subtitle
        case controlLabel
        case controlLabelFiring
        case statusLabel
        case countdownShadow
    }

    init(
        usesSystemAppearance: Bool = false,
        trackRing: CodableColor,
        progressRing: CodableColor,
        progressRingFiring: CodableColor,
        countdown: CodableColor,
        countdownFiring: CodableColor,
        subtitle: CodableColor,
        controlLabel: CodableColor,
        controlLabelFiring: CodableColor,
        statusLabel: CodableColor,
        countdownShadow: Bool = false
    ) {
        self.usesSystemAppearance = usesSystemAppearance
        self.trackRing = trackRing
        self.progressRing = progressRing
        self.progressRingFiring = progressRingFiring
        self.countdown = countdown
        self.countdownFiring = countdownFiring
        self.subtitle = subtitle
        self.controlLabel = controlLabel
        self.controlLabelFiring = controlLabelFiring
        self.statusLabel = statusLabel
        self.countdownShadow = countdownShadow
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        usesSystemAppearance = try c.decodeIfPresent(Bool.self, forKey: .usesSystemAppearance) ?? false
        trackRing = try c.decode(CodableColor.self, forKey: .trackRing)
        progressRing = try c.decode(CodableColor.self, forKey: .progressRing)
        progressRingFiring = try c.decode(CodableColor.self, forKey: .progressRingFiring)
        countdown = try c.decode(CodableColor.self, forKey: .countdown)
        countdownFiring = try c.decode(CodableColor.self, forKey: .countdownFiring)
        subtitle = try c.decode(CodableColor.self, forKey: .subtitle)
        statusLabel = try c.decode(CodableColor.self, forKey: .statusLabel)
        controlLabel = try c.decodeIfPresent(CodableColor.self, forKey: .controlLabel) ?? subtitle
        controlLabelFiring = try c.decodeIfPresent(CodableColor.self, forKey: .controlLabelFiring)
            ?? progressRingFiring
        countdownShadow = try c.decodeIfPresent(Bool.self, forKey: .countdownShadow) ?? false
    }

    static let neutralTrack = CodableColor(hex: 0x808080, opacity: 0.32)

    static func resolved(preset: OverlayThemePreset, custom: OverlayColorPalette?) -> OverlayColorPalette {
        switch preset {
        case .custom:
            return custom ?? .moonlight
        default:
            return preset.palette
        }
    }

    /// 进度环 / 倒计时 / 菜单按钮 可分别指定
    static func themed(
        progress: UInt32,
        progressFiring: UInt32,
        countdown: UInt32,
        countdownFiring: UInt32? = nil,
        subtitle: UInt32,
        control: UInt32,
        controlFiring: UInt32? = nil,
        status: UInt32 = 0x9CA3AF,
        track: CodableColor = neutralTrack,
        countdownShadow: Bool = false
    ) -> OverlayColorPalette {
        OverlayColorPalette(
            trackRing: track,
            progressRing: CodableColor(hex: progress),
            progressRingFiring: CodableColor(hex: progressFiring),
            countdown: CodableColor(hex: countdown),
            countdownFiring: CodableColor(hex: countdownFiring ?? countdown),
            subtitle: CodableColor(hex: subtitle),
            controlLabel: CodableColor(hex: control),
            controlLabelFiring: CodableColor(hex: controlFiring ?? control),
            statusLabel: CodableColor(hex: status),
            countdownShadow: countdownShadow
        )
    }

    static let system = OverlayColorPalette(
        usesSystemAppearance: true,
        trackRing: CodableColor(hex: 0x000000, opacity: 0.12),
        progressRing: CodableColor(hex: 0x007AFF),
        progressRingFiring: CodableColor(hex: 0xFF9500),
        countdown: CodableColor(hex: 0x000000),
        countdownFiring: CodableColor(hex: 0xFF9500),
        subtitle: CodableColor(hex: 0x8E8E93),
        controlLabel: CodableColor(hex: 0x8E8E93),
        controlLabelFiring: CodableColor(hex: 0xFF9500),
        statusLabel: CodableColor(hex: 0x8E8E93)
    )

    static let moonlight = themed(
        progress: 0xFFFFFF, progressFiring: 0xFF9F0A,
        countdown: 0xF5F5F5, countdownFiring: 0xFF9F0A,
        subtitle: 0x9CA3AF, control: 0xCBD5E1, controlFiring: 0xFCD34D,
        countdownShadow: true
    )

    static let ocean = themed(
        progress: 0x3B82F6, progressFiring: 0x2563EB,
        countdown: 0x60A5FA, countdownFiring: 0x2563EB,
        subtitle: 0x93C5FD, control: 0xBFDBFE,
        controlFiring: 0x1D4ED8,
        track: CodableColor(hex: 0x3B82F6, opacity: 0.22)
    )

    static let pearl = themed(
        progress: 0x94A3B8, progressFiring: 0x64748B,
        countdown: 0xE2E8F0, countdownFiring: 0xF8FAFC,
        subtitle: 0x94A3B8, control: 0x64748B, controlFiring: 0x475569,
        countdownShadow: true
    )

    static let hudCyan = themed(
        progress: 0x22D3EE, progressFiring: 0x06B6D4,
        countdown: 0xF9FAFB, countdownFiring: 0x22D3EE,
        subtitle: 0x9CA3AF, control: 0x67E8F9, controlFiring: 0x0891B2,
        countdownShadow: true
    )

    static let frost = themed(
        progress: 0x67E8F9, progressFiring: 0x0891B2,
        countdown: 0xCFFAFE, countdownFiring: 0x22D3EE,
        subtitle: 0xA5F3FC, control: 0x94A3B8, controlFiring: 0x0E7490,
        countdownShadow: true
    )

    static let ink = themed(
        progress: 0x374151, progressFiring: 0x1F2937,
        countdown: 0x1F2937, countdownFiring: 0x111827,
        subtitle: 0x6B7280, control: 0x9CA3AF, controlFiring: 0x4B5563
    )

    static let slate = themed(
        progress: 0x64748B, progressFiring: 0x475569,
        countdown: 0x334155, countdownFiring: 0x1E293B,
        subtitle: 0x64748B, control: 0x94A3B8, controlFiring: 0x334155,
        status: 0x64748B
    )

    static let sky = themed(
        progress: 0x38BDF8, progressFiring: 0x0284C7,
        countdown: 0xBAE6FD, countdownFiring: 0x0EA5E9,
        subtitle: 0x7DD3FC, control: 0x64748B, controlFiring: 0x0369A1,
        countdownShadow: true
    )

    static let teal = themed(
        progress: 0x2DD4BF, progressFiring: 0x0D9488,
        countdown: 0x99F6E4, countdownFiring: 0x14B8A6,
        subtitle: 0x5EEAD4, control: 0x6B7280, controlFiring: 0x0F766E
    )

    static let forest = themed(
        progress: 0x34D399, progressFiring: 0x10B981,
        countdown: 0xA7F3D0, countdownFiring: 0x10B981,
        subtitle: 0x6EE7B7, control: 0x78716C, controlFiring: 0x047857,
        countdownShadow: true
    )

    static let jade = themed(
        progress: 0x10B981, progressFiring: 0x059669,
        countdown: 0x6EE7B7, countdownFiring: 0x059669,
        subtitle: 0x34D399, control: 0x9CA3AF, controlFiring: 0x065F46
    )

    static let lime = themed(
        progress: 0xA3E635, progressFiring: 0x65A30D,
        countdown: 0xD9F99D, countdownFiring: 0x84CC16,
        subtitle: 0x84CC16, control: 0x78716C, controlFiring: 0x4D7C0F,
        countdownShadow: true
    )

    static let amber = themed(
        progress: 0xFBBF24, progressFiring: 0xF59E0B,
        countdown: 0xFDE68A, countdownFiring: 0xF59E0B,
        subtitle: 0xD97706, control: 0x78716C, controlFiring: 0xB45309,
        countdownShadow: true
    )

    static let sand = themed(
        progress: 0xD6B25E, progressFiring: 0xB8860B,
        countdown: 0xE8D5A3, countdownFiring: 0xCA8A04,
        subtitle: 0xA8A29E, control: 0x78716C, controlFiring: 0x92400E,
        countdownShadow: true
    )

    static let sunset = themed(
        progress: 0xF97316, progressFiring: 0xEA580C,
        countdown: 0xFDBA74, countdownFiring: 0xF97316,
        subtitle: 0xFB923C, control: 0x94A3B8, controlFiring: 0xC2410C
    )

    static let copper = themed(
        progress: 0xEA580C, progressFiring: 0xC2410C,
        countdown: 0xFDBA74, countdownFiring: 0xEA580C,
        subtitle: 0xD97706, control: 0x78716C, controlFiring: 0x9A3412
    )

    static let rose = themed(
        progress: 0xF43F5E, progressFiring: 0xE11D48,
        countdown: 0xFDA4AF, countdownFiring: 0xF43F5E,
        subtitle: 0xFB7185, control: 0x9CA3AF, controlFiring: 0xBE123C
    )

    static let cherry = themed(
        progress: 0xEF4444, progressFiring: 0xDC2626,
        countdown: 0xFCA5A5, countdownFiring: 0xEF4444,
        subtitle: 0xF87171, control: 0x6B7280, controlFiring: 0xB91C1C
    )

    static let coral = themed(
        progress: 0xFB7185, progressFiring: 0xE11D48,
        countdown: 0xFDA4AF, countdownFiring: 0xE11D48,
        subtitle: 0x9CA3AF, control: 0xFDBA74, controlFiring: 0xBE123C
    )

    static let violet = themed(
        progress: 0xA78BFA, progressFiring: 0x8B5CF6,
        countdown: 0xC4B5FD, countdownFiring: 0x8B5CF6,
        subtitle: 0x9CA3AF, control: 0xDDD6FE, controlFiring: 0x6D28D9
    )

    static let orchid = themed(
        progress: 0xC084FC, progressFiring: 0x9333EA,
        countdown: 0xE9D5FF, countdownFiring: 0xA855F7,
        subtitle: 0xD8B4FE, control: 0x94A3B8, controlFiring: 0x7E22CE,
        countdownShadow: true
    )

    static let magenta = themed(
        progress: 0xE879F9, progressFiring: 0xC026D3,
        countdown: 0xF5D0FE, countdownFiring: 0xD946EF,
        subtitle: 0xD8B4FE, control: 0x9CA3AF, controlFiring: 0xA21CAF,
        countdownShadow: true
    )

    static let indigo = themed(
        progress: 0x6366F1, progressFiring: 0x4F46E5,
        countdown: 0xA5B4FC, countdownFiring: 0x6366F1,
        subtitle: 0x818CF8, control: 0x94A3B8, controlFiring: 0x4338CA
    )

    // MARK: - 三色分离主题（环 / 时钟 / 菜单各不同）

    static let neon = themed(
        progress: 0x22D3EE, progressFiring: 0x06B6D4,
        countdown: 0xF8FAFC, countdownFiring: 0xFFFFFF,
        subtitle: 0xA5F3FC, control: 0xF472B6, controlFiring: 0xEC4899,
        countdownShadow: true
    )

    static let terminal = themed(
        progress: 0x39FF14, progressFiring: 0x22C55E,
        countdown: 0xBBF7D0, countdownFiring: 0x4ADE80,
        subtitle: 0x86EFAC, control: 0xFBBF24, controlFiring: 0xF59E0B,
        countdownShadow: true
    )

    static let sunrise = themed(
        progress: 0xF97316, progressFiring: 0xEA580C,
        countdown: 0xFDE047, countdownFiring: 0xFACC15,
        subtitle: 0xFDBA74, control: 0xFB7185, controlFiring: 0xF43F5E,
        countdownShadow: true
    )

    static let midnight = themed(
        progress: 0x3B82F6, progressFiring: 0x1D4ED8,
        countdown: 0xE2E8F0, countdownFiring: 0xF1F5F9,
        subtitle: 0x94A3B8, control: 0xC4B5FD, controlFiring: 0x8B5CF6,
        countdownShadow: true
    )

    static let espresso = themed(
        progress: 0x92400E, progressFiring: 0x78350F,
        countdown: 0xF5F5DC, countdownFiring: 0xFFEDD5,
        subtitle: 0xD6B25E, control: 0xA8A29E, controlFiring: 0xB45309,
        countdownShadow: true
    )

    static let glacier = themed(
        progress: 0x7DD3FC, progressFiring: 0x0284C7,
        countdown: 0xF0F9FF, countdownFiring: 0xE0F2FE,
        subtitle: 0xBAE6FD, control: 0x64748B, controlFiring: 0x475569,
        countdownShadow: true
    )

    static let papaya = themed(
        progress: 0xFB923C, progressFiring: 0xEA580C,
        countdown: 0xFED7AA, countdownFiring: 0xFDBA74,
        subtitle: 0xFDBA74, control: 0x84CC16, controlFiring: 0x65A30D
    )

    static let electric = themed(
        progress: 0x8B5CF6, progressFiring: 0x6D28D9,
        countdown: 0xFAFAFA, countdownFiring: 0xFFFFFF,
        subtitle: 0xC4B5FD, control: 0xA3E635, controlFiring: 0x84CC16,
        countdownShadow: true
    )

    static let rust = themed(
        progress: 0xB45309, progressFiring: 0x92400E,
        countdown: 0xE7C9A9, countdownFiring: 0xD6B25E,
        subtitle: 0xD97706, control: 0x78716C, controlFiring: 0x57534E
    )

    static let aurora = themed(
        progress: 0x34D399, progressFiring: 0x059669,
        countdown: 0xC4B5FD, countdownFiring: 0xA78BFA,
        subtitle: 0x6EE7B7, control: 0x22D3EE, controlFiring: 0x0891B2,
        countdownShadow: true
    )

    static let citrus = themed(
        progress: 0xFACC15, progressFiring: 0xEAB308,
        countdown: 0x1F2937, countdownFiring: 0x111827,
        subtitle: 0xCA8A04, control: 0xEA580C, controlFiring: 0xC2410C
    )

    static let lagoon = themed(
        progress: 0x0EA5E9, progressFiring: 0x0369A1,
        countdown: 0x67E8F9, countdownFiring: 0x22D3EE,
        subtitle: 0x7DD3FC, control: 0x94A3B8, controlFiring: 0x64748B
    )

    static let sakura = themed(
        progress: 0xF9A8D4, progressFiring: 0xEC4899,
        countdown: 0xFDF2F8, countdownFiring: 0xFBCFE8,
        subtitle: 0xF9A8D4, control: 0x86EFAC, controlFiring: 0x22C55E,
        countdownShadow: true
    )

    static let graphite = themed(
        progress: 0x52525B, progressFiring: 0x3F3F46,
        countdown: 0xD4D4D8, countdownFiring: 0xFAFAFA,
        subtitle: 0xA1A1AA, control: 0x71717A, controlFiring: 0x27272A,
        countdownShadow: true
    )

    static let ember = themed(
        progress: 0xEF4444, progressFiring: 0xB91C1C,
        countdown: 0xFEF3C7, countdownFiring: 0xFDE68A,
        subtitle: 0xFCA5A5, control: 0x94A3B8, controlFiring: 0x7F1D1D,
        countdownShadow: true
    )

    static let mintCream = themed(
        progress: 0x6EE7B7, progressFiring: 0x34D399,
        countdown: 0x134E4A, countdownFiring: 0x115E59,
        subtitle: 0x5EEAD4, control: 0xF472B6, controlFiring: 0xDB2777
    )

    static let royal = themed(
        progress: 0x1E40AF, progressFiring: 0x1E3A8A,
        countdown: 0xFCD34D, countdownFiring: 0xFBBF24,
        subtitle: 0x93C5FD, control: 0xE2E8F0, controlFiring: 0xCBD5E1,
        countdownShadow: true
    )

    static let defaultCustom = themed(
        progress: 0x3B82F6, progressFiring: 0xFF9F0A,
        countdown: 0xF5F5F5, countdownFiring: 0xFF9F0A,
        subtitle: 0x9CA3AF, control: 0xCBD5E1, controlFiring: 0xFF9F0A,
        countdownShadow: true
    )
}

enum OverlayThemePreset: String, Codable, CaseIterable, Identifiable {
    case system
    case moonlight
    case ocean
    case pearl
    case hudCyan
    case frost
    case ink
    case slate
    case sky
    case teal
    case forest
    case jade
    case lime
    case amber
    case sand
    case sunset
    case copper
    case rose
    case cherry
    case coral
    case violet
    case orchid
    case magenta
    case indigo
    case neon
    case terminal
    case sunrise
    case midnight
    case espresso
    case glacier
    case papaya
    case electric
    case rust
    case aurora
    case citrus
    case lagoon
    case sakura
    case graphite
    case ember
    case mintCream
    case royal
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "系统默认"
        case .moonlight: "月白"
        case .ocean: "海洋蓝"
        case .pearl: "珠灰"
        case .hudCyan: "青霓"
        case .frost: "霜青"
        case .ink: "墨韵"
        case .slate: "岩灰"
        case .sky: "天蓝"
        case .teal: "碧涛"
        case .forest: "苍绿"
        case .jade: "翠玉"
        case .lime: "柠光"
        case .amber: "琥珀"
        case .sand: "沙金"
        case .sunset: "暮橙"
        case .copper: "赤铜"
        case .rose: "绯露"
        case .cherry: "樱红"
        case .coral: "珊瑚"
        case .violet: "紫雾"
        case .orchid: "兰紫"
        case .magenta: "玫影"
        case .indigo: "靛青"
        case .neon: "霓虹"
        case .terminal: "终端"
        case .sunrise: "朝霞"
        case .midnight: "午夜"
        case .espresso: "浓缩"
        case .glacier: "冰川"
        case .papaya: "木瓜"
        case .electric: "电光"
        case .rust: "铁锈"
        case .aurora: "极光"
        case .citrus: "柑橘"
        case .lagoon: "泻湖"
        case .sakura: "樱吹"
        case .graphite: "石墨"
        case .ember: "余烬"
        case .mintCream: "薄荷"
        case .royal: "皇家"
        case .custom: "自定义"
        }
    }

    var palette: OverlayColorPalette {
        switch self {
        case .system: .system
        case .moonlight: .moonlight
        case .ocean: .ocean
        case .pearl: .pearl
        case .hudCyan: .hudCyan
        case .frost: .frost
        case .ink: .ink
        case .slate: .slate
        case .sky: .sky
        case .teal: .teal
        case .forest: .forest
        case .jade: .jade
        case .lime: .lime
        case .amber: .amber
        case .sand: .sand
        case .sunset: .sunset
        case .copper: .copper
        case .rose: .rose
        case .cherry: .cherry
        case .coral: .coral
        case .violet: .violet
        case .orchid: .orchid
        case .magenta: .magenta
        case .indigo: .indigo
        case .neon: .neon
        case .terminal: .terminal
        case .sunrise: .sunrise
        case .midnight: .midnight
        case .espresso: .espresso
        case .glacier: .glacier
        case .papaya: .papaya
        case .electric: .electric
        case .rust: .rust
        case .aurora: .aurora
        case .citrus: .citrus
        case .lagoon: .lagoon
        case .sakura: .sakura
        case .graphite: .graphite
        case .ember: .ember
        case .mintCream: .mintCream
        case .royal: .royal
        case .custom: .defaultCustom
        }
    }
}

extension ReminderSettings {
    var resolvedOverlayPalette: OverlayColorPalette {
        OverlayColorPalette.resolved(preset: overlayThemePreset, custom: customOverlayPalette)
    }
}
