import Darwin
import Foundation
import RemindersLibrary

// Show help without requesting access
let arguments = CommandLine.arguments
if arguments.contains("--help") || arguments.contains("-h") || arguments.count == 1 {
    CLI.main()
    exit(0)
}

// Request access for actual sync operations
switch Reminders.requestAccess() {
case (true, _):
    CLI.main()
case (false, let error):
    print("error: you need to grant reminders access")
    if let error {
        print("error: \(error.localizedDescription)")
    }
    exit(1)
}
