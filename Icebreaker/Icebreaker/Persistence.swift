//
//  Persistence.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/23/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Log error instead of crashing in preview
            print("❌ Preview CoreData Error: \(error)")
            // Don't crash previews - just continue with empty context
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Icebreaker")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { [container] (storeDescription, error) in
            if let error = error as NSError? {
                // Log error instead of crashing in production
                print("❌ CoreData Error: \(error), \(error.userInfo)")
                
                // Try to recover by creating a new store
                let coordinator = container.persistentStoreCoordinator
                let store = coordinator.persistentStores.first
                
                if let store = store {
                    do {
                        try coordinator.remove(store)
                        try coordinator.addPersistentStore(
                            ofType: NSSQLiteStoreType,
                            configurationName: nil,
                            at: store.url,
                            options: [NSMigratePersistentStoresAutomaticallyOption: true,
                                     NSInferMappingModelAutomaticallyOption: true]
                        )
                        print("✅ CoreData store recovered")
                    } catch {
                        print("❌ Failed to recover CoreData store: \(error)")
                        // As a last resort, create an in-memory store
                        do {
                            _ = try coordinator.addPersistentStore(
                                ofType: NSInMemoryStoreType,
                                configurationName: nil,
                                at: nil,
                                options: nil
                            )
                            print("✅ Created fallback in-memory store")
                        } catch {
                            print("❌ Critical: Failed to create fallback store: \(error)")
                        }
                    }
                }
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
