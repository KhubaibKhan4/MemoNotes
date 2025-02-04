//
//  TodoScreen.swift
//  Notes
//
//  Created by Muhammad Khubaib Imtiaz on 20/10/2024.
//

import SwiftUI
import SwiftData

struct TodoScreen: View {
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appManager: AppManager
    @AppStorage("isSubscribed") var isSubscribed: Bool = false
    
    
    @Query(filter: .true, sort: \TodoItem.id, order: .forward, animation: .smooth) private var todoList: [TodoItem]
    @Query(filter: #Predicate<TodoItem> { $0.isCompleted == false }) private var inCompleteList: [TodoItem]
    @Query(filter: #Predicate<TodoItem> { $0.isCompleted == true }, animation: .smooth) private var completedList: [TodoItem]
    
    @State private var title: String = ""
    @State private var isCompleted: Bool = false
    @State private var isSheet: Bool = false
    @State private var navTitle: String = "Add Task"
    @State private var selectedItem: TodoItem?
    
    @AppStorage("isDarkMode") private var isDark: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)
                
                if todoList.isEmpty {
                    VStack {
                        Image(systemName: "note.text.badge.plus")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No Tasks Found")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Start by adding a new task.")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                } else {
                    VStack {
                        Spacer()
                            .frame(height: 8)
                        if !isSubscribed {
                            BannerAdView()
                                .background(.gray)
                                .frame(width: 320, height: 100)
                                .padding(10)
                        }
                        Spacer()
                            .frame(height: 8)
                        
                        List {
                            if !completedList.isEmpty {
                                Section(header: Text("✅ Completed Tasks")) {
                                    ForEach(completedList) { item in
                                        todoCard(for: item)
                                            .swipeActions(edge: .trailing) {
                                                Button {
                                                    toggleCompletion(for: item)
                                                } label: {
                                                    Label("UnComplete", systemImage: item.isCompleted ? "xmark.circle" : "checkmark.circle.fill")
                                                }
                                                .tint(.green)
                                                
                                                Button("Edit") {
                                                    editItem(item)
                                                }
                                                .tint(.blue)
                                                
                                                Button("Delete", role: .destructive) {
                                                    deleteItem(item)
                                                }
                                            }
                                    }
                                }
                            }
                            if !inCompleteList.isEmpty {
                                Section(header: Text("⏳ Pending Tasks")) {
                                    ForEach(inCompleteList) { item in
                                        todoCard(for: item)
                                            .swipeActions(edge: .trailing) {
                                                Button {
                                                    toggleCompletion(for: item)
                                                } label: {
                                                    Label("Complete", systemImage: item.isCompleted ? "xmark.circle" : "checkmark.circle.fill")
                                                }
                                                .tint(.green)
                                                
                                                Button("Edit") {
                                                    editItem(item)
                                                }
                                                .tint(.blue)
                                                
                                                Button("Delete", role: .destructive) {
                                                    deleteItem(item)
                                                }
                                            }
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                        .refreshable {
                            print("Refreshing tasks...")
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        title = ""
                        selectedItem = nil
                        navTitle = "Add Task"
                        isSheet.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .preferredColorScheme(isDark ? .dark : .light)
            .navigationTitle("📝 Todo List")
            .sheet(isPresented: $isSheet) {
                TodoSheetContent(
                    title: $title,
                    isCompleted: $isCompleted,
                    taskTitle: navTitle,
                    onSave: {
                        if let selectedItem = selectedItem {
                            selectedItem.title = title
                            selectedItem.isCompleted = isCompleted
                            navTitle = "Update Task"
                        } else {
                            let todoItem = TodoItem(title: title, isCompleted: isCompleted)
                            context.insert(todoItem)
                        }
                        try? context.save()
                        isSheet = false
                    }
                )
            }
        }
    }
    
    private func todoCard(for item: TodoItem) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(item.isCompleted ? .gray : appManager.isDark ? .white : .black)
                
                Text(item.isCompleted ? "Completed" : "Pending")
                    .font(.subheadline)
                    .foregroundColor(item.isCompleted ? .green : .red)
            }
            Spacer()
            
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(item.isCompleted ? .green : .gray)
                .font(.title2)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(appManager.isDark ? .gray.opacity(0.1) : .white))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func toggleCompletion(for item: TodoItem) {
        item.isCompleted.toggle()
        try? context.save()
    }
    
    private func editItem(_ item: TodoItem) {
        selectedItem = item
        title = item.title
        isCompleted = item.isCompleted
        navTitle = "Update Task"
        isSheet = true
    }
    
    private func deleteItem(_ item: TodoItem) {
        if let index = todoList.firstIndex(where: { $0.id == item.id }) {
            context.delete(todoList[index])
            try? context.save()
        }
    }
}
