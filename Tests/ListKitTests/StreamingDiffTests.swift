// ABOUTME: Tests for DiffStrategy.streaming — prefix matching, fallback to full, and marker preservation.
// ABOUTME: Covers the O(n) streaming fast-path and its graceful degradation to full diff.

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
  func streamingIdenticalSnapshotIsEmpty() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1, 2, 3], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2, 3], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .streaming)
    #expect(changeset.isEmpty)
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
    #expect(changeset.itemInserts.count == 2) // 3 in A + 20 in B
    #expect(changeset.sectionDeletes.isEmpty)
    #expect(changeset.sectionInserts.isEmpty)
  }

  @Test
  func streamingEmptyOldFallsBackToFull() {
    let old = DiffableDataSourceSnapshot<String, Int>()

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2], toSection: "A")

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
    #expect(changeset.hasStructuralChanges)
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
    #expect(changeset.itemDeletes.contains(IndexPath(item: 2, section: 0)))
  }

  // MARK: - isEmpty / hasStructuralChanges Semantics

  @Test
  func streamingAppendHasStructuralChanges() {
    var old = DiffableDataSourceSnapshot<String, Int>()
    old.appendSections(["A"])
    old.appendItems([1], toSection: "A")

    var new = DiffableDataSourceSnapshot<String, Int>()
    new.appendSections(["A"])
    new.appendItems([1, 2], toSection: "A")

    let changeset = SectionedDiff.diff(old: old, new: new, strategy: .streaming)
    #expect(changeset.hasStructuralChanges)
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
    let hasCrossMove = changeset.itemMoves.contains { $0.from.section != $0.to.section }
    #expect(hasCrossMove)
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
    #expect(!changeset.itemMoves.isEmpty)
    #expect(changeset.itemMoves.allSatisfy { $0.from.section == $0.to.section })
  }
}
