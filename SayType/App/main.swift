import AppKit

let application = NSApplication.shared
let applicationDelegate = AppDelegate()
application.delegate = applicationDelegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
