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
    private var realtimeDB = Database.database().reference()
    
    static let shared = SoundLevelMonitor()
    private var audioRecorder: AVAudioRecorder?
    
    private var timer: Timer?
    private var spikeDetectionTimer: Timer? = nil
    
    var amplitudes: [CGFloat] = Array(repeating: 0.0, count: 100) {
        didSet {
            uploadLatestAmplitudesToServer()
        }
    }
    
    var avgAmplitude: CGFloat = 0.0
    
    var spikeDetected: Bool = false
    
//    var suddenSpikeDetected: Bool = false {
//        didSet {
//            uploadSpikeDetectionToServer()
//        }
//    }
    
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
            
            // Start observing spikeDetected values on Firebase
            observeSpikeDetection()
            
        } catch {
            print("Failed to set up audio recorder: \(error)")
        }
    }
    
    func observeSpikeDetection() {
        realtimeDB.child("spikeDetected").observe(.value, with: { snapshot in
            if let value = snapshot.value as? Bool {
                self.spikeDetected = value
            }
        })
    }
    
    func setSpikeDetectionToTrue() {
        if spikeDetected {
            spikeDetectionTimer?.invalidate()
            spikeDetectionTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { _ in
                self.realtimeDB.child("spikeDetected").setValue(false)
            }
        } else {
            realtimeDB.child("spikeDetected").setValue(true)
            spikeDetectionTimer?.invalidate()
            spikeDetectionTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { _ in
                self.realtimeDB.child("spikeDetected").setValue(false)
            }
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
            
            self.avgAmplitude = self.average(of: self.amplitudes)
            
            // watch out for anomalies
            if self.amplitudes.count >= 6 {
                let lastTenAverage = self.amplitudes.suffix(3).reduce(0, +) / 3.0
                let previousTenAverage = self.amplitudes.prefix(self.amplitudes.count - 3).suffix(3).reduce(0, +) / 3.0
                
                if abs(lastTenAverage - previousTenAverage) > 0.08 {
                    self.setSpikeDetectionToTrue()
                }
            }
        }
    }
    
    private func average(of values: [CGFloat]) -> CGFloat {
        guard !values.isEmpty else { return 0 } // Handle empty array case
        let sum = values.reduce(0, +)
        return sum / CGFloat(values.count)
    }
    
    private func uploadLatestAmplitudesToServer() {
        let ref = Database.database().reference()
        ref.child("soundLevel").setValue(["value": amplitudes])
        ref.child("AverageSoundLevel").setValue(self.avgAmplitude)
    }
    
    
    func stopMonitoring() {
        audioRecorder?.stop()
        timer?.invalidate()
    }
}
