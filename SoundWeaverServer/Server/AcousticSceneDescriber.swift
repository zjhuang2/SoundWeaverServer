//
//  AcousticSceneDescriber.swift
//  SoundWeaverServer
//
//  Created by Jeremy Huang on 8/20/24.
//

import Foundation
import AVFoundation
import Firebase
import FirebaseDatabase

@Observable class AcousticSceneDescriber {
    static let shared = AcousticSceneDescriber()
    
    private var audioRecorder: AVAudioRecorder?
    private var audioFileName: URL?
    
    var isRecording = false
    var apiResponse: String? = nil
    
    private var realtimeDB = Database.database().reference()
    
    private init() {
        observeStartRecording()
    }
    
    // A trigger for start recording
    func observeStartRecording() {
        realtimeDB.child("ASUStartRecording").observe(.value) { snapshot in
            if let start = snapshot.value as? Bool, start == true {
                self.recordAudioForFiveSeconds()
                // Reset the startRecording flag
                self.realtimeDB.child("ASUStartRecording").setValue(false)
            }
        }
    }
    
    func recordAudioForFiveSeconds() {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = UUID().uuidString + ".wav"
            audioFileName = documentsPath.appendingPathComponent(fileName)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFileName!, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record(forDuration: 5.0)
            
            isRecording = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.1) {
                self.stopRecording()
            }
        } catch {
            print("Failed to set up audio recording: ", error)
        }
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        if let fileURL = audioFileName {
            uploadAudioFile(fileURL: fileURL)
        }
    }
    
    private func uploadAudioFile(fileURL: URL) {
        let url = URL(string: "http://34.123.123.106:8080/caption")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let httpBody = createBody(with: fileURL, boundary: boundary)
        
        let task = URLSession.shared.uploadTask(with: request, from: httpBody) { data, response, error in
            if let error = error {
                print("Failed to upload file:", error)
                return
            }
            
//            if let data = data {
//                self.handleAPIResponse(data: data)
//            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                
                let capitalizedResponseString = responseString.capitalizeFirstLetter()
                
                DispatchQueue.main.async {
                    self.uploadResponseToFirebase(response: capitalizedResponseString)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.1) {
                        self.uploadResponseToFirebase(response: "No response yet")
                    }
                }
            }
        }
        task.resume()
    }
    
    // Extract and process the result from the API response.
    private func handleAPIResponse(data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let result = json["result"] as? String {
                DispatchQueue.main.async {
                    self.apiResponse = result
                    self.uploadResponseToFirebase(response: result)
                }
            } else {
                print("Failed to parse JSON or find 'result' key")
            }
        } catch {
            print("Failed to parse API response:", error)
        }
    }
    
    private func createBody(with fileURL: URL, boundary: String) -> Data {
        var body = Data()
        let filename = fileURL.lastPathComponent
        let mimetype = "audio/wav"
        
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimetype)\r\n\r\n")
        body.append(try! Data(contentsOf: fileURL))
        body.append("\r\n")
        body.append("--\(boundary)--\r\n")
        
        return body
    }
    
    private func uploadResponseToFirebase(response: String) {
        realtimeDB.child("ASUResponse").setValue(response)
        
        // Set a timer to change the value to "NA" after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.realtimeDB.child("ASUResponse").setValue("NA")
        }
    }
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

extension String {
    func capitalizeFirstLetter() -> String {
        guard let firstLetter = self.first else {
            return self // Return the original string if it's empty
        }
        return firstLetter.uppercased() + self.dropFirst()
    }
}
