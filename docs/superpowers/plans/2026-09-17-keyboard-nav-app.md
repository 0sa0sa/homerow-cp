# キーボードナビゲーションアプリ (HomerowCP) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOSのAccessibility APIを使い、キーボードだけでUI要素をクリック操作できるユーティリティ(Homerow相当)をSwiftネイティブで実装する。バックグラウンド事前キャッシュにより起動レイテンシを最小化し、頻度ベースのラベル優先表示とRaycast水準のUIを備える。

**Architecture:** `AccessibilityIndexer`がバックグラウンドで`AXObserver`通知を購読し、フォーカスウィンドウのクリック可能要素を`WindowCache`へ非同期に反映し続ける。ホットキー押下時は`OverlayController`が`WindowCache`を同期的に参照し、`LabelAssignmentEngine`で頻度順にラベルを割当ててSwiftUIオーバーレイを描画する。純粋ロジック(ラベル割当・頻度スコアリング・検索フィルタ・入力ルーティング・スクロール方向計算・キーコンボ解析)は`HomerowCPCore`にまとめてXCTestで検証し、AXUIElement/SwiftUI/グローバルホットキー登録などOS連携部分は薄いラッパーとして分離し手動検証する。

**Tech Stack:** Swift 5.9+, Swift Package Manager(Xcodeプロジェクト不使用), SwiftUI + AppKit(NSPanel), ApplicationServices(Accessibility API), Carbon.HIToolbox(グローバルホットキー), XCTest。

**Spec:** `docs/superpowers/specs/2026-09-17-keyboard-nav-app-design.md`

## Global Constraints

- macOS 13.0以上をターゲットとする(SwiftUIの新しいAPIを前提とし、実装コストを下げるための決定。オリジナルのHomerowのmacOS 12.3+より新しいが、機能面での要求はない)
- 依存ライブラリは追加しない。SwiftUI/AppKit/ApplicationServices/Carbon.HIToolboxなどApple標準フレームワークのみを使う(YAGNI: v1ではSQLite等の外部依存を避け、頻度データはJSONファイル永続化とする)
- パッケージ/モジュール名は`HomerowCP`を用いる
- App Store配布は前提としない。サンドボックス化しない
- ラベル文字はホームロー`asdfghjkl`(9文字)を基本とし、要素数がそれを超える場合のみ2文字ラベルにフォールバックする

---

## Task 1: プロジェクト雛形

**Files:**
- Create: `Package.swift`
- Create: `Sources/HomerowCPCore/.gitkeep`(直後に実ファイルへ置換されるため空実装で可)
- Create: `Sources/HomerowCPAccessibility/.gitkeep`
- Create: `Sources/HomerowCPUI/.gitkeep`
- Create: `Sources/HomerowCPApp/main.swift`
- Create: `Tests/HomerowCPCoreTests/SanityTests.swift`
- Create: `.gitignore`

**Interfaces:**
- Produces: `HomerowCPCore`, `HomerowCPAccessibility`, `HomerowCPUI` (ライブラリターゲット)、`HomerowCPApp` (実行可能ターゲット)というターゲット名。以降のタスクはこれらのターゲットにファイルを追加していく。

- [ ] **Step 1: Package.swiftを作成**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HomerowCP",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "HomerowCPCore", path: "Sources/HomerowCPCore"),
        .target(
            name: "HomerowCPAccessibility",
            dependencies: ["HomerowCPCore"],
            path: "Sources/HomerowCPAccessibility"
        ),
        .target(
            name: "HomerowCPUI",
            dependencies: ["HomerowCPCore"],
            path: "Sources/HomerowCPUI"
        ),
        .executableTarget(
            name: "HomerowCPApp",
            dependencies: ["HomerowCPCore", "HomerowCPAccessibility", "HomerowCPUI"],
            path: "Sources/HomerowCPApp"
        ),
        .testTarget(
            name: "HomerowCPCoreTests",
            dependencies: ["HomerowCPCore"],
            path: "Tests/HomerowCPCoreTests"
        ),
    ]
)
```

- [ ] **Step 2: .gitignoreを作成**

```
.build/
.swiftpm/
*.xcodeproj
.DS_Store
```

- [ ] **Step 3: 各ターゲットの最小ソースを作成**

`Sources/HomerowCPCore/HomerowCPCore.swift`:
```swift
public enum HomerowCPCore {
    public static let version = "0.1.0"
}
```

`Sources/HomerowCPAccessibility/HomerowCPAccessibility.swift`:
```swift
import HomerowCPCore

public enum HomerowCPAccessibility {}
```

`Sources/HomerowCPUI/HomerowCPUI.swift`:
```swift
import HomerowCPCore

public enum HomerowCPUI {}
```

`Sources/HomerowCPApp/main.swift`:
```swift
import HomerowCPCore

print("HomerowCP \(HomerowCPCore.version) starting...")
```

- [ ] **Step 4: サニティテストを作成**

`Tests/HomerowCPCoreTests/SanityTests.swift`:
```swift
import XCTest
@testable import HomerowCPCore

final class SanityTests: XCTestCase {
    func test_versionIsSet() {
        XCTAssertEqual(HomerowCPCore.version, "0.1.0")
    }
}
```

- [ ] **Step 5: ビルドとテストを実行して通ることを確認**

Run: `cd /Users/osa/projects/homerow-cp && swift build && swift test`
Expected: ビルド成功、`SanityTests`が1件PASS

- [ ] **Step 6: Commit**

```bash
git add Package.swift .gitignore Sources Tests
git commit -m "chore: scaffold HomerowCP Swift package"
```

---

## Task 2: コアモデル + 安定ID生成

**Files:**
- Create: `Sources/HomerowCPCore/ClickableElement.swift`
- Create: `Sources/HomerowCPCore/StableIDGenerator.swift`
- Test: `Tests/HomerowCPCoreTests/StableIDGeneratorTests.swift`

**Interfaces:**
- Produces:
  - `public struct ElementFrame { let x, y, width, height: Double }`
  - `public struct ClickableElement { let stableID: String; let role: String; let title: String?; let frame: ElementFrame }`
  - `public enum StableIDGenerator { static func makeID(bundleID: String, windowRole: String, elementRole: String, title: String?, approximatePosition: (row: Int, col: Int)) -> String }`
  - `public func bucketedPosition(x: Double, y: Double, bucketSize: Double = 50) -> (row: Int, col: Int)`

- [ ] **Step 1: 失敗するテストを書く**

`Tests/HomerowCPCoreTests/StableIDGeneratorTests.swift`:
```swift
import XCTest
@testable import HomerowCPCore

final class StableIDGeneratorTests: XCTestCase {
    func test_sameInputsProduceSameID() {
        let id1 = StableIDGenerator.makeID(
            bundleID: "com.apple.finder", windowRole: "AXWindow",
            elementRole: "AXButton", title: "Save",
            approximatePosition: (row: 2, col: 3)
        )
        let id2 = StableIDGenerator.makeID(
            bundleID: "com.apple.finder", windowRole: "AXWindow",
            elementRole: "AXButton", title: "Save",
            approximatePosition: (row: 2, col: 3)
        )
        XCTAssertEqual(id1, id2)
    }

    func test_differentTitlesProduceDifferentIDs() {
        let id1 = StableIDGenerator.makeID(
            bundleID: "com.apple.finder", windowRole: "AXWindow",
            elementRole: "AXButton", title: "Save",
            approximatePosition: (row: 2, col: 3)
        )
        let id2 = StableIDGenerator.makeID(
            bundleID: "com.apple.finder", windowRole: "AXWindow",
            elementRole: "AXButton", title: "Cancel",
            approximatePosition: (row: 2, col: 3)
        )
        XCTAssertNotEqual(id1, id2)
    }

    func test_bucketedPositionRoundsNearbyPointsToSameBucket() {
        let a = bucketedPosition(x: 101, y: 202)
        let b = bucketedPosition(x: 110, y: 210)
        XCTAssertEqual(a.row, b.row)
        XCTAssertEqual(a.col, b.col)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `swift test --filter StableIDGeneratorTests`
Expected: FAIL(型・関数が存在しない)

- [ ] **Step 3: 実装**

`Sources/HomerowCPCore/ClickableElement.swift`:
```swift
public struct ElementFrame: Equatable, Codable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct ClickableElement: Equatable {
    public let stableID: String
    public let role: String
    public let title: String?
    public let frame: ElementFrame

    public init(stableID: String, role: String, title: String?, frame: ElementFrame) {
        self.stableID = stableID
        self.role = role
        self.title = title
        self.frame = frame
    }
}
```

`Sources/HomerowCPCore/StableIDGenerator.swift`:
```swift
public func bucketedPosition(x: Double, y: Double, bucketSize: Double = 50) -> (row: Int, col: Int) {
    (row: Int((y / bucketSize).rounded()), col: Int((x / bucketSize).rounded()))
}

public enum StableIDGenerator {
    public static func makeID(
        bundleID: String,
        windowRole: String,
        elementRole: String,
        title: String?,
        approximatePosition: (row: Int, col: Int)
    ) -> String {
        let titlePart = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(bundleID)|\(windowRole)|\(elementRole)|\(titlePart)|\(approximatePosition.row),\(approximatePosition.col)"
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `swift test --filter StableIDGeneratorTests`
Expected: 3件PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/HomerowCPCore/ClickableElement.swift Sources/HomerowCPCore/StableIDGenerator.swift Tests/HomerowCPCoreTests/StableIDGeneratorTests.swift
git commit -m "feat: add ClickableElement model and stable ID generator"
```

---

## Task 3: LabelAssignmentEngine

**Files:**
- Create: `Sources/HomerowCPCore/LabelAssignmentEngine.swift`
- Test: `Tests/HomerowCPCoreTests/LabelAssignmentEngineTests.swift`

**Interfaces:**
- Consumes: `ClickableElement`(Task 2)
- Produces:
  - `public struct LabelAssignment: Equatable { let elementID: String; let label: String }`
  - `public struct LabelAssignmentEngine { static let homeRowChars: [Character]; func assignLabels(elements: [ClickableElement], frequencyScores: [String: Double] = [:], previousAssignments: [String: String] = [:]) -> [LabelAssignment] }`

- [ ] **Step 1: 失敗するテストを書く**

`Tests/HomerowCPCoreTests/LabelAssignmentEngineTests.swift`:
```swift
import XCTest
@testable import HomerowCPCore

final class LabelAssignmentEngineTests: XCTestCase {
    func makeElement(_ id: String) -> ClickableElement {
        ClickableElement(stableID: id, role: "AXButton", title: id, frame: ElementFrame(x: 0, y: 0, width: 10, height: 10))
    }

    func test_assignsSingleCharLabelsWhenFewerElementsThanHomeRowChars() {
        let engine = LabelAssignmentEngine()
        let elements = ["a", "b", "c"].map(makeElement)
        let result = engine.assignLabels(elements: elements)
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.allSatisfy { $0.label.count == 1 })
    }

    func test_higherFrequencyElementsGetShorterLabels() {
        let engine = LabelAssignmentEngine()
        let elements = (1...12).map { makeElement("el\($0)") }
        var scores: [String: Double] = [:]
        for i in 1...12 { scores["el\(i)"] = Double(12 - i) }
        let result = engine.assignLabels(elements: elements, frequencyScores: scores)
        let topElement = result.first { $0.elementID == "el1" }
        XCTAssertEqual(topElement?.label.count, 1)
        let lowestElement = result.first { $0.elementID == "el12" }
        XCTAssertEqual(lowestElement?.label.count, 2)
    }

    func test_preservesPreviousLabelWhenStillAvailable() {
        let engine = LabelAssignmentEngine()
        let elements = ["a", "b", "c"].map(makeElement)
        let first = engine.assignLabels(elements: elements)
        let previous = Dictionary(uniqueKeysWithValues: first.map { ($0.elementID, $0.label) })
        let second = engine.assignLabels(elements: elements, previousAssignments: previous)
        XCTAssertEqual(Set(first), Set(second))
    }

    func test_overflowUsesTwoCharLabelsWhenMoreThanNineElements() {
        let engine = LabelAssignmentEngine()
        let elements = (1...15).map { makeElement("el\($0)") }
        let result = engine.assignLabels(elements: elements)
        let twoCharCount = result.filter { $0.label.count == 2 }.count
        XCTAssertEqual(twoCharCount, 15 - LabelAssignmentEngine.homeRowChars.count)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `swift test --filter LabelAssignmentEngineTests`
Expected: FAIL(型が存在しない)

- [ ] **Step 3: 実装**

`Sources/HomerowCPCore/LabelAssignmentEngine.swift`:
```swift
public struct LabelAssignment: Equatable, Hashable {
    public let elementID: String
    public let label: String

    public init(elementID: String, label: String) {
        self.elementID = elementID
        self.label = label
    }
}

public struct LabelAssignmentEngine {
    public static let homeRowChars: [Character] = Array("asdfghjkl")

    public init() {}

    public func assignLabels(
        elements: [ClickableElement],
        frequencyScores: [String: Double] = [:],
        previousAssignments: [String: String] = [:]
    ) -> [LabelAssignment] {
        let sortedElements = elements.sorted { lhs, rhs in
            let l = frequencyScores[lhs.stableID] ?? 0
            let r = frequencyScores[rhs.stableID] ?? 0
            if l != r { return l > r }
            return lhs.stableID < rhs.stableID
        }

        var pool = generateLabelPool(count: sortedElements.count)
        var assignedElementIDs = Set<String>()
        var result: [LabelAssignment] = []

        for element in sortedElements {
            guard let prev = previousAssignments[element.stableID],
                  let index = pool.firstIndex(of: prev) else { continue }
            pool.remove(at: index)
            assignedElementIDs.insert(element.stableID)
            result.append(LabelAssignment(elementID: element.stableID, label: prev))
        }

        for element in sortedElements {
            guard !assignedElementIDs.contains(element.stableID) else { continue }
            guard !pool.isEmpty else { break }
            let label = pool.removeFirst()
            assignedElementIDs.insert(element.stableID)
            result.append(LabelAssignment(elementID: element.stableID, label: label))
        }

        return result
    }

    private func generateLabelPool(count: Int) -> [String] {
        var pool: [String] = Self.homeRowChars.map { String($0) }
        if count > pool.count {
            outer: for c1 in Self.homeRowChars {
                for c2 in Self.homeRowChars {
                    pool.append("\(c1)\(c2)")
                    if pool.count >= count { break outer }
                }
            }
        }
        return pool
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `swift test --filter LabelAssignmentEngineTests`
Expected: 4件PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/HomerowCPCore/LabelAssignmentEngine.swift Tests/HomerowCPCoreTests/LabelAssignmentEngineTests.swift
git commit -m "feat: add frequency-aware label assignment engine"
```

---

## Task 4: FrequencyTracker

**Files:**
- Create: `Sources/HomerowCPCore/FrequencyTracker.swift`
- Test: `Tests/HomerowCPCoreTests/FrequencyTrackerTests.swift`

**Interfaces:**
- Produces:
  - `public struct FrequencyRecord: Codable, Equatable { var count: Double; var lastUsed: Date }`
  - `public final class FrequencyTracker { init(storeURL: URL, decayFactor: Double = 0.98); func score(for elementID: String) -> Double; func recordSelection(elementID: String, now: Date = Date()); func reset(); func persist() throws }`
- 後続タスク(OverlayController)は`score(for:)`を`LabelAssignmentEngine.assignLabels(frequencyScores:)`に渡す辞書の構築に使う。

- [ ] **Step 1: 失敗するテストを書く**

`Tests/HomerowCPCoreTests/FrequencyTrackerTests.swift`:
```swift
import XCTest
@testable import HomerowCPCore

final class FrequencyTrackerTests: XCTestCase {
    func tempStoreURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("freq-\(UUID().uuidString).json")
    }

    func test_recordSelectionIncrementsScore() {
        let tracker = FrequencyTracker(storeURL: tempStoreURL())
        XCTAssertEqual(tracker.score(for: "el1"), 0)
        tracker.recordSelection(elementID: "el1")
        XCTAssertEqual(tracker.score(for: "el1"), 1)
        tracker.recordSelection(elementID: "el1")
        XCTAssertEqual(tracker.score(for: "el1"), 2)
    }

    func test_decayReducesScoreOverTime() {
        let tracker = FrequencyTracker(storeURL: tempStoreURL(), decayFactor: 0.5)
        let day0 = Date(timeIntervalSince1970: 0)
        tracker.recordSelection(elementID: "el1", now: day0)
        let day2 = day0.addingTimeInterval(2 * 24 * 60 * 60)
        tracker.recordSelection(elementID: "el2", now: day2) // triggers decay pass
        XCTAssertEqual(tracker.score(for: "el1"), 0.25, accuracy: 0.0001) // 1 * 0.5^2
    }

    func test_persistAndReloadRoundTrips() throws {
        let url = tempStoreURL()
        let tracker = FrequencyTracker(storeURL: url)
        tracker.recordSelection(elementID: "el1")
        try tracker.persist()

        let reloaded = FrequencyTracker(storeURL: url)
        XCTAssertEqual(reloaded.score(for: "el1"), 1)
    }

    func test_resetClearsScores() {
        let tracker = FrequencyTracker(storeURL: tempStoreURL())
        tracker.recordSelection(elementID: "el1")
        tracker.reset()
        XCTAssertEqual(tracker.score(for: "el1"), 0)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `swift test --filter FrequencyTrackerTests`
Expected: FAIL(型が存在しない)

- [ ] **Step 3: 実装**

`Sources/HomerowCPCore/FrequencyTracker.swift`:
```swift
import Foundation

public struct FrequencyRecord: Codable, Equatable {
    public var count: Double
    public var lastUsed: Date
}

public final class FrequencyTracker {
    private var records: [String: FrequencyRecord]
    private let decayFactor: Double
    private let storeURL: URL

    public init(storeURL: URL, decayFactor: Double = 0.98) {
        self.storeURL = storeURL
        self.decayFactor = decayFactor
        self.records = Self.load(from: storeURL)
    }

    public func score(for elementID: String) -> Double {
        records[elementID]?.count ?? 0
    }

    public func recordSelection(elementID: String, now: Date = Date()) {
        applyDecayIfNeeded(now: now)
        var record = records[elementID] ?? FrequencyRecord(count: 0, lastUsed: now)
        record.count += 1
        record.lastUsed = now
        records[elementID] = record
    }

    public func reset() {
        records = [:]
    }

    public func persist() throws {
        let data = try JSONEncoder().encode(records)
        try data.write(to: storeURL, options: .atomic)
    }

    private func applyDecayIfNeeded(now: Date) {
        let calendar = Calendar(identifier: .gregorian)
        for (id, record) in records {
            let days = calendar.dateComponents([.day], from: record.lastUsed, to: now).day ?? 0
            guard days > 0 else { continue }
            var updated = record
            updated.count *= pow(decayFactor, Double(days))
            records[id] = updated
        }
    }

    private static func load(from url: URL) -> [String: FrequencyRecord] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: FrequencyRecord].self, from: data)) ?? [:]
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `swift test --filter FrequencyTrackerTests`
Expected: 4件PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/HomerowCPCore/FrequencyTracker.swift Tests/HomerowCPCoreTests/FrequencyTrackerTests.swift
git commit -m "feat: add JSON-backed frequency tracker with decay"
```

---

## Task 5: SearchFilter

**Files:**
- Create: `Sources/HomerowCPCore/SearchFilter.swift`
- Test: `Tests/HomerowCPCoreTests/SearchFilterTests.swift`

**Interfaces:**
- Consumes: `ClickableElement`(Task 2)
- Produces: `public struct SearchFilter { func matches(query: String, candidate: String) -> Bool; func filter(query: String, elements: [ClickableElement]) -> [ClickableElement] }`

- [ ] **Step 1: 失敗するテストを書く**

`Tests/HomerowCPCoreTests/SearchFilterTests.swift`:
```swift
import XCTest
@testable import HomerowCPCore

final class SearchFilterTests: XCTestCase {
    let filter = SearchFilter()

    func test_emptyQueryMatchesEverything() {
        XCTAssertTrue(filter.matches(query: "", candidate: "Save Document"))
    }

    func test_matchesSubsequenceIgnoringCaseAndSpaces() {
        XCTAssertTrue(filter.matches(query: "svdoc", candidate: "Save Document"))
    }

    func test_doesNotMatchWhenCharsOutOfOrder() {
        XCTAssertFalse(filter.matches(query: "docsv", candidate: "Save Document"))
    }

    func test_filterReturnsOnlyMatchingElements() {
        let elements = [
            ClickableElement(stableID: "1", role: "AXButton", title: "Save Document", frame: ElementFrame(x: 0, y: 0, width: 1, height: 1)),
            ClickableElement(stableID: "2", role: "AXButton", title: "Cancel", frame: ElementFrame(x: 0, y: 0, width: 1, height: 1)),
        ]
        let result = filter.filter(query: "save", elements: elements)
        XCTAssertEqual(result.map(\.stableID), ["1"])
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `swift test --filter SearchFilterTests`
Expected: FAIL

- [ ] **Step 3: 実装**

`Sources/HomerowCPCore/SearchFilter.swift`:
```swift
public struct SearchFilter {
    public init() {}

    public func matches(query: String, candidate: String) -> Bool {
        guard !query.isEmpty else { return true }
        let normalizedQuery = query.lowercased().replacingOccurrences(of: " ", with: "")
        let normalizedCandidate = candidate.lowercased().replacingOccurrences(of: " ", with: "")

        var searchStart = normalizedCandidate.startIndex
        for qChar in normalizedQuery {
            guard searchStart < normalizedCandidate.endIndex,
                  let foundIndex = normalizedCandidate[searchStart...].firstIndex(of: qChar) else {
                return false
            }
            searchStart = normalizedCandidate.index(after: foundIndex)
        }
        return true
    }

    public func filter(query: String, elements: [ClickableElement]) -> [ClickableElement] {
        elements.filter { matches(query: query, candidate: $0.title ?? "") }
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `swift test --filter SearchFilterTests`
Expected: 4件PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/HomerowCPCore/SearchFilter.swift Tests/HomerowCPCoreTests/SearchFilterTests.swift
git commit -m "feat: add fuzzy subsequence search filter"
```

---

## Task 6: ClickableElementScanner + 実AXアダプタ

**Files:**
- Create: `Sources/HomerowCPCore/AXNode.swift`
- Create: `Sources/HomerowCPCore/ClickableElementScanner.swift`
- Create: `Sources/HomerowCPAccessibility/LiveAXNode.swift`
- Test: `Tests/HomerowCPCoreTests/ClickableElementScannerTests.swift`

**Interfaces:**
- Consumes: `ClickableElement`, `StableIDGenerator`, `bucketedPosition`(Task 2)
- Produces:
  - `public protocol AXNode { var role: String; var title: String?; var frame: ElementFrame?; var isEnabled: Bool; var children: [AXNode] }`
  - `public struct ClickableElementScanner { static let defaultClickableRoles: Set<String>; init(bundleID: String, windowRole: String, clickableRoles: Set<String> = defaultClickableRoles); func scan(root: AXNode, maxDepth: Int = 50) -> [ClickableElement]; func scanPaired(root: AXNode, maxDepth: Int = 50) -> [(element: ClickableElement, node: AXNode)] }`
  - `final class LiveAXNode: AXNode`(HomerowCPAccessibilityターゲット、実AXUIElementラッパー。`underlyingElement: AXUIElement`をpublicに公開し、Task 7が`scanPaired`の結果からクリック実行用の実要素を復元できるようにする。手動検証対象)

- [ ] **Step 1: 失敗するテストを書く**

`Tests/HomerowCPCoreTests/ClickableElementScannerTests.swift`:
```swift
import XCTest
@testable import HomerowCPCore

final class FakeAXNode: AXNode {
    let role: String
    let title: String?
    let frame: ElementFrame?
    let isEnabled: Bool
    var children: [AXNode]

    init(role: String, title: String? = nil, frame: ElementFrame? = ElementFrame(x: 0, y: 0, width: 10, height: 10), isEnabled: Bool = true, children: [AXNode] = []) {
        self.role = role
        self.title = title
        self.frame = frame
        self.isEnabled = isEnabled
        self.children = children
    }
}

final class ClickableElementScannerTests: XCTestCase {
    func test_findsClickableElementsAndSkipsNonClickableRoles() {
        let root = FakeAXNode(role: "AXWindow", frame: nil, children: [
            FakeAXNode(role: "AXButton", title: "Save"),
            FakeAXNode(role: "AXGroup", frame: nil, children: [
                FakeAXNode(role: "AXLink", title: "Learn More"),
            ]),
        ])
        let scanner = ClickableElementScanner(bundleID: "com.example.app", windowRole: "AXWindow")
        let result = scanner.scan(root: root)
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains { $0.title == "Save" })
        XCTAssertTrue(result.contains { $0.title == "Learn More" })
    }

    func test_skipsDisabledElements() {
        let root = FakeAXNode(role: "AXWindow", frame: nil, children: [
            FakeAXNode(role: "AXButton", title: "Disabled", isEnabled: false),
        ])
        let scanner = ClickableElementScanner(bundleID: "com.example.app", windowRole: "AXWindow")
        let result = scanner.scan(root: root)
        XCTAssertTrue(result.isEmpty)
    }

    func test_skipsElementsWithoutFrame() {
        let root = FakeAXNode(role: "AXWindow", frame: nil, children: [
            FakeAXNode(role: "AXButton", title: "NoFrame", frame: nil),
        ])
        let scanner = ClickableElementScanner(bundleID: "com.example.app", windowRole: "AXWindow")
        let result = scanner.scan(root: root)
        XCTAssertTrue(result.isEmpty)
    }

    func test_scanPairedReturnsMatchingSourceNode() {
        let button = FakeAXNode(role: "AXButton", title: "Save")
        let root = FakeAXNode(role: "AXWindow", frame: nil, children: [button])
        let scanner = ClickableElementScanner(bundleID: "com.example.app", windowRole: "AXWindow")
        let pairs = scanner.scanPaired(root: root)
        XCTAssertEqual(pairs.count, 1)
        XCTAssertTrue(pairs[0].node as? FakeAXNode === button)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `swift test --filter ClickableElementScannerTests`
Expected: FAIL

- [ ] **Step 3: 実装**

`Sources/HomerowCPCore/AXNode.swift`:
```swift
public protocol AXNode {
    var role: String { get }
    var title: String? { get }
    var frame: ElementFrame? { get }
    var isEnabled: Bool { get }
    var children: [AXNode] { get }
}
```

`Sources/HomerowCPCore/ClickableElementScanner.swift`:
```swift
public struct ClickableElementScanner {
    public static let defaultClickableRoles: Set<String> = [
        "AXButton", "AXCheckBox", "AXRadioButton", "AXPopUpButton",
        "AXMenuButton", "AXLink", "AXTextField", "AXComboBox",
        "AXDisclosureTriangle", "AXTab", "AXMenuItem",
    ]

    private let bundleID: String
    private let windowRole: String
    private let clickableRoles: Set<String>

    public init(bundleID: String, windowRole: String, clickableRoles: Set<String> = ClickableElementScanner.defaultClickableRoles) {
        self.bundleID = bundleID
        self.windowRole = windowRole
        self.clickableRoles = clickableRoles
    }

    public func scan(root: AXNode, maxDepth: Int = 50) -> [ClickableElement] {
        scanPaired(root: root, maxDepth: maxDepth).map(\.element)
    }

    /// Same traversal as `scan`, but also returns the source `AXNode` for each result.
    /// `AccessibilityIndexer` uses the paired node (downcast to `LiveAXNode`) to recover
    /// the underlying `AXUIElement` needed to actually perform a click.
    public func scanPaired(root: AXNode, maxDepth: Int = 50) -> [(element: ClickableElement, node: AXNode)] {
        var results: [(element: ClickableElement, node: AXNode)] = []
        walk(node: root, depth: 0, maxDepth: maxDepth, into: &results)
        return results
    }

    private func walk(node: AXNode, depth: Int, maxDepth: Int, into results: inout [(element: ClickableElement, node: AXNode)]) {
        guard depth <= maxDepth else { return }

        if clickableRoles.contains(node.role), node.isEnabled, let frame = node.frame {
            let bucketed = bucketedPosition(x: frame.x, y: frame.y)
            let id = StableIDGenerator.makeID(
                bundleID: bundleID,
                windowRole: windowRole,
                elementRole: node.role,
                title: node.title,
                approximatePosition: bucketed
            )
            let clickable = ClickableElement(stableID: id, role: node.role, title: node.title, frame: frame)
            results.append((element: clickable, node: node))
        }

        for child in node.children {
            walk(node: child, depth: depth + 1, maxDepth: maxDepth, into: &results)
        }
    }
}
```

`Sources/HomerowCPAccessibility/LiveAXNode.swift`(手動検証対象。実機のAccessibility権限が必要):
```swift
import ApplicationServices
import HomerowCPCore

public final class LiveAXNode: AXNode {
    public let underlyingElement: AXUIElement
    private var element: AXUIElement { underlyingElement }

    public init(element: AXUIElement) {
        self.underlyingElement = element
    }

    public var role: String {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        return value as? String ?? ""
    }

    public var title: String? {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value)
        return value as? String
    }

    public var isEnabled: Bool {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &value)
        return (value as? Bool) ?? true
    }

    public var frame: ElementFrame? {
        var positionValue: AnyObject?
        var sizeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionAXValue = positionValue, let sizeAXValue = sizeValue else {
            return nil
        }
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionAXValue as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeAXValue as! AXValue, .cgSize, &size)
        return ElementFrame(x: point.x, y: point.y, width: size.width, height: size.height)
    }

    public var children: [AXNode] {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard let axChildren = value as? [AXUIElement] else { return [] }
        return axChildren.map { LiveAXNode(element: $0) }
    }
}
```

- [ ] **Step 4: テストとビルドを確認**

Run: `swift build && swift test --filter ClickableElementScannerTests`
Expected: ビルド成功、4件PASS

- [ ] **Step 5: 手動検証(LiveAXNode)**

後続タスク(Task 7)でLiveAXNodeを実際のAXUIElementに接続した後、Finder等のウィンドウに対して`scan`を実行し、ボタン・リンク等が正しく列挙されることを目視確認する(このタスク単体では未接続のため自動検証不可)。

- [ ] **Step 6: Commit**

```bash
git add Sources/HomerowCPCore/AXNode.swift Sources/HomerowCPCore/ClickableElementScanner.swift Sources/HomerowCPAccessibility/LiveAXNode.swift Tests/HomerowCPCoreTests/ClickableElementScannerTests.swift
git commit -m "feat: add AX tree scanner with fake-testable protocol and live adapter"
```

---

## Task 7: WindowCache + AccessibilityIndexer

**Files:**
- Create: `Sources/HomerowCPCore/WindowCache.swift`
- Create: `Sources/HomerowCPAccessibility/AccessibilityIndexer.swift`
- Test: `Tests/HomerowCPCoreTests/WindowCacheTests.swift`

**Interfaces:**
- Consumes: `ClickableElement`(Task 2), `ClickableElementScanner`, `AXNode`(Task 6), `LiveAXNode`(Task 6)
- Produces:
  - `public struct WindowKey: Hashable { let bundleID: String; let windowID: Int }`
  - `public final class WindowCache { func elements(for key: WindowKey) -> [ClickableElement]?; func update(_ elements: [ClickableElement], for key: WindowKey); func invalidate(_ key: WindowKey) }`
  - `public final class AccessibilityIndexer { init(cache: WindowCache); func start(); func stop(); var lastCachedKey: WindowKey? { get }; func axElement(for stableID: String) -> AXUIElement? }`(手動検証対象。`lastCachedKey`は最後にキャッシュを更新したウィンドウのキーで、Task 14の`AppCoordinator`がホットキー押下時にどのキーで`WindowCache`を参照すべきか調べるのに使う。`axElement(for:)`はTask 8の`LiveClickPerformer`が実際にクリックを実行するための生の`AXUIElement`を返す)

- [ ] **Step 1: 失敗するテストを書く**

`Tests/HomerowCPCoreTests/WindowCacheTests.swift`:
```swift
import XCTest
@testable import HomerowCPCore

final class WindowCacheTests: XCTestCase {
    func test_updateThenReadReturnsElements() {
        let cache = WindowCache()
        let key = WindowKey(bundleID: "com.apple.finder", windowID: 1)
        let element = ClickableElement(stableID: "1", role: "AXButton", title: "Save", frame: ElementFrame(x: 0, y: 0, width: 1, height: 1))
        cache.update([element], for: key)
        XCTAssertEqual(cache.elements(for: key), [element])
    }

    func test_missingKeyReturnsNil() {
        let cache = WindowCache()
        let key = WindowKey(bundleID: "com.apple.finder", windowID: 99)
        XCTAssertNil(cache.elements(for: key))
    }

    func test_invalidateRemovesEntry() {
        let cache = WindowCache()
        let key = WindowKey(bundleID: "com.apple.finder", windowID: 1)
        cache.update([], for: key)
        cache.invalidate(key)
        XCTAssertNil(cache.elements(for: key))
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `swift test --filter WindowCacheTests`
Expected: FAIL

- [ ] **Step 3: WindowCacheを実装**

`Sources/HomerowCPCore/WindowCache.swift`:
```swift
import Foundation

public struct WindowKey: Hashable {
    public let bundleID: String
    public let windowID: Int

    public init(bundleID: String, windowID: Int) {
        self.bundleID = bundleID
        self.windowID = windowID
    }
}

public final class WindowCache {
    private var storage: [WindowKey: [ClickableElement]] = [:]
    private let lock = NSLock()

    public init() {}

    public func elements(for key: WindowKey) -> [ClickableElement]? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]
    }

    public func update(_ elements: [ClickableElement], for key: WindowKey) {
        lock.lock(); defer { lock.unlock() }
        storage[key] = elements
    }

    public func invalidate(_ key: WindowKey) {
        lock.lock(); defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `swift test --filter WindowCacheTests`
Expected: 3件PASS

- [ ] **Step 5: AccessibilityIndexerを実装(手動検証対象)**

`Sources/HomerowCPAccessibility/AccessibilityIndexer.swift`:
```swift
import AppKit
import ApplicationServices
import HomerowCPCore

public final class AccessibilityIndexer {
    private let cache: WindowCache
    private var observer: AXObserver?
    private var currentAppElement: AXUIElement?
    private var currentBundleID: String?
    private var workspaceToken: NSObjectProtocol?
    public private(set) var lastCachedKey: WindowKey?
    private var axElementLookup: [String: AXUIElement] = [:]

    public init(cache: WindowCache) {
        self.cache = cache
    }

    /// The live `AXUIElement` for a previously scanned `ClickableElement.stableID`,
    /// valid only until the next rescan of that window. Used by `ActionExecutor`/
    /// `LiveClickPerformer` to actually perform a click on the element the user selected.
    public func axElement(for stableID: String) -> AXUIElement? {
        axElementLookup[stableID]
    }

    public func start() {
        workspaceToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.attach(to: app)
        }
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            attach(to: frontmost)
        }
    }

    public func stop() {
        if let workspaceToken {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceToken)
        }
        observer = nil
    }

    private func attach(to app: NSRunningApplication) {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        currentAppElement = appElement
        currentBundleID = app.bundleIdentifier

        var axObserver: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let indexer = Unmanaged<AccessibilityIndexer>.fromOpaque(refcon).takeUnretainedValue()
            indexer.rescanCurrentWindow()
        }
        AXObserverCreate(app.processIdentifier, callback, &axObserver)
        guard let axObserver else { return }
        observer = axObserver

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for notification in [
            kAXFocusedWindowChangedNotification,
            kAXUIElementDestroyedNotification,
            kAXLayoutChangedNotification,
            kAXWindowResizedNotification,
        ] {
            AXObserverAddNotification(axObserver, appElement, notification as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(axObserver), .defaultMode)

        rescanCurrentWindow()
    }

    private func rescanCurrentWindow() {
        guard let appElement = currentAppElement, let bundleID = currentBundleID else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var windowValue: AnyObject?
            guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
                  let windowValue else { return }
            let axWindow = windowValue as! AXUIElement
            let node = LiveAXNode(element: axWindow)
            let scanner = ClickableElementScanner(bundleID: bundleID, windowRole: node.role)
            let pairs = scanner.scanPaired(root: node)
            let elements = pairs.map(\.element)
            var lookup: [String: AXUIElement] = [:]
            for pair in pairs {
                if let liveNode = pair.node as? LiveAXNode {
                    lookup[pair.element.stableID] = liveNode.underlyingElement
                }
            }

            var windowIDValue: AnyObject?
            AXUIElementCopyAttributeValue(axWindow, "AXWindowNumber" as CFString, &windowIDValue)
            let windowID = (windowIDValue as? Int) ?? 0
            let key = WindowKey(bundleID: bundleID, windowID: windowID)

            self.cache.update(elements, for: key)
            DispatchQueue.main.async {
                self.lastCachedKey = key
                self.axElementLookup = lookup
            }
        }
    }
}
```

- [ ] **Step 6: 手動検証**

1. `HomerowCPApp`の`main.swift`から一時的に`AccessibilityIndexer(cache: WindowCache()).start()`を呼び出し、`RunLoop.main.run()`で待機させる
2. `swift run`で実行し、システム設定でこのバイナリにAccessibility権限を付与する
3. Finderのウィンドウを操作(リサイズ、フォーカス切替)し、デバッグprintで`WindowCache`が更新されることを確認する
4. 確認後、一時的な呼び出しコードは元に戻す(Task 14で正式に配線する)

- [ ] **Step 7: Commit**

```bash
git add Sources/HomerowCPCore/WindowCache.swift Sources/HomerowCPAccessibility/AccessibilityIndexer.swift Tests/HomerowCPCoreTests/WindowCacheTests.swift
git commit -m "feat: add window cache and background accessibility indexer"
```

---

## Task 8: ActionExecutor

**Files:**
- Create: `Sources/HomerowCPCore/ActionExecutor.swift`
- Create: `Sources/HomerowCPAccessibility/LiveClickPerformer.swift`
- Test: `Tests/HomerowCPCoreTests/ActionExecutorTests.swift`

**Interfaces:**
- Consumes: `ElementFrame`(Task 2)
- Produces:
  - `public enum ClickKind { case left, right, double, command }`
  - `public struct ActionExecutor { func chooseAXAction(for kind: ClickKind) -> String; func centerPoint(of frame: ElementFrame) -> (x: Double, y: Double) }`
  - `final class LiveClickPerformer`(HomerowCPAccessibilityターゲット、手動検証対象)

- [ ] **Step 1: 失敗するテストを書く**

`Tests/HomerowCPCoreTests/ActionExecutorTests.swift`:
```swift
import XCTest
@testable import HomerowCPCore

final class ActionExecutorTests: XCTestCase {
    let executor = ActionExecutor()

    func test_leftAndCommandClickUsePressAction() {
        XCTAssertEqual(executor.chooseAXAction(for: .left), "AXPress")
        XCTAssertEqual(executor.chooseAXAction(for: .command), "AXPress")
    }

    func test_rightClickUsesShowMenuAction() {
        XCTAssertEqual(executor.chooseAXAction(for: .right), "AXShowMenu")
    }

    func test_centerPointComputesMidpointOfFrame() {
        let frame = ElementFrame(x: 10, y: 20, width: 100, height: 50)
        let center = executor.centerPoint(of: frame)
        XCTAssertEqual(center.x, 60)
        XCTAssertEqual(center.y, 45)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `swift test --filter ActionExecutorTests`
Expected: FAIL

- [ ] **Step 3: 実装**

`Sources/HomerowCPCore/ActionExecutor.swift`:
```swift
public enum ClickKind {
    case left, right, double, command
}

public struct ActionExecutor {
    public init() {}

    public func chooseAXAction(for kind: ClickKind) -> String {
        switch kind {
        case .left, .command, .double:
            return "AXPress"
        case .right:
            return "AXShowMenu"
        }
    }

    public func centerPoint(of frame: ElementFrame) -> (x: Double, y: Double) {
        (x: frame.x + frame.width / 2, y: frame.y + frame.height / 2)
    }
}
```

`Sources/HomerowCPAccessibility/LiveClickPerformer.swift`(手動検証対象):
```swift
import ApplicationServices
import HomerowCPCore

public struct LiveClickPerformer {
    private let executor = ActionExecutor()

    public init() {}

    public func perform(kind: ClickKind, on element: AXUIElement, frame: ElementFrame) {
        let actionName = executor.chooseAXAction(for: kind)
        let result = AXUIElementPerformAction(element, actionName as CFString)

        if result != .success, kind != .right {
            // AXPressに応じないカスタム描画要素向けのフォールバック: 中心点へ合成マウスクリックを送る
            let center = executor.centerPoint(of: frame)
            postSyntheticClick(at: CGPoint(x: center.x, y: center.y), doubleClick: kind == .double, commandModifier: kind == .command)
        } else if result == .success, kind == .double {
            _ = AXUIElementPerformAction(element, actionName as CFString)
        }
    }

    private func postSyntheticClick(at point: CGPoint, doubleClick: Bool, commandModifier: Bool) {
        let flags: CGEventFlags = commandModifier ? .maskCommand : []
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        if doubleClick {
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `swift test --filter ActionExecutorTests`
Expected: 3件PASS

- [ ] **Step 5: 手動検証**

Task 14でOverlayControllerに接続した後、実際にFinderのボタンを`left`/`right`/`double`/`command`の各`ClickKind`で選択し、期待通りの挙動(通常クリック・コンテキストメニュー表示・ダブルクリック・Command+クリック)になることを目視確認する。

- [ ] **Step 6: Commit**

```bash
git add Sources/HomerowCPCore/ActionExecutor.swift Sources/HomerowCPAccessibility/LiveClickPerformer.swift Tests/HomerowCPCoreTests/ActionExecutorTests.swift
git commit -m "feat: add click action mapping and live AX/CGEvent click performer"
```

---

## Task 9: HotkeyManager + キーコンボ解析

**Files:**
- Create: `Sources/HomerowCPCore/KeyCombo.swift`
- Create: `Sources/HomerowCPApp/HotkeyManager.swift`
- Test: `Tests/HomerowCPCoreTests/KeyComboParserTests.swift`

**Interfaces:**
- Produces:
  - `public struct KeyCombo: Equatable { let keyCode: UInt32; let modifiers: UInt32 }`
  - `public enum KeyComboParser { static func parse(_ string: String) -> KeyCombo? }`
  - `final class HotkeyManager { var onActivate: (() -> Void)?; func register(combo: KeyCombo); func unregister() }`(手動検証対象、実行可能ターゲット内に配置しCarbonに依存)

- [ ] **Step 1: 失敗するテストを書く**

`Tests/HomerowCPCoreTests/KeyComboParserTests.swift`:
```swift
import XCTest
@testable import HomerowCPCore

final class KeyComboParserTests: XCTestCase {
    func test_parsesCmdShiftSpace() {
        let combo = KeyComboParser.parse("cmd+shift+space")
        XCTAssertNotNil(combo)
        XCTAssertEqual(combo?.keyCode, 49)
    }

    func test_returnsNilForUnknownKey() {
        XCTAssertNil(KeyComboParser.parse("cmd+unknownkey"))
    }

    func test_returnsNilForUnknownModifier() {
        XCTAssertNil(KeyComboParser.parse("meta+space"))
    }

    func test_singleKeyWithNoModifierParses() {
        let combo = KeyComboParser.parse("space")
        XCTAssertEqual(combo?.modifiers, 0)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `swift test --filter KeyComboParserTests`
Expected: FAIL

- [ ] **Step 3: KeyCombo/KeyComboParserを実装**

`Sources/HomerowCPCore/KeyCombo.swift`:
```swift
public struct KeyCombo: Equatable {
    public let keyCode: UInt32
    public let modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public enum KeyComboParser {
    // Carbon modifier flag values (cmdKey=0x100, shiftKey=0x200, optionKey=0x800, controlKey=0x1000)
    private static let modifierNames: [String: UInt32] = [
        "cmd": 0x100, "shift": 0x200, "option": 0x800, "alt": 0x800, "control": 0x1000, "ctrl": 0x1000,
    ]

    // macOS virtual keycodes for the subset of keys this app's default bindings use
    private static let keyCodeNames: [String: UInt32] = [
        "space": 49, "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "j": 38, "k": 40, "l": 37, "slash": 44,
    ]

    public static func parse(_ string: String) -> KeyCombo? {
        let parts = string.lowercased().split(separator: "+").map(String.init)
        guard let keyPart = parts.last, let keyCode = keyCodeNames[keyPart] else { return nil }

        var modifiers: UInt32 = 0
        for part in parts.dropLast() {
            guard let flag = modifierNames[part] else { return nil }
            modifiers |= flag
        }
        return KeyCombo(keyCode: keyCode, modifiers: modifiers)
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `swift test --filter KeyComboParserTests`
Expected: 4件PASS

- [ ] **Step 5: HotkeyManagerを実装(手動検証対象)**

`Sources/HomerowCPApp/HotkeyManager.swift`:
```swift
import Carbon.HIToolbox
import AppKit
import HomerowCPCore

final class HotkeyManager {
    var onActivate: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func register(combo: KeyCombo) {
        var hotKeyID = EventHotKeyID(signature: OSType(0x484D5257), id: 1)
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onActivate?()
            return noErr
        }, 1, &eventSpec, selfPtr, &eventHandlerRef)

        RegisterEventHotKey(combo.keyCode, combo.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
        hotKeyRef = nil
        eventHandlerRef = nil
    }
}
```

- [ ] **Step 6: 手動検証**

`main.swift`から一時的に`HotkeyManager`を生成し、`register(combo: KeyComboParser.parse("cmd+shift+space")!)`、`onActivate`にprintを設定して`swift run`で実行、実際に`Cmd+Shift+Space`を押してコールバックが発火することを確認する。

- [ ] **Step 7: Commit**

```bash
git add Sources/HomerowCPCore/KeyCombo.swift Sources/HomerowCPApp/HotkeyManager.swift Tests/HomerowCPCoreTests/KeyComboParserTests.swift
git commit -m "feat: add key combo parser and Carbon-based global hotkey manager"
```

---

## Task 10: OverlayInputRouter + SwiftUIオーバーレイ

**Files:**
- Create: `Sources/HomerowCPCore/OverlayInputRouter.swift`
- Create: `Sources/HomerowCPUI/HintLabelView.swift`
- Create: `Sources/HomerowCPUI/OverlayController.swift`
- Test: `Tests/HomerowCPCoreTests/OverlayInputRouterTests.swift`

**Interfaces:**
- Consumes: `LabelAssignment`(Task 3), `ClickableElement`(Task 2), `ClickKind`(Task 8)
- Produces:
  - `public enum OverlayInputResult: Equatable { case selected(elementID: String); case updatedQuery(String); case noMatch; case dismiss }`
  - `public struct OverlayInputRouter { func handle(character: Character, currentQuery: String, assignments: [LabelAssignment]) -> OverlayInputResult }`
  - `final class OverlayController`(HomerowCPUIターゲット、手動検証対象。`onSelect: ((ClickableElement, ClickKind) -> Void)?`と`func handleKeyPress(character: Character, modifierFlags: NSEvent.ModifierFlags = [])`を公開し、ラベル確定時に押されていた修飾キーからクリック種別を判定してTask 14の`AppCoordinator`に伝える)

- [ ] **Step 1: 失敗するテストを書く**

`Tests/HomerowCPCoreTests/OverlayInputRouterTests.swift`:
```swift
import XCTest
@testable import HomerowCPCore

final class OverlayInputRouterTests: XCTestCase {
    let router = OverlayInputRouter()
    let assignments = [
        LabelAssignment(elementID: "1", label: "a"),
        LabelAssignment(elementID: "2", label: "sd"),
        LabelAssignment(elementID: "3", label: "sf"),
    ]

    func test_exactSingleCharMatchSelectsImmediately() {
        let result = router.handle(character: "a", currentQuery: "", assignments: assignments)
        XCTAssertEqual(result, .selected(elementID: "1"))
    }

    func test_prefixOfTwoCharLabelUpdatesQuery() {
        let result = router.handle(character: "s", currentQuery: "", assignments: assignments)
        XCTAssertEqual(result, .updatedQuery("s"))
    }

    func test_secondCharacterCompletesTwoCharLabel() {
        let result = router.handle(character: "d", currentQuery: "s", assignments: assignments)
        XCTAssertEqual(result, .selected(elementID: "2"))
    }

    func test_unmatchableCharacterReturnsNoMatch() {
        let result = router.handle(character: "z", currentQuery: "", assignments: assignments)
        XCTAssertEqual(result, .noMatch)
    }

    func test_escapeDismisses() {
        let result = router.handle(character: "\u{1B}", currentQuery: "s", assignments: assignments)
        XCTAssertEqual(result, .dismiss)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `swift test --filter OverlayInputRouterTests`
Expected: FAIL

- [ ] **Step 3: OverlayInputRouterを実装**

`Sources/HomerowCPCore/OverlayInputRouter.swift`:
```swift
public enum OverlayInputResult: Equatable {
    case selected(elementID: String)
    case updatedQuery(String)
    case noMatch
    case dismiss
}

public struct OverlayInputRouter {
    public init() {}

    public func handle(character: Character, currentQuery: String, assignments: [LabelAssignment]) -> OverlayInputResult {
        if character == "\u{1B}" {
            return .dismiss
        }

        let newQuery = currentQuery + String(character)

        if let exact = assignments.first(where: { $0.label == newQuery }) {
            return .selected(elementID: exact.elementID)
        }

        let stillPossible = assignments.contains { $0.label.hasPrefix(newQuery) }
        if stillPossible {
            return .updatedQuery(newQuery)
        }

        return .noMatch
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `swift test --filter OverlayInputRouterTests`
Expected: 5件PASS

- [ ] **Step 5: HintLabelViewを実装(手動検証対象)**

`Sources/HomerowCPUI/HintLabelView.swift`:
```swift
import SwiftUI
import HomerowCPCore

public struct HintLabelView: View {
    let label: String
    let matchedPrefix: String
    let isPrioritized: Bool

    public init(label: String, matchedPrefix: String, isPrioritized: Bool) {
        self.label = label
        self.matchedPrefix = matchedPrefix
        self.isPrioritized = isPrioritized
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(label.enumerated()), id: \.offset) { index, char in
                Text(String(char))
                    .foregroundColor(index < matchedPrefix.count ? .accentColor : .primary)
            }
        }
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(isPrioritized ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
        )
        .transition(.asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity), removal: .opacity))
        .animation(.spring(response: 0.15, dampingFraction: 0.8), value: matchedPrefix)
    }
}
```

`Sources/HomerowCPUI/OverlayController.swift`:
```swift
import AppKit
import SwiftUI
import HomerowCPCore

public final class OverlayController {
    private var panel: NSPanel?
    private let router = OverlayInputRouter()
    private var query = ""
    private var assignments: [LabelAssignment] = []
    private var elementsByID: [String: ClickableElement] = [:]
    private var keyMonitor: Any?
    /// `ClickKind` is derived from the modifier flags held during the keystroke that
    /// completed the label (see `handleKeyPress`): Shift -> right click, Option -> double
    /// click, Command -> command click, no modifier -> left click.
    public var onSelect: ((ClickableElement, ClickKind) -> Void)?

    public init() {}

    public func show(elements: [ClickableElement], assignments: [LabelAssignment], on screenFrame: CGRect) {
        self.assignments = assignments
        self.elementsByID = Dictionary(uniqueKeysWithValues: elements.map { ($0.stableID, $0) })
        query = ""

        let panel = NSPanel(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false

        let rootView = OverlayRootView(elements: elements, assignments: assignments, matchedPrefix: query)
        panel.contentView = NSHostingView(rootView: rootView)
        panel.orderFrontRegardless()
        self.panel = panel

        // The panel is a non-activating NSPanel so it never steals focus from the app
        // underneath; keystrokes are instead captured system-wide via a global monitor
        // (requires the Accessibility permission already granted for AXUIElement access)
        // and routed into `handleKeyPress`, which drives the SwiftUI overlay purely from
        // state (`query`) rather than first responder chains.
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let scalar = event.charactersIgnoringModifiers?.unicodeScalars.first else { return }
            self.handleKeyPress(character: Character(scalar), modifierFlags: event.modifierFlags)
        }
    }

    public func handleKeyPress(character: Character, modifierFlags: NSEvent.ModifierFlags = []) {
        let result = router.handle(character: character, currentQuery: query, assignments: assignments)
        switch result {
        case .selected(let elementID):
            if let element = elementsByID[elementID] {
                onSelect?(element, clickKind(for: modifierFlags))
            }
            dismiss()
        case .updatedQuery(let newQuery):
            query = newQuery
        case .noMatch:
            query = ""
        case .dismiss:
            dismiss()
        }
    }

    public func dismiss() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func clickKind(for modifierFlags: NSEvent.ModifierFlags) -> ClickKind {
        if modifierFlags.contains(.shift) { return .right }
        if modifierFlags.contains(.option) { return .double }
        if modifierFlags.contains(.command) { return .command }
        return .left
    }
}

private struct OverlayRootView: View {
    let elements: [ClickableElement]
    let assignments: [LabelAssignment]
    let matchedPrefix: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(assignments, id: \.elementID) { assignment in
                if let element = elements.first(where: { $0.stableID == assignment.elementID }) {
                    HintLabelView(label: assignment.label, matchedPrefix: matchedPrefix, isPrioritized: false)
                        .position(x: element.frame.x, y: element.frame.y)
                }
            }
        }
    }
}
```

- [ ] **Step 6: 手動検証**

Task 14でHotkeyManager/AccessibilityIndexer/ActionExecutorと配線した後、実際にFinderで`Cmd+Shift+Space`を押し、ラベルが表示される・入力に応じて絞り込まれる・確定でクリックされる・Escapeで閉じることを目視確認する。修飾キーなし/Shift/Option/Cmdを押しながらラベルを確定し、それぞれ左クリック/右クリック(コンテキストメニュー)/ダブルクリック/Command+クリックとして実行されることも確認する。特にアニメーション(フェード+拡大)の見え方を確認する。

- [ ] **Step 7: Commit**

```bash
git add Sources/HomerowCPCore/OverlayInputRouter.swift Sources/HomerowCPUI/HintLabelView.swift Sources/HomerowCPUI/OverlayController.swift Tests/HomerowCPCoreTests/OverlayInputRouterTests.swift
git commit -m "feat: add overlay input routing logic and SwiftUI hint overlay"
```

---

## Task 11: ScrollController

**Files:**
- Create: `Sources/HomerowCPCore/ScrollController.swift`
- Create: `Sources/HomerowCPAccessibility/LiveScrollPerformer.swift`
- Test: `Tests/HomerowCPCoreTests/ScrollControllerTests.swift`

**Interfaces:**
- Produces:
  - `public enum ScrollDirection { case up, down, left, right }`
  - `public struct ScrollController { func direction(for key: Character) -> ScrollDirection?; func delta(for direction: ScrollDirection, step: Double = 40) -> (dx: Double, dy: Double) }`
  - `struct LiveScrollPerformer`(HomerowCPAccessibilityターゲット、手動検証対象)

- [ ] **Step 1: 失敗するテストを書く**

`Tests/HomerowCPCoreTests/ScrollControllerTests.swift`:
```swift
import XCTest
@testable import HomerowCPCore

final class ScrollControllerTests: XCTestCase {
    let controller = ScrollController()

    func test_hjklMapToDirections() {
        XCTAssertEqual(controller.direction(for: "k"), .up)
        XCTAssertEqual(controller.direction(for: "j"), .down)
        XCTAssertEqual(controller.direction(for: "h"), .left)
        XCTAssertEqual(controller.direction(for: "l"), .right)
    }

    func test_unknownKeyReturnsNil() {
        XCTAssertNil(controller.direction(for: "x"))
    }

    func test_deltaForUpIsNegativeY() {
        let delta = controller.delta(for: .up, step: 40)
        XCTAssertEqual(delta.dx, 0)
        XCTAssertEqual(delta.dy, -40)
    }

    func test_deltaForRightIsPositiveX() {
        let delta = controller.delta(for: .right, step: 40)
        XCTAssertEqual(delta.dx, 40)
        XCTAssertEqual(delta.dy, 0)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `swift test --filter ScrollControllerTests`
Expected: FAIL

- [ ] **Step 3: 実装**

`Sources/HomerowCPCore/ScrollController.swift`:
```swift
public enum ScrollDirection {
    case up, down, left, right
}

public struct ScrollController {
    public init() {}

    public func direction(for key: Character) -> ScrollDirection? {
        switch key {
        case "k": return .up
        case "j": return .down
        case "h": return .left
        case "l": return .right
        default: return nil
        }
    }

    public func delta(for direction: ScrollDirection, step: Double = 40) -> (dx: Double, dy: Double) {
        switch direction {
        case .up: return (0, -step)
        case .down: return (0, step)
        case .left: return (-step, 0)
        case .right: return (step, 0)
        }
    }
}
```

`Sources/HomerowCPAccessibility/LiveScrollPerformer.swift`(手動検証対象):
```swift
import CoreGraphics

public struct LiveScrollPerformer {
    public init() {}

    public func scroll(dx: Double, dy: Double) {
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(-dy), wheel2: Int32(-dx), wheel3: 0)
        event?.post(tap: .cghidEventTap)
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `swift test --filter ScrollControllerTests`
Expected: 4件PASS

- [ ] **Step 5: 手動検証**

Task 14で配線後、スクロール可能なウィンドウ(Finderのリスト表示など)で`Shift+J`後にhjklを押し、実際にスクロールされることを確認する。

- [ ] **Step 6: Commit**

```bash
git add Sources/HomerowCPCore/ScrollController.swift Sources/HomerowCPAccessibility/LiveScrollPerformer.swift Tests/HomerowCPCoreTests/ScrollControllerTests.swift
git commit -m "feat: add hjkl scroll direction logic and live scroll performer"
```

---

## Task 12: アクセシビリティ権限オンボーディング

**Files:**
- Create: `Sources/HomerowCPAccessibility/AccessibilityPermission.swift`
- Create: `Sources/HomerowCPUI/OnboardingView.swift`

**Interfaces:**
- Produces:
  - `public enum AccessibilityPermission { static func isTrusted(promptIfNeeded: Bool = false) -> Bool; static func openSystemSettings() }`
  - `public struct OnboardingView: View`(手動検証対象)

- [ ] **Step 1: AccessibilityPermissionを実装**

`Sources/HomerowCPAccessibility/AccessibilityPermission.swift`:
```swift
import ApplicationServices
import AppKit

public enum AccessibilityPermission {
    public static func isTrusted(promptIfNeeded: Bool = false) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: promptIfNeeded] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
```

- [ ] **Step 2: OnboardingViewを実装**

`Sources/HomerowCPUI/OnboardingView.swift`:
```swift
import SwiftUI
import HomerowCPAccessibility

public struct OnboardingView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text("アクセシビリティ権限が必要です")
                .font(.title2.bold())
            Text("キーボードでUIを操作するには、システム設定でこのアプリにアクセシビリティ権限を許可してください。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("システム設定を開く") {
                AccessibilityPermission.openSystemSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(width: 360)
    }
}
```

- [ ] **Step 3: ビルドを確認**

Run: `swift build`
Expected: ビルド成功

- [ ] **Step 4: 手動検証**

システム設定 > プライバシーとセキュリティ > アクセシビリティから、開発中のバイナリの権限を意図的に外した状態でTask 14のアプリ本体を起動し、`AccessibilityPermission.isTrusted()`が`false`を返して`OnboardingView`が表示されること、「システム設定を開く」ボタンで該当ペインが開くことを確認する。

- [ ] **Step 5: Commit**

```bash
git add Sources/HomerowCPAccessibility/AccessibilityPermission.swift Sources/HomerowCPUI/OnboardingView.swift
git commit -m "feat: add accessibility permission check and onboarding view"
```

---

## Task 13: PreferencesUI

**Files:**
- Create: `Sources/HomerowCPUI/PreferencesView.swift`

**Interfaces:**
- Consumes: `FrequencyTracker`(Task 4)
- Produces: `public struct PreferencesView: View`(手動検証対象)

- [ ] **Step 1: PreferencesViewを実装**

`Sources/HomerowCPUI/PreferencesView.swift`:
```swift
import SwiftUI
import HomerowCPCore

public struct PreferencesView: View {
    public enum Tab: String, CaseIterable, Identifiable {
        case general = "General"
        case keybindings = "Keybindings"
        case appearance = "Appearance"
        case frequencyData = "Frequency Data"
        case about = "About"
        public var id: String { rawValue }
    }

    @State private var selectedTab: Tab = .general
    let onResetFrequencyData: () -> Void

    public init(onResetFrequencyData: @escaping () -> Void) {
        self.onResetFrequencyData = onResetFrequencyData
    }

    public var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selectedTab) { tab in
                Text(tab.rawValue).tag(tab)
            }
            .navigationSplitViewColumnWidth(160)
        } detail: {
            switch selectedTab {
            case .general:
                Text("General settings placeholder")
            case .keybindings:
                Text("Keybinding recorder placeholder")
            case .appearance:
                Text("Appearance settings placeholder")
            case .frequencyData:
                VStack(alignment: .leading, spacing: 12) {
                    Text("学習した頻度データをリセットできます。")
                    Button("学習データをリセット", role: .destructive) {
                        onResetFrequencyData()
                    }
                }
                .padding()
            case .about:
                Text("HomerowCP v0.1.0")
            }
        }
        .frame(width: 560, height: 360)
    }
}
```

- [ ] **Step 2: ビルドを確認**

Run: `swift build`
Expected: ビルド成功

- [ ] **Step 3: 手動検証**

Task 14でメニューバーから開けるようにした後、各タブが切り替わること、「学習データをリセット」ボタン押下で`FrequencyTracker.reset()`が呼ばれ、直後にオーバーレイを開いてもラベル優先順位がリセットされていることを確認する。

- [ ] **Step 4: Commit**

```bash
git add Sources/HomerowCPUI/PreferencesView.swift
git commit -m "feat: add preferences window with tabbed sections"
```

---

## Task 14: アプリ配線 + .appバンドル化 + パフォーマンスHUD

**Files:**
- Modify: `Sources/HomerowCPApp/main.swift`
- Create: `Sources/HomerowCPApp/AppCoordinator.swift`
- Create: `Sources/HomerowCPApp/LatencyHUD.swift`
- Create: `Resources/Info.plist`
- Create: `Scripts/build_app_bundle.sh`

**Interfaces:**
- Consumes: すべての先行タスクの型(`AccessibilityIndexer`, `WindowCache`, `HotkeyManager`, `OverlayController`, `LiveClickPerformer`, `LiveScrollPerformer`, `FrequencyTracker`, `LabelAssignmentEngine`, `SearchFilter`, `AccessibilityPermission`, `OnboardingView`, `PreferencesView(onResetFrequencyData:)`)
- メニューバー(`NSStatusItem`)に「Preferences...」「Quit」を持つメニューを追加し、`PreferencesView`を開く導線をここで初めて配線する(Task 13時点では未配線)。

- [ ] **Step 1: AppCoordinatorを実装**

`Sources/HomerowCPApp/AppCoordinator.swift`:
```swift
import AppKit
import SwiftUI
import HomerowCPCore
import HomerowCPAccessibility
import HomerowCPUI

final class AppCoordinator {
    private let cache = WindowCache()
    private let indexer: AccessibilityIndexer
    private let hotkeyManager = HotkeyManager()
    private let overlay = OverlayController()
    private let clickPerformer = LiveClickPerformer()
    private let frequencyTracker: FrequencyTracker
    private let labelEngine = LabelAssignmentEngine()
    private var previousLabels: [String: String] = [:]
    private let latencyHUD = LatencyHUD()
    private var statusItem: NSStatusItem?
    private var preferencesWindow: NSWindow?

    init() {
        indexer = AccessibilityIndexer(cache: cache)
        let storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HomerowCP", isDirectory: true)
        try? FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)
        frequencyTracker = FrequencyTracker(storeURL: storeURL.appendingPathComponent("frequency.json"))
    }

    func start() {
        setUpStatusItem()
        guard AccessibilityPermission.isTrusted(promptIfNeeded: true) else {
            presentOnboarding()
            return
        }
        indexer.start()
        hotkeyManager.onActivate = { [weak self] in self?.activateOverlay() }
        hotkeyManager.register(combo: KeyComboParser.parse("cmd+shift+space")!)
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "⌨"

        let menu = NSMenu()
        menu.addItem(withTitle: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit HomerowCP", action: #selector(quit), keyEquivalent: "q")
        for menuItem in menu.items { menuItem.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func showPreferences() {
        if let preferencesWindow {
            preferencesWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = PreferencesView(onResetFrequencyData: { [weak self] in
            self?.frequencyTracker.reset()
            self?.previousLabels = [:]
        })
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "HomerowCP Preferences"
        window.styleMask = [.titled, .closable]
        preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func activateOverlay() {
        let started = Date()
        guard let screen = NSScreen.main else { return }
        guard let key = indexer.lastCachedKey,
              let elements = cache.elements(for: key) else { return }

        var scores: [String: Double] = [:]
        for element in elements { scores[element.stableID] = frequencyTracker.score(for: element.stableID) }
        let assignments = labelEngine.assignLabels(elements: elements, frequencyScores: scores, previousAssignments: previousLabels)
        previousLabels = Dictionary(uniqueKeysWithValues: assignments.map { ($0.elementID, $0.label) })

        overlay.onSelect = { [weak self] element, kind in
            guard let self else { return }
            if let axElement = self.indexer.axElement(for: element.stableID) {
                self.clickPerformer.perform(kind: kind, on: axElement, frame: element.frame)
            }
            self.frequencyTracker.recordSelection(elementID: element.stableID)
            try? self.frequencyTracker.persist()
        }
        overlay.show(elements: elements, assignments: assignments, on: screen.frame)
        latencyHUD.report(elapsed: Date().timeIntervalSince(started))
    }

    private func presentOnboarding() {
        let window = NSWindow(contentViewController: NSHostingController(rootView: OnboardingView()))
        window.makeKeyAndOrderFront(nil)
    }
}
```

- [ ] **Step 2: LatencyHUDを実装**

`Sources/HomerowCPApp/LatencyHUD.swift`:
```swift
import Foundation

final class LatencyHUD {
    private var samples: [TimeInterval] = []

    func report(elapsed: TimeInterval) {
        samples.append(elapsed)
        let ms = Int(elapsed * 1000)
        print("[HomerowCP] activation latency: \(ms)ms (avg over \(samples.count): \(Int(samples.reduce(0, +) / Double(samples.count) * 1000))ms)")
    }
}
```

- [ ] **Step 3: main.swiftを更新**

`Sources/HomerowCPApp/main.swift`:
```swift
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // メニューバー常駐、Dockアイコンなし
let coordinator = AppCoordinator()
coordinator.start()
app.run()
```

- [ ] **Step 4: Info.plistを作成**

`Resources/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>HomerowCP</string>
    <key>CFBundleIdentifier</key>
    <string>dev.local.homerowcp</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleExecutable</key>
    <string>HomerowCPApp</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
```

- [ ] **Step 5: .appバンドル化スクリプトを作成**

`Scripts/build_app_bundle.sh`:
```bash
#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/.build/HomerowCP.app"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$BUILD_DIR/HomerowCPApp" "$APP_DIR/Contents/MacOS/HomerowCPApp"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "Built $APP_DIR"
```

```bash
chmod +x Scripts/build_app_bundle.sh
```

- [ ] **Step 6: ビルドと.appバンドル化を実行**

Run: `swift build && ./Scripts/build_app_bundle.sh`
Expected: `.build/HomerowCP.app`が生成される

- [ ] **Step 7: エンドツーエンド手動検証**

1. `open .build/HomerowCP.app`で起動
2. システム設定でアクセシビリティ権限を許可
3. Finderで`Cmd+Shift+Space`を押し、ラベルが表示されることを確認
4. ラベル文字を入力してクリックが実行されることを確認
5. コンソール(`Console.app`または`swift run`時の標準出力)で`activation latency`ログを確認し、2回目以降の起動でキャッシュ命中により有意に短くなっていることを確認する
6. `Shift+J`でスクロールモードに入りhjklでスクロールできることを確認
7. メニューバーアイコンから設定画面を開き、頻度データのリセットが機能することを確認

- [ ] **Step 8: Commit**

```bash
git add Sources/HomerowCPApp/main.swift Sources/HomerowCPApp/AppCoordinator.swift Sources/HomerowCPApp/LatencyHUD.swift Resources/Info.plist Scripts/build_app_bundle.sh
git commit -m "feat: wire up app coordinator, permission flow, and .app bundle packaging"
```
