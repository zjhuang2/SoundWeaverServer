//
//  DirectionView.swift
//  SoundWeaverServer
//
//  Created by Jeremy Huang on 8/14/24.
//

import SwiftUI
import Firebase
import FirebaseDatabase
import Foundation

struct DirectionView: View {
    
    @State private var databaseRef: DatabaseReference!
    
    func setupFirebase() {
        databaseRef = Database.database().reference()
    }
    
    @State var currentDirection = "NA"
    
    var body: some View {
        VStack {
            Text("Directional Information").font(.title)
            VStack {
                HStack {
                    DirectionButton(direction: "Front-left",
                                    currentDirection: $currentDirection)
                    Spacer()
                    DirectionButton(direction: "Front",
                                    currentDirection: $currentDirection)
                    Spacer()
                    DirectionButton(direction: "Front-right",
                                    currentDirection: $currentDirection)
                }
                Spacer()
                HStack {
                    DirectionButton(direction: "Left",
                                    currentDirection: $currentDirection)
                    Spacer()
                    DirectionButton(direction: "Right",
                                    currentDirection: $currentDirection)
                }
                Spacer()
                HStack {
                    DirectionButton(direction: "Back-left",
                                    currentDirection: $currentDirection)
                    Spacer()
                    DirectionButton(direction: "Back",
                                    currentDirection: $currentDirection)
                    Spacer()
                    DirectionButton(direction: "Back-right",
                                    currentDirection: $currentDirection)
                }
                Spacer()
                Spacer()
                Spacer()
            }
        }
    }
}

#Preview {
    DirectionView()
}
