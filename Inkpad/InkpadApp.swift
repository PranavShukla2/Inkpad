//
//  InkpadApp.swift
//  Inkpad
//

import SwiftUI
import SwiftData

@main
struct InkpadApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Notebook.self,
            Page.self,
            Folder.self,
            Recording.self,
            // Legacy single-page notes, kept so they can be migrated into notebooks.
            Note.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
