# Media QC Inspector Design Notes

Version 0.5.0

This document describes the design philosophy, user interface guidelines, and architectural decisions that define Media QC Inspector. It serves as a reference for maintaining a consistent user experience as the application evolves.

---

# Design Goals

Media QC Inspector is designed for production coordinators, media operators, and post-production teams who need to quickly validate Apple ProRes media files.

The application should:

- Provide a native macOS experience.
- Require minimal training.
- Present technical information clearly.
- Emphasize production-friendly terminology.
- Keep the workflow simple and efficient.
- Generate objective, professional reports.

Every design decision should prioritize clarity and speed over unnecessary complexity.

---

# Core Principles

- Keep result badges consistent throughout the application.
- Keep reports objective and application-generated.
- Favor production terminology over developer terminology.
- Minimize clicks and user interaction.
- Keep queue density high without sacrificing readability.
- Preserve the soft blue selected state throughout the application.
- Maintain a clean, professional appearance suitable for production environments.

---

# User Interface Philosophy

The interface is divided into three primary areas:

## Queue

The queue provides a compact overview of every file being processed.

Goals:

- Show as many files as practical.
- Clearly communicate processing status.
- Allow rapid file management.
- Minimize visual clutter.

The queue should always remain secondary to the detailed inspection view.

---

## Detail Panel

The detail panel presents the currently selected file.

Priority order:

1. Result badge
2. File information
3. Technical metadata
4. Validation report

The analysis result should always be immediately recognizable without requiring the user to read the report.

---

## Footer

The footer communicates analysis progress.

Information is presented in order of importance:

- Current status
- Queue progress
- Elapsed time
- Remaining time estimate

The footer intentionally avoids unnecessary decoration and updates continuously during analysis.

---

# Queue Philosophy

Queue management should require as little user interaction as possible.

Design decisions:

- Files may be added while analysis is running.
- Analysis automatically continues when new files are added.
- Removing the current file immediately advances to the next file.
- Resume continues from the next incomplete file.
- Completed files remain visible until cleared.
- Queue progress represents the entire queue, not only the current file.

---

# Progress Philosophy

Two separate progress indicators are used.

## Current File Progress

Represents progress through the currently analyzed file.

Purpose:

- Indicates activity.
- Provides confidence that analysis is progressing.
- Resets for each file.

---

## Queue Progress

Represents completion of the overall queue.

Purpose:

- Shows total workload.
- Updates immediately when files are added.
- Recalculates dynamically throughout analysis.

Elapsed and Remaining time estimates update continuously based on queue changes.

---

# Reporting Philosophy

Reports are intended for production workflows.

They should remain objective, concise, and easy to distribute.

Reports should never imply personal authorship.

Avoid wording such as:

- "I found"
- "We detected"
- "Our analysis"

Preferred wording:

- "Analysis detected..."
- "Validation identified..."
- "Decoder errors were detected..."

Reports should never reference FFmpeg directly.

---

## PASS Reports

PASS reports should remain concise.

Typical structure:

- Summary
- Technical metadata
- Validation result

No unnecessary explanation should be included.

---

## FAIL Reports

FAIL reports provide actionable information.

Standard sections:

- Summary
- Findings
- Affected Region
- Recommended Action

Descriptions should use production terminology rather than implementation details whenever possible.

---

## Metadata Failed Reports

Metadata failures should clearly explain that technical information could not be extracted.

The report should distinguish metadata failures from decoder failures.

---

# Status Messaging

Status messages should remain short and descriptive.

Examples:

- Initializing...
- Validating decoder...
- Extracting metadata...
- Generating report...
- Complete

Status text should remain neutral because the Result Badge already communicates PASS or FAIL visually.

---

# Result Badges

Result badges provide immediate recognition of analysis status.

Standard colors:

- PASS — Green
- FAIL — Red
- ANALYZING — Blue
- METADATA FAILED — Orange

Badges should be used consistently throughout the application.

Large badges are used in the detail panel.

Compact badges are used in the queue.

---

# Shared Values

## Corner Radius

- Cards: 12
- Metric cards: 8

## Colors

PASS: Green

FAIL: Red

ANALYZING: Blue

METADATA FAILED: Orange

Selected Queue Row: Soft Blue

---

# Components

## ResultBadgeView

Shared badge component used throughout the application.

Large style:

- Detail panel

Compact style:

- Queue

---

## Queue Cards

Queue cards should remain compact and readable.

Each card displays:

- Result badge
- Filename
- Processing state

---

## Detail Panel

The detail panel emphasizes:

1. Validation result
2. Technical information
3. Generated report

---

# Typography

Typography follows the native macOS appearance whenever possible.

Guidelines:

- Use bold labels for important information.
- Keep filenames prominent.
- Keep metric labels small and secondary.
- Use monospaced digits for timers and percentages.
- Avoid excessive font sizes.

---

# Application Architecture

Beginning with v0.5.0, Media QC Inspector is a fully self-contained macOS application.

Standalone FFmpeg and FFprobe executables are bundled inside the application and located at runtime through the ToolLocator service.

No external software installation is required.

The analysis engine currently consists of:

- ToolLocator validates that bundled analysis tools are available during application startup before media analysis begins
- FFmpegScanner
- ReportFormatter
- PDFReportRenderer

This architecture separates media analysis from the user interface, allowing future QC modules to be added without affecting the overall application workflow.

---

# Future Design Direction

Future releases may include:

- Additional QC modules
- Batch reporting improvements
- User Preferences
- Windows version
- Shared cross-platform architecture

Future enhancements should preserve the existing design philosophy while maintaining a simple production-focused workflow.

---

# Design Objective

Media QC Inspector should feel like a professional desktop application built specifically for production media validation.

Every interface element should help users answer three questions as quickly as possible:

1. Did the file pass?
2. If not, where is the problem?
3. What action should be taken next?

Any future feature should reinforce those goals while maintaining a clean, efficient, and production-focused user experience.
