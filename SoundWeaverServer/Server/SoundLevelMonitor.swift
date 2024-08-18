//
//  SoundLevelMonitor.swift
//  SoundWeaverServer
//
//  Created by Jeremy Huang on 8/15/24.
//

import Foundation
import AVFoundation
import Combine
import Firebase
import FirebaseDatabase

@Observable class SoundLevelMonitor {
    
    // Set up Firebase Database connection
    private var databaseRef: DatabaseReference!
    
    static let shared = SoundLevelMonitor()

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    
    var amplitudes: [CGFloat] = Array(repeating: 0.0, count: 100) {
        didSet {
            uploadLatestAmplitudesToServer()
        }
    }
    
    var suddenSpikeDetected: Bool = false {
        didSet {
            uploadSpikeDetectionToServer()
        }
    }
    
    func startMonitoring() {
        
        // Document path for the temporary audio file for sound level monitoring
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFileName = documentsPath.appendingPathComponent("temp_audio.caf")
        
        do {
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatAppleLossless,
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFileName, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            // Start recording
            audioRecorder?.record()
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                self.updateAmplitudes()
            }
        } catch {
            print("Failed to set up audio recorder: \(error)")
        }
    }
    
    private func updateAmplitudes() {
        audioRecorder?.updateMeters()
        
        let amplitude = pow(10, (0.05 * audioRecorder!.averagePower(forChannel: 0)))
        let normalizedAmplitude = CGFloat(amplitude) * -6.0
        
        DispatchQueue.main.async {
            
            self.amplitudes.append(normalizedAmplitude)
            
            if self.amplitudes.count > 100 {
                self.amplitudes.removeFirst()
            }
            
            // watch out for anomalies
            if self.amplitudes.count >= 6 {
                let lastTenAverage = self.amplitudes.suffix(3).reduce(0, +) / 3.0
                let previousTenAverage = self.amplitudes.prefix(self.amplitudes.count - 3).suffix(3).reduce(0, +) / 3.0
                
                if abs(lastTenAverage - previousTenAverage) > 0.08 {
                    self.suddenSpikeDetected = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.suddenSpikeDetected = false
                    }
                }
            }
        }
    }
    
    private func uploadLatestAmplitudesToServer() {
        let ref = Database.database().reference()
        ref.child("soundLevel").setValue(["value": amplitudes])
    }
    
    private func uploadSpikeDetectionToServer() {
        let ref = Database.database().reference()
        ref.child("spikeDetected").setValue(["value": suddenSpikeDetected])
    }
    
    func stopMonitoring() {
        audioRecorder?.stop()
        timer?.invalidate()
    }
}
