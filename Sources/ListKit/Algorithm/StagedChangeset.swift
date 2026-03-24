// ABOUTME: Groups diff results into a single value type for UICollectionView batch updates.
// ABOUTME: Holds section/item deletes, inserts, moves, reloads, and reconfigures.

import Foundation

// MARK: - StagedChangeset

struct StagedChangeset<SectionID: Hashable & Sendable, ItemID: Hashable & Sendable>: Sendable {
  let sectionDeletes: IndexSet
  let sectionInserts: IndexSet
  let sectionMoves: [(from: Int, to: Int)]
  let sectionReloads: IndexSet
  let itemDeletes: [IndexPath]
  let itemInserts: [IndexPath]
  let itemMoves: [(from: IndexPath, to: IndexPath)]
  let itemReloads: [IndexPath]
  let itemReconfigures: [IndexPath]

  /// Matched pairs where identity survived; content may have changed.
  /// ID-centric: consumers look up objects by ID, index paths are informational only.
  let itemUpdates: [(itemId: ItemID, oldPath: IndexPath, newPath: IndexPath)]

  var isEmpty: Bool {
    sectionDeletes.isEmpty
      && sectionInserts.isEmpty
      && sectionMoves.isEmpty
      && sectionReloads.isEmpty
      && itemDeletes.isEmpty
      && itemInserts.isEmpty
      && itemMoves.isEmpty
      && itemReloads.isEmpty
      && itemReconfigures.isEmpty
      && itemUpdates.isEmpty
  }

  /// Structural changes require `performBatchUpdates`.
  /// `itemUpdates` is intentionally excluded: content change != structural change.
  var hasStructuralChanges: Bool {
    !sectionDeletes.isEmpty
      || !sectionInserts.isEmpty
      || !sectionMoves.isEmpty
      || !itemDeletes.isEmpty
      || !itemInserts.isEmpty
      || !itemMoves.isEmpty
  }
}

// MARK: Equatable

extension StagedChangeset: Equatable {
  static func ==(lhs: StagedChangeset, rhs: StagedChangeset) -> Bool {
    lhs.sectionDeletes == rhs.sectionDeletes
      && lhs.sectionInserts == rhs.sectionInserts
      && lhs.sectionMoves.count == rhs.sectionMoves.count
      && zip(lhs.sectionMoves, rhs.sectionMoves).allSatisfy { $0.from == $1.from && $0.to == $1.to }
      && lhs.sectionReloads == rhs.sectionReloads
      && lhs.itemDeletes == rhs.itemDeletes
      && lhs.itemInserts == rhs.itemInserts
      && lhs.itemMoves.count == rhs.itemMoves.count
      && zip(lhs.itemMoves, rhs.itemMoves).allSatisfy { $0.from == $1.from && $0.to == $1.to }
      && lhs.itemReloads == rhs.itemReloads
      && lhs.itemReconfigures == rhs.itemReconfigures
      && lhs.itemUpdates.count == rhs.itemUpdates.count
      && zip(lhs.itemUpdates, rhs.itemUpdates).allSatisfy {
        $0.itemId == $1.itemId && $0.oldPath == $1.oldPath && $0.newPath == $1.newPath
      }
  }
}
