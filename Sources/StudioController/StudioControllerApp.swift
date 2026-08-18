import SwiftUI

@main
struct StudioControllerApp: App {
    @StateObject private var controller = HeadphoneController()

    var body: some Scene {
        MenuBarExtra("Studio Pro", systemImage: "headphones") {
            ControllerMenuView(controller: controller)
        }
        .menuBarExtraStyle(.window)
    }
}
