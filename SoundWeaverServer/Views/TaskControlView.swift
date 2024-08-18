//
//  TaskControlView.swift
//  SoundWeaverServer
//
//  Created by Jeremy Huang on 8/18/24.
//

import SwiftUI

struct TaskControlView: View {
    
    var firestoreManager = FireStoreManager()
    @State private var selectedTask: TaskItem? = nil
    @State private var activeStates: [String: Bool] = [:]
    
    var body: some View {
        VStack {
            if let selectedTask = selectedTask {
                Text("Selected Task: \(selectedTask.taskLabel)")
                    .font(.headline)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    ForEach(selectedTask.soundItems) { sound in
                        Button(action: {
                            firestoreManager.toggleSoundActiveState(task: selectedTask, soundItem: sound)
                        }) {
                            Text(sound.labelName)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(activeStates[sound.labelName] == true ? Color.green : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            } else {
                Text("Select a Task").font(.headline)
            }
            
            Picker("Select a Task", selection: $selectedTask) {
                ForEach(firestoreManager.tasks) { task in
                    Text(task.taskLabel).tag(task as TaskItem?)
                }
            }
            .onChange(of: selectedTask) {
                if let task = selectedTask {
                    firestoreManager.sendTaskToRealtimeDatabase(task: task)
                    firestoreManager.fetchActiveStates(task: task) { states in
                        activeStates = states
                    }
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
        }
    }
}

#Preview {
    TaskControlView()
}
