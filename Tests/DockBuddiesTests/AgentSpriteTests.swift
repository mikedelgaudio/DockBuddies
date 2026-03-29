import XCTest
@testable import DockBuddies

final class AgentSpriteTests: XCTestCase {
    func testSpriteGridIs16x16() {
        let sprite = AgentSprite.baseGrid
        XCTAssertEqual(sprite.count, 16, "Sprite should be 16 rows")
        for row in sprite {
            XCTAssertEqual(row.count, 16, "Each row should be 16 pixels")
        }
    }

    func testAllColorPalettesHaveRequiredKeys() {
        for color in AgentColor.allCases {
            let palette = color.palette
            XCTAssertNotNil(palette[.body], "\(color) missing body color")
            XCTAssertNotNil(palette[.bodyDark], "\(color) missing bodyDark color")
            XCTAssertNotNil(palette[.eye], "\(color) missing eye color")
            XCTAssertNotNil(palette[.antenna], "\(color) missing antenna color")
            XCTAssertNotNil(palette[.feet], "\(color) missing feet color")
        }
    }

    func testFourColorVariantsExist() {
        XCTAssertEqual(AgentColor.allCases.count, 4)
    }

    func testBlinkGridReplacesEyes() {
        let blink = AgentSprite.blinkGrid
        // Rows 5 and 6 should have no .eye or .eyePupil
        for col in 0..<16 {
            XCTAssertNotEqual(blink[5][col], .eye)
            XCTAssertNotEqual(blink[5][col], .eyePupil)
            XCTAssertNotEqual(blink[6][col], .eye)
            XCTAssertNotEqual(blink[6][col], .eyePupil)
        }
    }
}
