import Cocoa

// Disable stdout buffering for immediate log output
setbuf(stdout, nil)

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
