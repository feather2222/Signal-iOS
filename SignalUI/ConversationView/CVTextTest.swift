//
// Copyright 2026 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import XCTest
@testable import SignalUI

final class CVTextTest: XCTestCase {

    /// Long text (e.g. some translations of the poll subtitle) must wrap to
    /// fit `maxWidth` instead of being measured at its unwrapped width, which
    /// would let message bubbles stretch beyond their maximum width.
    func testMeasureLabelWrapsLongText() {
        let config = CVLabelConfig.unstyledText(
            "Umfrage · Wähle eine oder mehrere Optionen aus",
            font: .dynamicTypeFootnote,
            textColor: .label,
            numberOfLines: 0,
            lineBreakMode: .byWordWrapping,
        )
        let maxWidth: CGFloat = 200

        let size = CVText.measureLabel(config: config, maxWidth: maxWidth)

        XCTAssertLessThanOrEqual(size.width, maxWidth)
        // The string is much wider than maxWidth on a single line, so it must
        // have wrapped onto multiple lines.
        XCTAssertGreaterThan(size.height, config.font.lineHeight)
    }
}
