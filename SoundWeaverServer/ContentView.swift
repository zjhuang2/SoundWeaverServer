//
//  ContentView.swift
//  SoundWeaverServer
//
//  Created by Jeremy Huang on 8/14/24.
//

import SwiftUI
import Firebase
import FirebaseDatabase
import Foundation

struct ContentView: View {
    
    @State private var databaseRef: DatabaseReference!
    
    func setupFirebase() {
        databaseRef = Database.database().reference()
    }
    
    @State private var data: [String] = []
    @State private var newItem: String = ""
    
//    @State var currentDirection = "NA"
    
    @State var isSensing = false
    
    private func startTranscribing() {
        SpeechRecognizer.shared.startTranscribing()
    }

    private func stopTranscribing() {
        SpeechRecognizer.shared.stopTranscribing()
    }
    
    var body: some View {
        VStack {
            TabView {
                TaskConfigView()
                    .tabItem {
                        Label("Action Tasks", systemImage: "bolt.fill")
                    }
                
                VStack {
                    DirectionView()
                    TaskControlView()
                }
                .tabItem {
                    Label("Woz Remote", systemImage: "av.remote")
                }
                
                ServerView()
                    .tabItem {
                        Label("Server Controls", systemImage: "server.rack")
                    }
            }
        }
        .onAppear {
            AudioSessionManager.shared
        }
    }
}



#Preview {
    ContentView()
}
