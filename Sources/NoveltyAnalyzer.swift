import EventKit
import Foundation

struct NovelEvent {
    let event: EventType
    let noveltyScore: Double
    let reason: String
}

class NoveltyAnalyzer {
    private let patternDetector: PatternDetector
    private let noveltyThreshold: Double
    
    init(patternDetector: PatternDetector, noveltyThreshold: Double = 0.2) {
        self.patternDetector = patternDetector
        self.noveltyThreshold = noveltyThreshold
    }
    
    func findNovelEvents(in events: [EventType]) -> [NovelEvent] {
        var novelEvents: [NovelEvent] = []
        
        for event in events {
            let patternScore = patternDetector.getPatternScore(for: event)
            let isNovel = patternScore < noveltyThreshold
            
            if isNovel {
                let reason = "Event occurs infrequently in your calendar"
                novelEvents.append(NovelEvent(event: event,
                                           noveltyScore: 1.0 - patternScore,
                                           reason: reason))
            }
        }
        
        return novelEvents.sorted { 
            guard let date1 = $0.event.startDate, let date2 = $1.event.startDate else {
                return false
            }
            return date1 < date2
        }
    }
} 