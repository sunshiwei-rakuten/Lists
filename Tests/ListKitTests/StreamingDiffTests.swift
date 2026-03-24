// ABOUTME: Tests for DiffStrategy.streaming and itemUpdates production.
// ABOUTME: Covers prefix matching, fallback to full, and content-level update semantics.

import Foundation
import Testing
@testable import ListKit

struct StreamingDiffTests {

  // MARK: - Streaming Fast-Path

  @Test
  func streamingAppendOnly() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2, 3, 4], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .streaming)
    #expect(changeset.itemInserts.count == 2)
    #expect(changeset.itemInserts.contains(IndexPath(item: 2, section: 0)))
    #expect(changeset.itemInserts.contains(IndexPath(item: 3, section: 0)))
    #expect(changeset.itemDeletes.isEmpty)
    #expect(changeset.itemMoves.isEmpty)
    #expect(changeset.sectionDeletes.isEmpty)
    #expect(changeset.sectionInserts.isEmpty)
  }

  @Test
  func streamingPrefixMatchProducesUpdates() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2, 3], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .streaming)
    // All items matched → itemUpdates for each
    #expect(changeset.itemUpdates.count == 3)
    for (i, update) in changeset.itemUpdates.enumerated() {
      #expect(update.itemId == i + 1)
      #expect(update.oldPath == IndexPath(item: i, section: 0))
      #expect(update.newPath == IndexPath(item: i, section: 0))
    }
    #expect(changeset.itemInserts.isEmpty)
    #expect(changeset.itemDeletes.isEmpty)
  }

  @Test
  func streamingPrefixMatchWithAppend() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2, 3], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .streaming)
    #expect(changeset.itemUpdates.count == 2)
    #expect(changeset.itemUpdates[0].itemId == 1)
    #expect(changeset.itemUpdates[1].itemId == 2)
    #expect(changeset.itemInserts.count == 1)
    #expect(changeset.itemInserts[0] == IndexPath(item: 2, section: 0))
  }

  @Test
  func streamingMultipleSections() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems([1, 2], toSection: "A")
    old.appendItems([10], toSection: "B")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A", "B"])
    new.appendItems([1, 2, 3], toSection: "A")
    new.appendItems([10, 20], toSection: "B")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .streaming)
    #expect(changeset.itemUpdates.count == 3) // 1,2 from A + 10 from B
    #expect(changeset.itemInserts.count == 2) // 3 in A + 20 in B
    #expect(changeset.sectionDeletes.isEmpty)
    #expect(changeset.sectionInserts.isEmpty)
  }

  @Test
  func streamingEmptyOldAllInserts() {
    let old = DiffableDataSourceSnapshot<String, Int>()

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2], toSection: "A")

    // Section mismatch → falls back to full
    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .streaming)
    #expect(changeset.sectionInserts == IndexSet([0]))
  }

  // MARK: - Streaming Fallback to Full

  @Test
  func streamingFallbackOnSectionOrderDifference() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems([1], toSection: "A")
    old.appendItems([2], toSection: "B")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["B", "A"])
    new.appendItems([2], toSection: "B")
    new.appendItems([1], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .streaming)
    // Fell back to full diff — sections reordered, so moves produced
    #expect(!changeset.sectionMoves.isEmpty)
  }

  @Test
  func streamingFallbackOnSectionCountDifference() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A", "B"])
    new.appendItems([1], toSection: "A")
    new.appendItems([2], toSection: "B")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .streaming)
    // Fell back to full diff — new section added
    #expect(changeset.sectionInserts == IndexSet([1]))
  }

  @Test
  func streamingFallbackOnItemNotPrefix() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 99, 3, 4], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .streaming)
    // Item 2 → 99 breaks prefix match → falls back to full diff
    #expect(changeset.hasStructuralChanges)
    // Full diff: item 2 deleted, items 99 and 4 inserted
    #expect(!changeset.itemDeletes.isEmpty)
    #expect(!changeset.itemInserts.isEmpty)
  }

  @Test
  func streamingFallbackOnShrinkingItems() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .streaming)
    // newCount < oldCount → falls back to full diff
    #expect(changeset.itemDeletes.contains(IndexPath(item: 2, section: 0)))
  }

  // MARK: - itemUpdates in Full Diff

  @Test
  func fullDiffProducesItemUpdatesForMatchedPairs() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3, 4], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 3, 5], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .full)
    // Items 1 and 3 survive; 2 and 4 deleted; 5 inserted
    let survivingIds = Set(changeset.itemUpdates.map(\.itemId))
    #expect(survivingIds.contains(1))
    #expect(survivingIds.contains(3))
    #expect(!survivingIds.contains(2))
    #expect(!survivingIds.contains(4))
    #expect(!survivingIds.contains(5))
  }

  @Test
  func fullDiffNoUpdatesWhenItemsIdentical() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2, 3], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .full)
    // Identical sections → no itemUpdates, changeset is empty
    #expect(changeset.isEmpty)
    #expect(changeset.itemUpdates.isEmpty)
  }

  @Test
  func fullDiffItemUpdatePathsReflectMovement() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([3, 1, 2], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .full)
    // All 3 items survive with different paths
    #expect(changeset.itemUpdates.count == 3)
    let updateFor1 = changeset.itemUpdates.first { $0.itemId == 1 }!
    #expect(updateFor1.oldPath.item == 0)
    #expect(updateFor1.newPath.item == 1)
  }

  // MARK: - isEmpty / hasStructuralChanges Semantics with itemUpdates

  @Test
  func onlyItemUpdatesIsNotEmpty() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .streaming)
    // Streaming always produces itemUpdates for matched prefix
    #expect(!changeset.isEmpty)
    #expect(changeset.itemUpdates.count == 2)
  }

  @Test
  func onlyItemUpdatesHasNoStructuralChanges() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .streaming)
    #expect(!changeset.hasStructuralChanges)
  }

  @Test
  func streamingAppendHasStructuralChanges() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .streaming)
    // Has inserts → structural
    #expect(changeset.hasStructuralChanges)
    // Also has updates for matched prefix
    #expect(changeset.itemUpdates.count == 1)
    #expect(changeset.itemUpdates[0].itemId == 1)
  }

  // MARK: - Streaming with Reload/Reconfigure Markers

  @Test
  func streamingPreservesReconfigureMarkers() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2, 3], toSection: "A")
    new.reconfigureItems([1])

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .streaming)
    #expect(changeset.itemReconfigures.contains(IndexPath(item: 0, section: 0)))
    #expect(changeset.itemUpdates.count == 2)
    #expect(changeset.itemInserts.count == 1)
  }

  @Test
  func streamingPreservesReloadMarkers() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2], toSection: "A")
    new.reloadSections(["A"])

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .streaming)
    #expect(changeset.sectionReloads == IndexSet([0]))
  }

  // MARK: - Cross-Section Move Decomposition

  @Test
  func crossSectionMoveDecomposedInFullDiff() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A", "B"])
    old.appendItems([1, 2], toSection: "A")
    old.appendItems([3], toSection: "B")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A", "B"])
    new.appendItems([1], toSection: "A")
    new.appendItems([3, 2], toSection: "B")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .full)
    // No cross-section moves
    let hasCrossMove = changeset.itemMoves.contains { $0.from.section != $0.to.section }
    #expect(!hasCrossMove)
    // Item 2: delete from A + insert into B
    #expect(changeset.itemDeletes.contains(IndexPath(item: 1, section: 0)))
    #expect(changeset.itemInserts.contains(IndexPath(item: 1, section: 1)))
  }

  @Test
  func withinSectionMovesStillWork() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([3, 1, 2], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .full)
    // Within-section moves still emitted
    #expect(!changeset.itemMoves.isEmpty)
    // All moves are within the same section
    #expect(changeset.itemMoves.allSatisfy { $0.from.section == $0.to.section })
  }
}
