//
// Copyright 2026 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import XCTest
@testable import SignalServiceKit

final class FullTextSearchIndexerTests: SSKBaseTest {

    private var thread: TSContactThread!
    private var nextTimestamp: UInt64 = 1

    override func setUp() {
        super.setUp()
        self.thread = TSContactThread.getOrCreateThread(
            contactAddress: SignalServiceAddress(phoneNumber: "fake-thread-id"),
        )
    }

    private func insertMessage(body: String) {
        let timestamp = nextTimestamp
        nextTimestamp += 1
        write { transaction in
            let builder = TSOutgoingMessageBuilder.outgoingMessageBuilder(
                thread: self.thread,
                messageBody: AttachmentContentValidatorMock.mockValidatedBody(body),
            )
            builder.timestamp = timestamp
            builder.build(transaction: transaction).anyInsert(transaction: transaction)
        }
    }

    private func ftsSearchUniqueIds(searchText: String) -> [String] {
        var uniqueIds = [String]()
        read { transaction in
            FullTextSearchIndexer.search(for: searchText, maxResults: 100, tx: transaction) { message, _, _ in
                uniqueIds.append(message.uniqueId)
            }
        }
        return uniqueIds
    }

    private func substringSearchUniqueIds(searchText: String) -> [String] {
        var uniqueIds = [String]()
        read { transaction in
            FullTextSearchIndexer.substringSearch(for: searchText, maxResults: 100, tx: transaction) { message, _ in
                uniqueIds.append(message.uniqueId)
            }
        }
        return uniqueIds
    }

    // MARK: - Prefix search (FTS) sanity checks

    func testFtsMatchesTokenPrefix() {
        insertMessage(body: "effects test")
        XCTAssertEqual(ftsSearchUniqueIds(searchText: "effects").count, 1)
    }

    func testFtsMissesNonPrefixSubstring() {
        insertMessage(body: "effects test")
        // FTS only supports prefix-token matches, so this finds nothing.
        XCTAssertEqual(ftsSearchUniqueIds(searchText: "ffects").count, 0)
    }

    func testFtsMissesMidTokenDigits() {
        insertMessage(body: "abc12345")
        // "abc12345" is a single token; a prefix query for "12345" misses it.
        XCTAssertEqual(ftsSearchUniqueIds(searchText: "12345").count, 0)
    }

    // MARK: - Substring fallback

    func testSubstringSearchMatchesTokenPrefix() {
        insertMessage(body: "effects test")
        XCTAssertEqual(substringSearchUniqueIds(searchText: "effects").count, 1)
    }

    func testSubstringSearchMatchesNonPrefixSubstring() {
        insertMessage(body: "effects test")
        XCTAssertEqual(substringSearchUniqueIds(searchText: "ffects").count, 1)
    }

    func testSubstringSearchMatchesMidTokenDigits() {
        insertMessage(body: "abc12345")
        XCTAssertEqual(substringSearchUniqueIds(searchText: "12345").count, 1)
    }

    func testSubstringSearchMatchesAcrossMultipleTerms() {
        insertMessage(body: "the quick brown fox")
        // Every term must match (AND semantics, consistent with the FTS query).
        XCTAssertEqual(substringSearchUniqueIds(searchText: "quick fox").count, 1)
        XCTAssertEqual(substringSearchUniqueIds(searchText: "quick zebra").count, 0)
    }

    func testSubstringSearchDoesNotMatchUnrelatedMessages() {
        insertMessage(body: "hello world")
        XCTAssertEqual(substringSearchUniqueIds(searchText: "goodbye").count, 0)
    }

    func testSubstringSearchIgnoresLikeWildcards() {
        insertMessage(body: "100% real")
        // "%" is a LIKE wildcard; it must be escaped so it matches literally.
        XCTAssertEqual(substringSearchUniqueIds(searchText: "100%").count, 1)
    }

    func testSubstringSearchEmptyAfterNormalization() {
        insertMessage(body: "hello world")
        // Punctuation is stripped by normalization, leaving an empty query.
        XCTAssertEqual(substringSearchUniqueIds(searchText: "!!!").count, 0)
    }
}
