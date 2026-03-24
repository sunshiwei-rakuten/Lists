// ABOUTME: Per-section item diffing with cross-section move reconciliation.
// ABOUTME: Combines HeckelDiff results into a StagedChangeset for batch updates.

import Foundation

// MARK: - DiffStrategy

enum DiffStrategy: Sendable {
  /// O(n) prefix check. Produces updates for matched prefix + inserts for tail.
  /// Falls back to `.full` on any structural mismatch.
  case streaming
  /// Full two-level SectionedHeckel. Handles arbitrary deletes / inserts / moves.
  case full
}

// MARK: - SectionedDiff

enum SectionedDiff {
  /// Computes a `StagedChangeset` by diffing two snapshots at both the section and item level.
  ///
  /// Uses per-section HeckelDiff for surviving sections, skipping sections whose items
  /// haven't changed. Cross-section item moves are detected by reconciling per-section
  /// deletes and inserts.
  static func diff<SectionID: Hashable & Sendable, ItemID: Hashable & Sendable>(
    old: DiffableDataSourceSnapshot<SectionID, ItemID>,
    new: DiffableDataSourceSnapshot<SectionID, ItemID>,
    strategy: DiffStrategy = .full
  ) -> StagedChangeset<SectionID, ItemID> {
    if case .streaming = strategy {
      if let result = streamingDiff(old: old, new: new) {
        return result
      }
    }
    return fullDiff(old: old, new: new)
  }

  // MARK: - Streaming Fast-Path

  /// O(n) prefix-based diff: requires identical section order and old items being
  /// a prefix of new items in every section. Produces `itemUpdates` for the matched
  /// prefix and `itemInserts` for the tail. Falls back to `nil` on any mismatch.
  private static func streamingDiff<SectionID: Hashable & Sendable, ItemID: Hashable & Sendable>(
    old: DiffableDataSourceSnapshot<SectionID, ItemID>,
    new: DiffableDataSourceSnapshot<SectionID, ItemID>
  ) -> StagedChangeset<SectionID, ItemID>? {
    // 1. Section IDs must be identical (order + content)
    guard old.sectionIdentifiers == new.sectionIdentifiers else {
      return nil
    }

    var itemInserts = [IndexPath]()
    var itemUpdates = [(itemId: ItemID, oldPath: IndexPath, newPath: IndexPath)]()

    // 2. Per-section: old items must be a prefix of new items
    for (sectionIdx, sectionID) in new.sectionIdentifiers.enumerated() {
      let oldItems = old.itemIdentifiers(inSection: sectionID)
      let newItems = new.itemIdentifiers(inSection: sectionID)

      guard newItems.count >= oldItems.count else { return nil }

      // Verify prefix match
      for i in 0 ..< oldItems.count {
        guard oldItems[i] == newItems[i] else { return nil }
      }

      // Matched prefix → itemUpdates (consumer decides if content actually changed)
      for i in 0 ..< oldItems.count {
        let path = IndexPath(item: i, section: sectionIdx)
        itemUpdates.append((itemId: oldItems[i], oldPath: path, newPath: path))
      }

      // Tail → itemInserts
      for i in oldItems.count ..< newItems.count {
        itemInserts.append(IndexPath(item: i, section: sectionIdx))
      }
    }

    // Collect reload/reconfigure markers from new snapshot
    var sectionReloads = IndexSet()
    if !new.reloadedSectionIdentifiers.isEmpty {
      for sectionID in new.reloadedSectionIdentifiers {
        if let newIdx = new.index(ofSection: sectionID), old.index(ofSection: sectionID) != nil {
          sectionReloads.insert(newIdx)
        }
      }
    }

    var itemReloads = [IndexPath]()
    var itemReconfigures = [IndexPath]()
    if !new.reloadedItemIdentifiers.isEmpty || !new.reconfiguredItemIdentifiers.isEmpty {
      for (sectionIdx, sectionID) in new.sectionIdentifiers.enumerated() {
        for (itemIdx, itemID) in new.itemIdentifiers(inSection: sectionID).enumerated() {
          if new.reloadedItemIdentifiers.contains(itemID) {
            itemReloads.append(IndexPath(item: itemIdx, section: sectionIdx))
          }
          if new.reconfiguredItemIdentifiers.contains(itemID) {
            itemReconfigures.append(IndexPath(item: itemIdx, section: sectionIdx))
          }
        }
      }
    }

    return StagedChangeset(
      sectionDeletes: IndexSet(),
      sectionInserts: IndexSet(),
      sectionMoves: [],
      sectionReloads: sectionReloads,
      itemDeletes: [],
      itemInserts: itemInserts,
      itemMoves: [],
      itemReloads: itemReloads,
      itemReconfigures: itemReconfigures,
      itemUpdates: itemUpdates
    )
  }

  // MARK: - Full Diff

  private static func fullDiff<SectionID: Hashable & Sendable, ItemID: Hashable & Sendable>(
    old: DiffableDataSourceSnapshot<SectionID, ItemID>,
    new: DiffableDataSourceSnapshot<SectionID, ItemID>
  ) -> StagedChangeset<SectionID, ItemID> {
    // 1. Diff sections
    let sectionDiff = HeckelDiff.diff(old: old.sectionIdentifiers, new: new.sectionIdentifiers)

    let sectionDeletes = IndexSet(sectionDiff.deletes)
    let sectionInserts = IndexSet(sectionDiff.inserts)
    let sectionMoves = sectionDiff.moves

    // 2. Per-section item diffing for matched (surviving) sections.
    var itemDeletes = [IndexPath]()
    var itemInserts = [IndexPath]()
    var itemMoves = [(from: IndexPath, to: IndexPath)]()
    var itemUpdates = [(itemId: ItemID, oldPath: IndexPath, newPath: IndexPath)]()

    let crossSectionPossible = old.numberOfSections > 1 || new.numberOfSections > 1

    var crossDeleteCandidates = [ItemID: IndexPath]()
    var crossInsertCandidates = [ItemID: IndexPath]()

    for match in sectionDiff.matched {
      let oldSectionIdx = match.old
      let newSectionIdx = match.new
      let oldSectionID = old.sectionIdentifiers[oldSectionIdx]
      let newSectionID = new.sectionIdentifiers[newSectionIdx]

      let oldItems = old.itemIdentifiers(inSection: oldSectionID)
      let newItems = new.itemIdentifiers(inSection: newSectionID)

      // Fast path: identical items → no changes in this section
      if oldItems == newItems {
        continue
      }

      let itemDiff = HeckelDiff.diff(old: oldItems, new: newItems)

      // Matched items → itemUpdates
      for matched in itemDiff.matched {
        itemUpdates.append((
          itemId: oldItems[matched.old],
          oldPath: IndexPath(item: matched.old, section: oldSectionIdx),
          newPath: IndexPath(item: matched.new, section: newSectionIdx)
        ))
      }

      // Within-section moves
      for move in itemDiff.moves {
        itemMoves.append((
          from: IndexPath(item: move.from, section: oldSectionIdx),
          to: IndexPath(item: move.to, section: newSectionIdx)
        ))
      }

      if crossSectionPossible {
        for deleteIdx in itemDiff.deletes {
          let itemID = oldItems[deleteIdx]
          crossDeleteCandidates[itemID] = IndexPath(item: deleteIdx, section: oldSectionIdx)
        }
        for insertIdx in itemDiff.inserts {
          let itemID = newItems[insertIdx]
          crossInsertCandidates[itemID] = IndexPath(item: insertIdx, section: newSectionIdx)
        }
      } else {
        for deleteIdx in itemDiff.deletes {
          itemDeletes.append(IndexPath(item: deleteIdx, section: oldSectionIdx))
        }
        for insertIdx in itemDiff.inserts {
          itemInserts.append(IndexPath(item: insertIdx, section: newSectionIdx))
        }
      }
    }

    // 3. Reconcile cross-section candidates.
    //    Cross-section moves are decomposed into delete + insert rather than emitted
    //    as moves. This matches the chat render invariant (items don't cross message
    //    boundaries) and avoids UIKit batch update complications with cross-section moves.
    if crossSectionPossible {
      for (itemID, fromPath) in crossDeleteCandidates {
        if let toPath = crossInsertCandidates.removeValue(forKey: itemID) {
          itemDeletes.append(fromPath)
          itemInserts.append(toPath)
        } else {
          itemDeletes.append(fromPath)
        }
      }
      itemInserts.append(contentsOf: crossInsertCandidates.values)
    }

    // 4. Section reloads — surviving sections only, using NEW indices.
    var sectionReloads = IndexSet()
    if !new.reloadedSectionIdentifiers.isEmpty {
      for sectionID in new.reloadedSectionIdentifiers {
        if let newIdx = new.index(ofSection: sectionID), old.index(ofSection: sectionID) != nil {
          sectionReloads.insert(newIdx)
        }
      }
    }

    // 5. Item reloads and reconfigures from the new snapshot
    var itemReloads = [IndexPath]()
    var itemReconfigures = [IndexPath]()

    if !new.reloadedItemIdentifiers.isEmpty || !new.reconfiguredItemIdentifiers.isEmpty {
      itemReloads.reserveCapacity(new.reloadedItemIdentifiers.count)
      itemReconfigures.reserveCapacity(new.reconfiguredItemIdentifiers.count)

      for (sectionIdx, sectionID) in new.sectionIdentifiers.enumerated() {
        for (itemIdx, itemID) in new.itemIdentifiers(inSection: sectionID).enumerated() {
          if new.reloadedItemIdentifiers.contains(itemID) {
            itemReloads.append(IndexPath(item: itemIdx, section: sectionIdx))
          }
          if new.reconfiguredItemIdentifiers.contains(itemID) {
            itemReconfigures.append(IndexPath(item: itemIdx, section: sectionIdx))
          }
        }
      }
    }

    // 6. Sort for deterministic batch update ordering
    let sortedItemDeletes = itemDeletes.sorted { ($0.section, $0.item) > ($1.section, $1.item) }
    let sortedItemInserts = itemInserts.sorted { ($0.section, $0.item) < ($1.section, $1.item) }

    return StagedChangeset(
      sectionDeletes: sectionDeletes,
      sectionInserts: sectionInserts,
      sectionMoves: sectionMoves,
      sectionReloads: sectionReloads,
      itemDeletes: sortedItemDeletes,
      itemInserts: sortedItemInserts,
      itemMoves: itemMoves,
      itemReloads: itemReloads,
      itemReconfigures: itemReconfigures,
      itemUpdates: itemUpdates
    )
  }
}
