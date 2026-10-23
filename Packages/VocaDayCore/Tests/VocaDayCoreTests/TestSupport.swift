import Foundation
import XCTest
@testable import VocaDayCore

enum Fixtures {
    static func bank() throws -> WordBank {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "sample_bank", withExtension: "json",
                                                  subdirectory: "Fixtures"))
        return try WordBank.decode(from: Data(contentsOf: url))
    }

    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    static func date(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }
}
