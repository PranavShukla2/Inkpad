//
//  Recording.swift
//  Inkpad
//

import Foundation
import SwiftData

@Model
final class Recording {
    var createdAt: Date
    var duration: Double
    @Attribute(.externalStorage) var audioData: Data
    var notebook: Notebook?

    init(audioData: Data, duration: Double, createdAt: Date = .now) {
        self.audioData = audioData
        self.duration = duration
        self.createdAt = createdAt
    }
}
