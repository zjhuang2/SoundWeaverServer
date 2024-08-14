//
//  DirectionButton.swift
//  SoundWeaverServer
//
//  Created by Jeremy Huang on 8/14/24.
//

import SwiftUI
import Firebase
import FirebaseDatabase

struct DirectionButton: View {
    
    let direction: String
    
    @Binding var currentDirection: String
    
    var body: some View {
        Button(action: {
            if currentDirection != direction {
                currentDirection = direction
                sendDirectionToFirebase(direction: direction)
            } else {
                removeDirectionFromFirebase()
                currentDirection = "NA"
            }
            
        }) {
            Text(direction)
                .frame(width: 100, height: 60)
                .background(currentDirection == direction ? Color.green : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }
    
    func sendDirectionToFirebase(direction: String) {
        // Send direction
        let databaseRef = Database.database().reference()
        databaseRef.child("direction").setValue(["direction": direction])
    }
    
    func removeDirectionFromFirebase() {
        // Remove direction
        let databaseRef = Database.database().reference()
        databaseRef.child("direction").setValue(["direction": "NA"])
    }
}
