//
//  ConfigurationView.swift
//  SoundWeaverServer
//
//  Created by Jeremy Huang on 8/16/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct TaskConfigView: View {
    
    var firestoreManager = FireStoreManager()
    
    @State var newTaskName: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(firestoreManager.tasks) { task in
                        NavigationLink(destination: TaskDetailView(task: task)) {
                            Text(task.taskLabel)
                        }
                    }
                    .onDelete(perform: deleteTask)
                }
                
                HStack {
                    TextField("New Task Name", text: $newTaskName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        if !newTaskName.isEmpty {
                            firestoreManager.addTask(name: newTaskName)
                            newTaskName = ""
                        }
                    }) {
                        Text("Add Task")
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .navigationTitle("Action Tasks")
        }
    }
    
    private func deleteTask(at offsets: IndexSet) {
        offsets.forEach { index in
            let task = firestoreManager.tasks[index]
            firestoreManager.deleteTask(task: task)
        }
    }
}



#Preview {
    TaskConfigView()
}
