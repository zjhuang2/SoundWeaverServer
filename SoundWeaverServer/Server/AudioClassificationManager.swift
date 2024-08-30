//
//  AudioClassificationManager.swift
//  SoundWeaverServer
//
//  Created by Jeremy Huang on 8/14/24.
//

import Foundation
import SoundAnalysis
import Combine
import Firebase
import FirebaseDatabase

@Observable class AudioClassificationState {
    
    // Set up Firebase Database connection
    var ref = Database.database().reference()
    
    /// A cancellable object for the lifetime of the sound classification.
    ///
    /// While the app retains this cancellable object, a sound classification task continues to run until it
    /// terminates due to an error.
    private var detectionCancellable: AnyCancellable? = nil
    
    // The config that governs sound classification task.
    private var classificationConfig = AudioClassificationConfiguration()
    
    let emergencySoundsLabel = ["siren", "civil_defense_siren", "smoke_detector", "gunshot_gunfire", "emergency_vehicle", "police_siren", "ambulance_siren", "fire_engine_siren"]
    
    var EMDetectedLocal: Bool = false
//    var emergencyDetectionCount = 0
    var debounceTimer: Timer?
    
    /// A list of mappings between sounds and current detection states.
    ///
    /// The app sorts this list to reflect the order in which the app displays them.
    var detectionStates: [(SoundIdentifier, DetectionState)] = [] {
        didSet {
            updateValueOnServer()
            setEMDetectionOnServer()
        }
    }
    
    /// Indicates whether a sound classification is active.
    ///
    /// When `false,` the sound classification has ended for some reason. This could be due to an error
    /// emitted from Sound Analysis, or due to an interruption in the recorded audio. The app needs to prompt
    /// the user to restart classification when `false.`
    var soundDetectionIsRunning: Bool = false
    
    /// Begins detecting sounds according to the configuration you specify.
    ///
    /// If the sound classification is running when calling this method, it stops before starting again.
    ///
    /// - Parameter config: A configuration that provides information for performing sound detection.
    func restartDetection(config: AudioClassificationConfiguration) {
        AudioClassifier.singleton.stopSoundClassification()
        
        let classificationSubject = PassthroughSubject<SNClassificationResult, Error>()
        
        detectionCancellable = classificationSubject
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in self.soundDetectionIsRunning = false },
                  receiveValue: { self.detectionStates = AudioClassificationState.advanceDetectionStates(self.detectionStates, givenClassificationResult: $0)}
            )
        
        self.detectionStates = [SoundIdentifier](config.monitoredSounds)
            .sorted(by: { $0.displayName < $1.displayName })
            .map { ($0, DetectionState(presenceThreshold: 0.5,
                                       absenceThreshold: 0.3,
                                       presenceMeasurementsToStartDetection: 3,
                                       absenceMeasurementsToEndDetection: 10))
            }
        
        soundDetectionIsRunning = true
        classificationConfig = config
        AudioClassifier.singleton.startSoundClassification(subject: classificationSubject,
                                                           inferenceWindowSize: config.inferenceWindowSize,
                                                           overlapFactor: config.overlapFactor)
    }
    
    /// Updates the detection states according to the latest classification result.
    ///
    /// - Parameters:
    ///   - oldStates: The previous detection states to update with a new observation from an ongoing
    ///   sound classification.
    ///   - result: The latest observation the app emits from an ongoing sound classification.
    ///
    /// - Returns: A new array of sounds with their updated detection states.
    static func advanceDetectionStates( _ oldStates: [(SoundIdentifier, DetectionState)],
                                        givenClassificationResult result: SNClassificationResult) -> [(SoundIdentifier, DetectionState)] {
        let confidenceLabel = { (sound: SoundIdentifier) -> Double in
            let confidence: Double
            let label = sound.labelName
            if let classification = result.classification(forIdentifier: label) {
                confidence = classification.confidence
            } else {
                confidence = 0
            }
            return confidence
        }
        return oldStates.map {(key, value) in
            (key, DetectionState(advancedFrom: value, currentConfidence: confidenceLabel(key)))
        }
    }
    
    // Update the Emergency Detection on Server
    private func setEMDetectionOnServer() {
        let ref = Database.database().reference()
        ref.child("emergencyDetected").setValue(EMDetectedLocal)
    }

//    // Check locally if the current detectionState contains emergency sounds.
//    private func checkEmergencySoundDetection() {
//        let containsEmergencySounds = detectionStates.contains { tuple in
//            emergencySoundsLabel.contains(tuple.0.labelName)
//        }
//        self.EMDetectedLocal = containsEmergencySounds
//    }
    
    /// Update the detection states on the real-time database.
    private func updateValueOnServer() {
        let ref = Database.database().reference()
        let detectedSounds = self.detectionStates
            .filter {$1.isDetected}
            .map { DetectedSound(labelName: $0.labelName, confidence: $1.currentConfidence) }
        
        var updatedDetectionArray: [[String: Any]] = []
        
        for sound in detectedSounds {
            updatedDetectionArray.append(sound.toDictionary())
        }
        
        // Check for emergency sounds locally
        let containsEmergencySound = updatedDetectionArray.contains { dict in
            if let labelName = dict["labelName"] as? String {
                return emergencySoundsLabel.contains(labelName)
            }
            return false
        }
        
        if containsEmergencySound {
            if self.EMDetectedLocal == true {
                startDebounceTimer()
            } else {
                self.EMDetectedLocal = true
                startDebounceTimer()
            }
        }
        
        // Update the detectionState on Server
        if updatedDetectionArray.isEmpty {
            ref.child("detectionStates").setValue([["placeholder": true]])
        } else {
            ref.child("detectionStates").setValue(updatedDetectionArray)
        }
    }
    
    private func startDebounceTimer() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
            self.EMDetectedLocal = false
        }
    }
}

struct DetectedSound: Codable {
    var labelName: String
    var confidence: Double
}

extension DetectedSound {
    func toDictionary() -> [String: Any] {
        return [
            "labelName": labelName,
            "confidence": confidence
        ]
    }
}

/// Contains customizable settings that control app behavior.
struct AudioClassificationConfiguration {
    
    /// Indicates the amount of audio, in seconds, that informs a prediction.
    var inferenceWindowSize = Double(1.5)

    /// The amount of overlap between consecutive analysis windows.
    ///
    /// The system performs sound classification on a window-by-window basis. The system divides an
    /// audio stream into windows, and assigns labels and confidence values. This value determines how
    /// much two consecutive windows overlap. For example, 0.9 means that each window shares 90% of
    /// the audio that the previous window uses.
    var overlapFactor = Double(0.9)

    /// A list of sounds to identify from system audio input - SUBJECT TO CHANGE BASED ON CONTEXTS.
    var monitoredSounds = try! listExperiementalSoundIdentifiers()
    
    var emergencySounds = try! listEmergencySoundIdentifiers()

    /// Retrieves a list of the sounds the system can identify.
    ///
    /// - Returns: A set of identifiable sounds, including the associated labels that sound
    ///   classification emits, and names suitable for displaying to the user.
    static func listAllValidSoundIdentifiers() throws -> Set<SoundIdentifier> {
        let labels = try AudioClassifier.getAllPossibleLabels()
        return Set<SoundIdentifier>(labels.map {
            SoundIdentifier(labelName: $0)
        })
    }
    
    // A list of sounds used for the SoundWeaver Field Evaluation Experiments
    static func listExperiementalSoundIdentifiers() throws -> Set<SoundIdentifier> {
        let experimentalLabels = ["speech", "shout", "yell", "screaming", "whispering", "laughter", "baby_laughter", "giggling", "crying_sobbing", "baby_crying", "sigh", "singing", "cough", "sneeze", "finger_snapping",
                      "clapping", "cheering", "applause", "crowd", "dog", "dog_bark", "dog_howl", "cat", "cat_purr", "cat_meow", "bird", "music", "bell", "bicycle_bell", "chime", "wind_rustling_leaves", "thunder", "water", "rain", "stream_burbling", "waterfall", "fire", "fire_crackle", "car_horn", "emergency_vehicle", "police_siren", "ambulance_siren", "fire_engine_siren", "motorcycle", "subway_metro", "helicopter", "bicycle", "engine", "lawn_mower", "chainsaw", "door", "door_bell", "door_sliding", "door_slam", "knock", "tap", "squeak", "chopping_food", "frying_food", "cutlery_silverware", "microwave_oven", "blender", "water_tap_faucet", "hair_dryer", "vaccum_cleaner", "typing", "telephone", "telephone_bell_ringing", "ringtone", "alarm_clock", "siren", "civil_defense_siren", "smoke_detector", "mechanical_fan", "printer", "power_tool", "drill", "gunshot_gunfire", "fireworks", "boom", "glass_clink", "glass_breaking", "liquid_splashing", "liquid_dripping", "liquid_trickle_dribble", "liquid_sloshing", "boiling", "underwater_bubbling", "whoosh_swoosh_swish", "thump_thud", "slap_smack", "crushing", "crumpling_crinkling", "tearing", "beep", "click"]
        
        let labels = try AudioClassifier.getAllPossibleLabels().filter { experimentalLabels.contains($0) }
        return Set<SoundIdentifier>(labels.map {
            SoundIdentifier(labelName: $0)
        })
    }
    
    // A list of sounds that is emergent and should override the modes.
    static func listEmergencySoundIdentifiers() throws -> Set<SoundIdentifier> {
        let emergencyLabels = ["smoke_detector", "gunshot_gunfire", "emergency_vehicle", "police_siren", "ambulance_siren"]
        let labels = try AudioClassifier.getAllPossibleLabels().filter { emergencyLabels.contains($0) }
        return Set<SoundIdentifier>(labels.map {
            SoundIdentifier(labelName: $0)
        })
    }
}

@Observable class userContexts {
    var contextDict: [String: Set<SoundIdentifier>] = [:]
}
