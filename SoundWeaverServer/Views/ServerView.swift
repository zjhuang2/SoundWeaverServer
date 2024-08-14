//
//  ServerView.swift
//  SoundWeaverServer
//
//  Created by Jeremy Huang on 8/14/24.
//

import SwiftUI

struct ServerView: View {
    
    @State var isSensing = false
    
    @State private var data: [String] = []
    @State private var newItem: String = ""
    
    var classificationState = AudioClassificationState()
    @State var classificationConfig = AudioClassificationConfiguration()
    
    var body: some View {
        VStack {
            Spacer()
            Button(action: {
                if !isSensing {
                    classificationState.restartDetection(config: classificationConfig)
                    startTranscribing()
                    isSensing.toggle()
                } else {
                    AudioClassifier.singleton.stopSoundClassification()
                    stopTranscribing()
                    isSensing.toggle()
                }
            }) {
                Text(isSensing ? "Stop Streaming" : "Start Streaming")
            }
            .frame(width: 200, height: 60)
            .background(Color.pink)
            .foregroundColor(.white)
            .cornerRadius(10)
//            TranscriptView()
        }
    }
    
    
    private func startTranscribing() {
        SpeechRecognizer.shared.startTranscribing()
    }

    private func stopTranscribing() {
        SpeechRecognizer.shared.stopTranscribing()
    }
}

#Preview {
    ServerView()
}
