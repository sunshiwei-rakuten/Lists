// ABOUTME: Groups diff results into a single value type for UICollectionView batch updates.
// ABOUTME: Holds section/item deletes, inserts, moves, reloads, and reconfigures.

import Foundation

// MARK: - StagedChangeset

public struct StagedChangeset<SectionID: Hashable & Sendable, ItemID: Hashable & Sendable>: Sendable {
  public let sectionDeletes: IndexSet
  public let sectionInserts: IndexSet
  public let sectionMoves: [(from: Int, to: Int)]
  public let sectionReloads: IndexSet
  public let itemDeletes: [IndexPath]
  public let itemInserts: [IndexPath]
  public let itemMoves: [(from: IndexPath, to: IndexPath)]
  public let itemReloads: [IndexPath]
  public let itemReconfigures: [IndexPath]

  public init(
    sectionDeletes: IndexSet = IndexSet(),
    sectionInserts: IndexSet = IndexSet(),
    sectionMoves: [(from: Int, to: Int)] = [],
    sectionReloads: IndexSet = IndexSet(),
    itemDeletes: [IndexPath] = [],
    itemInserts: [IndexPath] = [],
    itemMoves: [(from: IndexPath, to: IndexPath)] = [],
    itemReloads: [IndexPath] = [],
    itemReconfigures: [IndexPath] = []
  ) {
    self.sectionDeletes = sectionDeletes
    self.sectionInserts = sectionInserts
    self.sectionMoves = sectionMoves
    self.sectionReloads = sectionReloads
    self.itemDeletes = itemDeletes
    self.itemInserts = itemInserts
    self.itemMoves = itemMoves
    self.itemReloads = itemReloads
    self.itemReconfigures = itemReconfigures
  }

  public var isEmpty: Bool {
    sectionDeletes.isEmpty
      && sectionInserts.isEmpty
      && sectionMoves.isEmpty
      && sectionReloads.isEmpty
      && itemDeletes.isEmpty
      && itemInserts.isEmpty
      && itemMoves.isEmpty
      && itemReloads.isEmpty
      && itemReconfigures.isEmpty
  }

  /// Structural changes require `performBatchUpdates`.
  public var hasStructuralChanges: Bool {
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
  public static func ==(lhs: StagedChangeset, rhs: StagedChangeset) -> Bool {
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
  }
}
