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
            Attachment.self,
            // Legacy single-page notes, kept so they can be migrated into notebooks.
            Note.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            #if DEBUG
            DemoContent.seedLegacyNotesIfRequested(in: container.mainContext)
            #endif
            LegacyNoteMigration.run(in: container.mainContext)
            #if DEBUG
            DemoContent.seedIfRequested(in: container.mainContext)
            #endif
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var tools = ToolState()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(tools)
        }
        .modelContainer(sharedModelContainer)
    }
}
