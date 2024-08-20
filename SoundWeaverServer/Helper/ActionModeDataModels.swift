//
//  TaskItem.swift
//  SoundWeaverServer
//
//  Created by Jeremy Huang on 8/17/24.
//

import Foundation
import Firebase
import FirebaseFirestore

// For fetching the sounds
struct SoundItem: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    var labelName: String
    var pinned: Bool = false
}

struct TaskItem: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var taskLabel: String
    var soundItems: [SoundItem]
}

// For real-time DB relays
struct SoundItemForRealTimeDB: Codable {
    var labelName: String
    var pinned: Bool
    var activeState: Bool
}

struct TaskItemForRealTimeDB: Codable {
    var taskName: String
    var sounds: [SoundItemForRealTimeDB]
}
