//
//  PreferencesStore.swift
//  lannaapp
//
//  Single source of truth for all SPEKT AI user preferences.
//  @Published properties → any observing view re-renders on change.
//  Writes through to UserDefaults immediately on set.
//
//  Keys are shared with the old @AppStorage in PreferencesContentView
//  so existing stored values are picked up automatically.
//

import Foundation
import Combine

// MARK: - Defaults

private enum PrefKey {
    static let voiceTone   = "spekt_pref_voice_tone"
    static let style       = "spekt_pref_style"
    static let format      = "spekt_pref_format"
    static let language    = "spekt_pref_language"
    static let detailLevel = "spekt_pref_detail_level"
}

private enum PrefDefault {
    static let voiceTone   = "Direct & concise"
    static let style       = "Action-first"
    static let format      = "Bullet points"
    static let language    = "English (US)"
    static let detailLevel = "High signal"
}

// MARK: - Store

final class PreferencesStore: ObservableObject {

    static let shared = PreferencesStore()

    private let ud = UserDefaults.standard

    @Published var voiceTone  : String { didSet { ud.set(voiceTone,   forKey: PrefKey.voiceTone) } }
    @Published var style      : String { didSet { ud.set(style,        forKey: PrefKey.style) } }
    @Published var format     : String { didSet { ud.set(format,       forKey: PrefKey.format) } }
    @Published var language   : String { didSet { ud.set(language,     forKey: PrefKey.language) } }
    @Published var detailLevel: String { didSet { ud.set(detailLevel,  forKey: PrefKey.detailLevel) } }

    private init() {
        voiceTone   = ud.string(forKey: PrefKey.voiceTone)   ?? PrefDefault.voiceTone
        style       = ud.string(forKey: PrefKey.style)        ?? PrefDefault.style
        format      = ud.string(forKey: PrefKey.format)       ?? PrefDefault.format
        language    = ud.string(forKey: PrefKey.language)     ?? PrefDefault.language
        detailLevel = ud.string(forKey: PrefKey.detailLevel)  ?? PrefDefault.detailLevel
    }

    // MARK: - Computed

    var isDefault: Bool {
        voiceTone   == PrefDefault.voiceTone   &&
        style       == PrefDefault.style       &&
        format      == PrefDefault.format      &&
        language    == PrefDefault.language    &&
        detailLevel == PrefDefault.detailLevel
    }

    /// Full one-liner shown in the Voice screen context strip.
    var contextSummary: String {
        "\(voiceTone)  ·  \(format)  ·  \(detailLevel)"
    }

    /// Short summary shown in the Signal card collapsed subtitle.
    var collapsedSummary: String {
        let f = format.components(separatedBy: " ").first ?? format
        return "\(voiceTone) · \(f)"
    }

    // MARK: - Actions

    func resetToDefaults() {
        voiceTone   = PrefDefault.voiceTone
        style       = PrefDefault.style
        format      = PrefDefault.format
        language    = PrefDefault.language
        detailLevel = PrefDefault.detailLevel
    }
}
