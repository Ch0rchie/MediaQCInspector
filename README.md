# Media QC Inspector

> **Validate. Inspect. Deliver.**

Version 0.5.0

Media QC Inspector is a native macOS application for validating Apple ProRes media files by detecting decoder errors, extracting technical metadata, identifying affected regions, and generating professional Technical Validation Reports for production workflows.

Beginning with v0.5.0, Media QC Inspector is completely self-contained. FFmpeg and FFprobe are bundled with the application, eliminating the need for any additional software installation.

## Screenshot

![Media QC Inspector](Documentation/Screenshot.png)

## Features

### Analysis
- Apple ProRes decoder validation
- Technical metadata extraction
- Automatic decoder error detection
- Error localization
- Editorial review window calculation
- Self-contained analysis engine
- No additional software installation is required

### Queue Management
- Drag-and-drop queue
- Add files while analysis is running
- Automatic queue processing
- Stop / Resume analysis
- Remove individual files
- Current file auto-selection

### Live Progress
- Current file progress
- Queue progress
- Elapsed time
- Remaining time estimate
- Live status updates

### Reporting
- Technical Validation Reports
- Rich text report copying
- PDF report export
- Copy report to clipboard
- Professional PASS / FAIL report formatting

### User Interface
- PASS / FAIL status badges
- About window with dynamic version/build information
- Native macOS SwiftUI interface

## Installation

1. Download Media QC Inspector.
2. Drag the application into the Applications folder.
3. Launch Media QC Inspector.
4. Drag one or more ProRes files into the queue.
5. Click **Start** to begin validation.
-No additional software installation is required.

## Requirements

- macOS 14 or later
- Apple Silicon

FFmpeg and FFprobe are bundled with the application, no additional software required

## Roadmap

### v0.6
- Additional QC modules
- Expanded media validation
- Batch reporting improvements
- User preferences

### Future
- Windows version (long-term)
- Shared cross-platform architecture

See CHANGELOG.md for complete release history.

## Documentation

Additional project documentation is available in the `Documentation` folder.

- **Brand_Guidelines.md** — Official branding, visual identity, typography, color palette, icon usage, animation, and product design standards.
- **DESIGN.md** — Technical architecture, application design, and implementation roadmap.
- **CHANGELOG.md** — Version history and release notes.


## License

Copyright © 2026.

License information will be added in a future release.
