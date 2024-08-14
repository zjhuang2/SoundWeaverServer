//
//  AudioSessionManager.swift
//  SoundWeaverServer
//
//  Created by Jeremy Huang on 8/14/24.
//

import Foundation
import AVFoundation

class AudioSessionManager {
    static let shared = AudioSessionManager()
    private let audioSession = AVAudioSession.sharedInstance()

    private init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.allowBluetooth])
            try audioSession.setActive(true)
//            if #available(visionOS 1.0, *) {
//                let availableDataSources = audioSession.availableInputs?.first?.dataSources
//                if let omniDirectionalSource = availableDataSources?.first(where: {$0.preferredPolarPattern == .omnidirectional}) {
//                    try audioSession.setInputDataSource(omniDirectionalSource)
//                }
//            }
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func stopAudioSession() {
        autoreleasepool {
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setActive(false)
        }
    }
}
