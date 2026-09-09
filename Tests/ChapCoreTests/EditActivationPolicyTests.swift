import CoreGraphics
import Foundation
import Testing

@testable import Chap

@Suite("Edit Activation Policy")
struct EditActivationPolicyTests {
    private let scriptFrame = CGRect(x: 100, y: 200, width: 400, height: 150)

    @Test("shell tap inside the script editor enables editing")
    func shellInsideScriptEnables() {
        let enables = EditActivationPolicy.shouldEnableEditing(
            launchType: .shell,
            tapLocation: CGPoint(x: 300, y: 275),
            scriptEditorFrame: scriptFrame)

        #expect(enables == true)
    }

    @Test("shell tap outside the script editor does not enable editing")
    func shellOutsideScriptDoesNotEnable() {
        let enables = EditActivationPolicy.shouldEnableEditing(
            launchType: .shell,
            tapLocation: CGPoint(x: 50, y: 50),
            scriptEditorFrame: scriptFrame)

        #expect(enables == false)
    }

    @Test("shell tap with an unset script frame does not enable editing")
    func shellZeroFrameDoesNotEnable() {
        let enables = EditActivationPolicy.shouldEnableEditing(
            launchType: .shell,
            tapLocation: CGPoint(x: 300, y: 275),
            scriptEditorFrame: .zero)

        #expect(enables == false)
    }

    @Test(
        "non-shell types enable editing from any tap location",
        arguments: [LaunchType.url, .app, .finder])
    func nonShellEnablesAnywhere(launchType: LaunchType) {
        let enables = EditActivationPolicy.shouldEnableEditing(
            launchType: launchType,
            tapLocation: CGPoint(x: 5, y: 5),
            scriptEditorFrame: scriptFrame)

        #expect(enables == true)
    }
}
