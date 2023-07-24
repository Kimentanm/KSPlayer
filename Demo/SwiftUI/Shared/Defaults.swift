//
//  Defaults.swift
//  TracyPlayer
//
//  Created by kintan on 2023/7/21.
//

import Foundation
import KSPlayer
import SwiftUI

public class Defaults: ObservableObject {
    @AppStorage("showRecentPlayList") public var showRecentPlayList = false
    @AppStorage("isUseAudioRenderer") public var isUseAudioRenderer = KSOptions.isUseAudioRenderer {
        didSet {
            KSOptions.isUseAudioRenderer = isUseAudioRenderer
        }
    }

    @AppStorage("hardwareDecode") public var hardwareDecode = KSOptions.hardwareDecode {
        didSet {
            KSOptions.hardwareDecode = hardwareDecode
        }
    }

    @AppStorage("isUseDisplayLayer") public var isUseDisplayLayer = MEOptions.isUseDisplayLayer {
        didSet {
            MEOptions.isUseDisplayLayer = isUseDisplayLayer
        }
    }

    @AppStorage("preferredForwardBufferDuration") public var preferredForwardBufferDuration = KSOptions.preferredForwardBufferDuration {
        didSet {
            KSOptions.preferredForwardBufferDuration = preferredForwardBufferDuration
        }
    }

    @AppStorage("maxBufferDuration") public var maxBufferDuration = KSOptions.maxBufferDuration {
        didSet {
            KSOptions.maxBufferDuration = maxBufferDuration
        }
    }

    @AppStorage("isLoopPlay") public var isLoopPlay = KSOptions.isLoopPlay {
        didSet {
            KSOptions.isLoopPlay = isLoopPlay
        }
    }

    @AppStorage("canBackgroundPlay") public var canBackgroundPlay = true {
        didSet {
            KSOptions.canBackgroundPlay = canBackgroundPlay
        }
    }

    @AppStorage("isAutoPlay") public var isAutoPlay = true {
        didSet {
            KSOptions.isAutoPlay = isAutoPlay
        }
    }

    @AppStorage("isSecondOpen") public var isSecondOpen = true {
        didSet {
            KSOptions.isSecondOpen = isSecondOpen
        }
    }

    @AppStorage("isAccurateSeek") public var isAccurateSeek = true {
        didSet {
            KSOptions.isAccurateSeek = isAccurateSeek
        }
    }

    @AppStorage("isPipPopViewController") public var isPipPopViewController = true {
        didSet {
            KSOptions.isPipPopViewController = isPipPopViewController
        }
    }

    @AppStorage("textFontSize") public var textFontSize = SubtitleModel.textFontSize {
        didSet {
            SubtitleModel.textFontSize = textFontSize
        }
    }

    @AppStorage("textBold") public var textBold = SubtitleModel.textBold {
        didSet {
            SubtitleModel.textBold = textBold
        }
    }

    @AppStorage("textItalic") public var textItalic = SubtitleModel.textItalic {
        didSet {
            SubtitleModel.textItalic = textItalic
        }
    }

    @AppStorage("textColor") public var textColor = SubtitleModel.textColor {
        didSet {
            SubtitleModel.textColor = textColor
        }
    }

    @AppStorage("textBackgroundColor") public var textBackgroundColor = SubtitleModel.textBackgroundColor {
        didSet {
            SubtitleModel.textBackgroundColor = textBackgroundColor
        }
    }

    @AppStorage("textXAlign") public var textXAlign = SubtitleModel.textXAlign {
        didSet {
            SubtitleModel.textXAlign = textXAlign
        }
    }

    @AppStorage("textYAlign") public var textYAlign = SubtitleModel.textYAlign {
        didSet {
            SubtitleModel.textYAlign = textYAlign
        }
    }

    @AppStorage("textXMargin") public var textXMargin = SubtitleModel.textXMargin {
        didSet {
            SubtitleModel.textXMargin = textXMargin
        }
    }

    @AppStorage("textYMargin") public var textYMargin = SubtitleModel.textYMargin {
        didSet {
            SubtitleModel.textYMargin = textYMargin
        }
    }

    public static let shared = Defaults()
    private init() {
        KSOptions.isUseAudioRenderer = isUseAudioRenderer
        KSOptions.hardwareDecode = hardwareDecode
        MEOptions.isUseDisplayLayer = isUseDisplayLayer
        SubtitleModel.textFontSize = textFontSize
        SubtitleModel.textBold = textBold
        SubtitleModel.textItalic = textItalic
        SubtitleModel.textColor = textColor
        SubtitleModel.textBackgroundColor = textBackgroundColor
        SubtitleModel.textXAlign = textXAlign
        SubtitleModel.textYAlign = textYAlign
        SubtitleModel.textXMargin = textXMargin
        SubtitleModel.textYMargin = textYMargin
        KSOptions.preferredForwardBufferDuration = preferredForwardBufferDuration
        KSOptions.maxBufferDuration = maxBufferDuration
        KSOptions.isLoopPlay = isLoopPlay
        KSOptions.canBackgroundPlay = canBackgroundPlay
        KSOptions.isAutoPlay = isAutoPlay
        KSOptions.isSecondOpen = isSecondOpen
        KSOptions.isAccurateSeek = isAccurateSeek
        KSOptions.isPipPopViewController = isPipPopViewController
    }
}

@propertyWrapper
public struct Default<T>: DynamicProperty {
    @ObservedObject private var defaults: Defaults
    private let keyPath: ReferenceWritableKeyPath<Defaults, T>
    public init(_ keyPath: ReferenceWritableKeyPath<Defaults, T>, defaults: Defaults = .shared) {
        self.keyPath = keyPath
        self.defaults = defaults
    }

    public var wrappedValue: T {
        get { defaults[keyPath: keyPath] }
        nonmutating set { defaults[keyPath: keyPath] = newValue }
    }

    public var projectedValue: Binding<T> {
        Binding(
            get: { defaults[keyPath: keyPath] },
            set: { value in
                defaults[keyPath: keyPath] = value
            }
        )
    }
}
