# Media QC Inspector

All notable changes to this project will be documented in this file.

---

## v0.5.0 — July 30, 2026

### Added
- Bundled standalone FFmpeg and FFprobe executables
- Self-contained analysis engine
- Startup validation of bundled analysis tools
- Tool version reporting in the About window

### Changed
- Removed the runtime dependency on Homebrew-installed FFmpeg and FFprobe
- Updated ToolLocator to resolve bundled executables
- Simplified application installation and distribution

### Verified
- Successfully validated on a clean macOS installation
- Confirmed operation without external FFmpeg installation
- Confirmed bundled standalone executables function correctly


## v0.4.0 — July 29, 2026

### Added
- Dynamic analysis queue
- Live queue processing while adding files
- Current file progress indicator
- Queue progress indicator
- Elapsed and Remaining timers
- Queue ETA
- Resume after Stop
- Stop confirmation dialog
- Remove confirmation dialog
- Export Report as PDF
- Rich text report copying
- Improved report formatting
- Current file auto-selection
- Result badge redesign
- About window version/build display
- Improved status messaging throughout analysis

### Changed
- Report generation redesigned with shared formatting for the detail view, clipboard copy, and PDF export.

### Improved
- Queue workflow
- Detail panel layout
- Footer layout
- Window sizing
- Report readability
- Progress reporting
- Stop/Resume behavior
- Queue management
- Overall UI polish

### Fixed
- Stop & Remove queue bug
- Resume restarting completed files
- Live queue updates
- Progress calculation while queue changes
- ETA updates while queue changes


## v0.3.0 — July 28, 2026

### Added
- FFmpeg decoder validation engine
- Metadata extraction
- Technical Validation Report
- Analysis date and time
- Editorial review window generation
- Queue management
- Drag-and-drop media import
- Copy Report functionality

### Improved
- PASS report formatting
- FAIL report formatting
- Report readability
- Error localization accuracy
- Queue interaction
- Remove file workflow

### Verified
- Validated against benchmark ProRes files with no decode errors.
- Validated against benchmark ProRes files containing known decode errors.
- Verified error localization against benchmark timestamps.
