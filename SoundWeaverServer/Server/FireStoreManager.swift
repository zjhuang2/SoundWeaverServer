//
//  FireStoreManager.swift
//  SoundWeaverServer
//
//  Created by Jeremy Huang on 8/17/24.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseDatabase

@Observable class FireStoreManager {
    var tasks: [TaskItem] = []
    
    private var db = Firestore.firestore()
    private var realtimeDB = Database.database().reference()
    
    init() {
        fetchTasks()
    }
    
    func fetchTasks() {
        db.collection("taskConfig").addSnapshotListener { (querySnapshot, error) in
            if let error = error {
                print("Error getting tasks: \(error.localizedDescription)")
                return
            }
            
            self.tasks = querySnapshot?.documents.compactMap { document in
                try? document.data(as: TaskItem.self)
            } ?? []
        }
    }
    
    func addTask(name: String) {
        let newTask = TaskItem(taskLabel: name, soundItems: [])
        do {
            _ = try db.collection("taskConfig").addDocument(from: newTask)
        } catch {
            print("Error adding task: \(error.localizedDescription)")
        }
    }
    
    func deleteTask(task: TaskItem) {
        guard let documentId = task.id else { return }
        db.collection("taskConfig").document(documentId).delete { error in
            if let error = error {
                print("Error deleting task: \(error.localizedDescription)")
            }
        }
    }
    
    func addSoundItem(to task: TaskItem, labelName: String, pinned: Bool) {
        guard let documentId = task.id else { return }
        
        var updatedTask = task
        updatedTask.soundItems.append(SoundItem(labelName: labelName, pinned: pinned))
        
        try? db.collection("taskConfig").document(documentId).setData(from: updatedTask)
    }
    
    func deleteSoundItem(from task: TaskItem, soundItem: SoundItem) {
        guard let documentId = task.id else { return }
        
        var updatedTask = task
        updatedTask.soundItems.removeAll { $0.id == soundItem.id }
        
        try? db.collection("taskConfig").document(documentId).setData(from: updatedTask)
    }
    
    func togglePinSoundItem(for task: TaskItem, soundItem: SoundItem) {
        guard let documentId = task.id else { return }
        
        var updatedTask = task
        if let index = updatedTask.soundItems.firstIndex(where: { $0.id == soundItem.id }) {
            updatedTask.soundItems[index].pinned.toggle()
        }
        
        try? db.collection("taskConfig").document(documentId).setData(from: updatedTask)
    }
    
    /// Real-time database connections.
    func sendTaskToRealtimeDatabase(task: TaskItem) {
        guard let taskId = task.id else { return }
        let taskData: [String: Any] = [
            "taskName": task.taskLabel,
            "sounds": task.soundItems.map { soundItem in
                [
                    "labelName": soundItem.labelName,
                    "pinned": soundItem.pinned,
                    "activeState": false
                ]
            }
        ]
        
        realtimeDB.child("activeTask/\(taskId)").setValue(taskData)
    }
    
    func toggleSoundActiveState(task: TaskItem, soundItem: SoundItem) {
        guard let taskId = task.id else { return }
        
        let soundItemsRef = realtimeDB.child("activeTask/\(taskId)/sounds")
        
        soundItemsRef.observeSingleEvent(of: .value, with: { snapshot in
            guard var sounds = snapshot.value as? [[String: Any]] else { return }
            
            if let index = sounds.firstIndex(where: { $0["labelName"] as? String == soundItem.labelName }) {
                var soundData = sounds[index]
                let currentState = soundData["activeState"] as? Bool ?? false
                soundData["activeState"] = !currentState
                sounds[index] = soundData
                soundItemsRef.setValue(sounds)
            }
        })
    }
    
    func fetchActiveStates(task: TaskItem, completion: @escaping ([String: Bool]) -> Void) {
        guard let taskId = task.id else { return }
        
        let soundRef = realtimeDB.child("activeTask/\(taskId)/sounds")
        
        soundRef.observe(.value) { snapshot in
            guard let sounds = snapshot.value as? [[String: Any]] else {
                completion([:])
                return
            }
            
            var activeStates: [String: Bool] = [:]
            for sound in sounds {
                if let labelName = sound["labelName"] as? String, let activeState = sound["activeState"] as? Bool {
                    activeStates[labelName] = activeState
                }
            }
            completion(activeStates)
        }
    }
}
