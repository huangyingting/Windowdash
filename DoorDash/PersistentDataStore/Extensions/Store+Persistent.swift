//
//  Store+Persistent.swift
//  DoorDash
//
//  Created by Marvin Zhan on 2018-09-25.
//  Copyright © 2018 Monster. All rights reserved.
//


import Foundation
import CoreData

extension Store: PersistentModel {
    public func savePersistently(to dataStore: DataStoreType) throws {
        guard self.validateModel() else {
            throw PersistentModelError.invalid
        }
        dataStore.performBackgroundTask { context in
            do {
                _ = self.insertOrUpdateTo(context)
                try context.save()
            } catch {
                log.error(error)
            }
        }
    }

    func validateModel() -> Bool {
        return true
    }

    public func insertOrUpdateTo(_ context: NSManagedObjectContext) -> PSStore {
        let store = PSStore(entity: PSStore.entity(), insertInto: context)
        store.averageRating = averageRating
        store.id = id
        store.numRatings = numRatings
        store.storeDescription = storeDescription
        store.name = name
        store.nextOpenTime = nextOpenTime
        store.nextCloseTime = nextCloseTime
        store.priceRange = priceRange
        return store
    }

    public static func revert(persistent: PSStore) throws -> Store {
        return Store(
            id: persistent.id,
            numRatings: persistent.numRatings,
            averageRating: persistent.averageRating,
            storeDescription: persistent.storeDescription ?? "",
            priceRange: persistent.priceRange,
            name: persistent.name ?? "",
            nextCloseTime: persistent.nextCloseTime ?? Date(),
            nextOpenTime: persistent.nextOpenTime ?? Date()
        )
    }
}