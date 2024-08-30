//
//  SpeechRecognizer.swift
//  SoundWeaverServer
//
//  Created by Jeremy Huang on 8/14/24.
//
import Foundation
import SwiftUI
import AVFoundation
import Speech
import Firebase
import FirebaseDatabase

@Observable class SpeechRecognizer: NSObject, SFSpeechRecognizerDelegate, AVAudioRecorderDelegate {
    static let shared = SpeechRecognizer()
    
    private var audioEngine = AVAudioEngine()
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Real Time DB reference
    let databaseRef = Database.database().reference()
    
    var transcriptText: String = ""
//    var isRecording: Bool = false
    
    // Just an indicator for checking microphone access.
    var hasMicrophoneAccess = false
    
    private var timer: Timer? // debounce timer for clearing out captions.
    
    public func startTranscribing() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                self.startSpeechRecognition()
            case .denied, .restricted, .notDetermined:
                self.transcriptText = "Speech recognition authorization was Denied."
            @unknown default:
                fatalError()
            }
        }
    }
    
    private func startSpeechRecognition() {
        do {
            // Cancel the previous task if it's running.
            if let recognitionTask = recognitionTask {
                recognitionTask.cancel()
                self.recognitionTask = nil
            }
            
            // The AudioSession is already active, creating input node.
            let inputNode = audioEngine.inputNode
//            try inputNode.setVoiceProcessingEnabled(false)
            
            // Create and configure the speech recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a recognition request") }
            recognitionRequest.shouldReportPartialResults = true
            
            // Keep speech recognition data on device
            if #available(iOS 13, *) {
                recognitionRequest.requiresOnDeviceRecognition = true
            }
            
            // Create a recognition task for speech recognition session.
            // Keep a reference to the task so that it can be canceled.
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
//                var isFinal = false
                
                if let result = result {
                    // Update the recognizedText
                    let recognizedText = result.bestTranscription.formattedString
                    
                    // Whole Transcript
                    self.transcriptText = recognizedText
                    self.databaseRef.child("currentTranscript").setValue(recognizedText)
                    self.resetTimer()
                    
                    let lines = self.splitTextForCaptions(recognizedText, maxLineLength: 50, maxLines: 2)
                    
//                    let lines = recognizedText.split(separator: "\n")
//                    let lastTwoLines = lines.suffix(2).joined(separator: "\n")
//                    self.transcriptText = lastTwoLines
                    
                    // Upload to RealTimeDB
                    self.databaseRef.child("captionLines").setValue(lines)
                    
                } else if let error = error {
                    self.transcriptText = "Recognition stopped: \(error.localizedDescription)"
                }
                
                if error != nil || result?.isFinal == true {
                    // Stop recognizing speech if there is a problem
                    self.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                }
            }
            
            // Configure the microphone input
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 512, format: recordingFormat) { (buffer, when) in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            self.transcriptText = "Audio engine could not start: \(error.localizedDescription)"
        }
    }
    
    // Stop the speech rceognition task
    func stopTranscribing() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }
    
    private func resetTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            self.databaseRef.child("currentTranscript").setValue("")
        }
    }
    
    func splitTextForCaptions(_ text: String, maxLineLength: Int = 42, maxLines: Int = 2) -> [String] {
        let words = text.split(separator: " ")
        
        var lines: [String] = []
//        var firstLine = ""
//        var secondLine = ""
        var currentLine = ""
        
        // Loop through the words to construct lines of text
        for word in words {
            if currentLine.count + word.count + 1 <= maxLineLength {
                currentLine += word + " "
            } else {
                lines.append(currentLine.trimmingCharacters(in: .whitespaces))
                currentLine = word + " "
            }
        }
        
        // Append the last line if not empty
        if !currentLine.isEmpty {
            lines.append(currentLine.trimmingCharacters(in: .whitespaces))
        }
        
        // Keep only the last two lines
        if lines.count > 2 {
            lines = Array(lines.suffix(2))
        }
        
//        for word in words {
//            if currentLine.count + word.count + 1 <= maxLineLength {
//                currentLine += word + " "
//            } else if firstLine.isEmpty {
//                firstLine = currentLine.trimmingCharacters(in: .whitespaces)
//                currentLine = word + " "
//            } else {
//                secondLine = currentLine.trimmingCharacters(in: .whitespaces)
//                break
//            }
//        }
//        
//        // If new text comes in, keep only the latest two lines
//        if !secondLine.isEmpty {
//            firstLine = secondLine
//            secondLine = currentLine.trimmingCharacters(in: .whitespaces)
//        } else if firstLine.isEmpty {
//            firstLine = currentLine.trimmingCharacters(in: .whitespaces)
//        } else {
//            secondLine = currentLine.trimmingCharacters(in: .whitespaces)
//        }
        
//        for word in words {
//            if (currentLine + " " + word).count <= maxLineLength {
//                currentLine += (currentLine.isEmpty ? "" : " ") + word
//            } else {
//                captionSegments.append(currentLine)
//                currentLine = String(word)
//                
//                if captionSegments.count == maxLines { break }
//            }
//        }
//        
//        if !currentLine.isEmpty && captionSegments.count < maxLines {
//            captionSegments.append(currentLine)
//        }
        
        return lines
    }
    
//    func splitTextForCaptions(_ text: String, maxLineLength: Int, maxLines: Int = 2) -> [String] {
//        let words = text.split(separator: " ").map(String.init)
//        var currentLine = ""
//        var captionSegments: [String] = []
//        var lineCount = 0
//        
//        for word in words {
//            if currentLine.count + word.count + 1 <= maxLineLength {
//                if currentLine.isEmpty {
//                    currentLine = word + " "
//                } else {
//                    currentLine += " \(word) "
//                }
//            } else {
//                captionSegments.append(currentLine)
//                lineCount += 1
//                currentLine = word + " "
//
//                if lineCount == maxLines - 1 {
//                    captionSegments.append(currentLine)
//                    currentLine = ""
//                    lineCount = 0
//                }
//            }
//        }
//        
//        if !currentLine.isEmpty {
//            captionSegments.append(currentLine)
//        }
//        
//        return captionSegments
//    }
}
