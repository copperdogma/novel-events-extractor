# Calendar Novelty Analyzer

## Core Purpose
Identify and present novel or non-routine calendar events to help users prepare for and plan around distinctive activities in their schedule, using AI-powered pattern analysis of historical calendar data to dynamically determine what constitutes "routine."

## Outstanding Questions
### High Priority
- What is the ideal output format and location?
  - Context: Need to balance accessibility with unobtrusiveness
  - Related sections: User Interface
  - Questions:
    - What platforms should be supported (phone, desktop, etc.)?
    - What format would best support quick glances?
  - Status: Needs specification

## Fundamental Principles
1. **Dynamic Pattern Recognition**
   - Use AI to identify patterns without preset rules
   - Consider full year of historical context
   - Adapt to changing patterns over time

2. **Contextual Novelty**
   - Define novelty based on historical patterns
   - Consider seasonal and annual patterns
   - Account for evolving routines

3. **Minimal Interaction Required**
   - Simple on-demand analysis
   - No configuration needed
   - Clear, at-a-glance information

## Core Requirements

### 1. Calendar Integration
- Connect to local Apple Calendar (Calendar.app):
  - Use macOS Calendar API
  - Access local calendar database
  - No authentication complexity
- Read historical calendar data (1 year minimum)
- Read upcoming calendar data:
  - User-specified window
  - Minimum: 1 week ahead
  - Maximum: 1 year ahead
- Handle all calendar types (work, personal, etc.) uniformly

### 2. Pattern Detection
- AI-powered analysis of calendar patterns:
  - Time-based patterns (daily, weekly, monthly)
  - Event similarity detection
  - Frequency analysis
  - Seasonal patterns
- Apply recency weighting:
  - More recent patterns weighted more heavily
  - Gradual weight decay for older patterns
- Rolling 12-month historical window

### 3. Novelty Analysis
- Compare upcoming events against detected patterns
- Consider multiple novelty factors:
  - Timing novelty (unusual time/day)
  - Content novelty (unusual event type)
  - Context novelty (unusual combinations)
- Store novelty detection reasoning for debugging

### 4. User Interface
- Simple command-line execution
- Plain text output file:
  - Header with scope and generation timestamp
  - Simple chronological list of events
  - Format per event:
    - Month abbreviation and day (e.g., "Jan 15")
    - 24-hour time without separators (e.g., "1500")
    - Event title
    - Calendar name in brackets
  - Example format:
    ```
    Novel events found in next 2 weeks:

    Generated: 2025-01-13 15:30

    Jan 15 0900 Full-day strategy workshop [Work]
    Jan 17 1230 Lunch with new team [Personal]
    Jan 23 1500 Quarterly planning [Work]
    Jan 24 1900 Theater performance [Personal]
    ```
- Focus on glanceability:
  - Consistent column alignment
  - Compact single-line entries
  - No grouping or separators between events
  - Generation timestamp for context

## Success Criteria
1. Successfully identifies truly novel events without manual pattern definition
2. Pattern analysis completes in under 30 seconds
3. Minimal false positives (routine events marked as novel)
4. Easy to run and check results
5. Results are clear and actionable

## Development Priorities

### MVP Phase
1. Core calendar integration
2. Basic AI pattern analysis
3. Simple novelty detection
4. Basic file/console output
5. On-demand execution

### Future Phases
1. Scheduled updates
2. Configuration options:
   - Novelty sensitivity settings
   - Custom "always novel" flags
3. Multiple interface options
4. Advanced pattern recognition
5. Cross-platform synchronization