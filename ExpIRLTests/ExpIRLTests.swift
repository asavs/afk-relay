//
//  ExpIRLTests.swift
//  ExpIRLTests
//
//  Created by 野嶋伊織 on 7/26/26.
//

import Testing
@testable import ExpIRL

struct ExpIRLTests {

    @Test
    func arenaLifecycleUsesValidGameplayKitTransitions() {
        let lifecycle = ArenaLifecycleMachine()

        #expect(lifecycle.phase == .ready)

        lifecycle.start()
        #expect(lifecycle.phase == .running)

        lifecycle.pause()
        #expect(lifecycle.phase == .paused)

        lifecycle.resume()
        #expect(lifecycle.phase == .running)
    }
}
