import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // メニューバー常駐、Dockアイコンなし
let coordinator = AppCoordinator()
coordinator.start()
app.run()
