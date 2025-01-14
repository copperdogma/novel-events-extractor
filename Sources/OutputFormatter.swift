import Foundation
import EventKit

/// OutputFormatter handles formatting and writing the results.
/// Debug output is controlled by `isDebugEnabled` flag - DO NOT REMOVE debug code,
/// it's essential for development and troubleshooting calendar filtering issues.
class OutputFormatter {
    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter
    private var debugOutput: String = ""
    
    /// Controls whether debug information is included in the output
    /// Set to false to hide debug info in production, but keep the code for development
    let isDebugEnabled: Bool
    
    init(isDebugEnabled: Bool = true) {
        self.isDebugEnabled = isDebugEnabled
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd"
        
        timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HHmm"
    }
    
    func addDebug(_ message: String) {
        guard isDebugEnabled else { return }
        debugOutput += message + "\n"
    }
    
    func formatNovelEvents(_ events: [NovelEvent], lookAheadDays: Int) -> String {
        var output = isDebugEnabled ? debugOutput + "\n" : ""
        output += "Novel events found in next \(lookAheadDays) days:\n\n"
        
        // Add generation timestamp
        let now = Date()
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        timestampFormatter.timeZone = .current
        output += "Generated: \(timestampFormatter.string(from: now))\n\n"
        
        // Format each event
        for novelEvent in events {
            let event = novelEvent.event
            let date = dateFormatter.string(from: event.startDate)
            let time = timeFormatter.string(from: event.startDate)
            let title = event.title ?? "Untitled Event"
            let calendar = event.calendar.title
            
            output += "\(date) \(time) \(title) [\(calendar)]\n"
        }
        
        return output
    }
    
    func writeToFile(_ content: String, at path: String) throws {
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }
} 