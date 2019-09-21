//
//  ContentBlockerTests.swift
//  ContentBlockerTests
//
//  Created by cpsdqs on 2019-06-18.
//  Copyright © 2019 cpsdqs. All rights reserved.
//

import XCTest
@testable import SwiftBlock

class ContentBlockerTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testFilterParser() {
        let a = FilterRule.parse(line: "example.com")!
        XCTAssertEqual(a.urls.count, 1)
        XCTAssertEqual(a.urls[0], .match("example\\.com"))

        let b = FilterRule.parse(line: "hello,~world###selector")!
        XCTAssertEqual(b.urls.count, 2)
        XCTAssertEqual(b.urls[0], .match("hello"))
        XCTAssertEqual(b.urls[1], .notMatch("world"))
        XCTAssertEqual(b.selector, "#selector")
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
