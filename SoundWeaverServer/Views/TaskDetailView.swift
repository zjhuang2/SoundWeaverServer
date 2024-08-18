//
//  TaskDetailView.swift
//  SoundWeaverServer
//
//  Created by Jeremy Huang on 8/17/24.
//

import SwiftUI

struct TaskDetailView: View {
    
    var firestoreManager = FireStoreManager()
    @State private var newSoundLabel: String = ""
    @State private var newSoundPinned: Bool = false
    
    var task: TaskItem
    
    var body: some View {
        VStack {
            List {
                ForEach(task.soundItems) { soundItem in
                    HStack {
                        Text(soundItem.labelName)
                        Spacer()
                        Button(action: {
                            firestoreManager.togglePinSoundItem(for: task, soundItem: soundItem)
                        }) {
                            Image(systemName: soundItem.pinned ? "star.fill" : "star")
                                .foregroundColor(soundItem.pinned ? .yellow : .gray)
                        }
                    }
                }
                .onDelete(perform: deleteSoundItem)
            }
            
            HStack {
                TextField("New Sound", text: $newSoundLabel)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                HStack(spacing: 5) {
                    Text("Pin")
                    Toggle("", isOn: $newSoundPinned)
                        .labelsHidden()
                }

                Spacer()
                
                Button(action: {
                    firestoreManager.addSoundItem(to: task, labelName: newSoundLabel, pinned: newSoundPinned)
                    newSoundLabel = ""
                    newSoundPinned = false
                }) {
                    Text("Add")
                        .padding(.horizontal)
                }
            }
            .padding()
        }
        .navigationTitle("Configuring: \(task.taskLabel)")
    }
    
    private func deleteSoundItem(at offsets: IndexSet) {
        offsets.forEach { index in
            let soundItem = task.soundItems[index]
            firestoreManager.deleteSoundItem(from: task, soundItem: soundItem)
        }
    }
}

//#Preview {
//    TaskDetailView()
//}
