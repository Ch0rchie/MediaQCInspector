import SwiftUI

struct FooterView: View {

    @ObservedObject var model: QCModel
    @State private var showClearConfirmation = false
    @State private var showRemoveConfirmation = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            footerBody(currentDate: timeline.date)
        }
    }

    @ViewBuilder
    private func footerBody(currentDate: Date) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(model.statusText)
                        .font(.headline)

                    Spacer(minLength: 8)

                    Text(liveElapsedText(at: currentDate))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Text(liveRemainingText(at: currentDate))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: model.progress)
                    .progressViewStyle(.linear)
            }

            Spacer(minLength: 12)

            Button(model.isBusy ? "STOP" : "Analyze") {
                if model.isBusy {
                    model.stopAnalysis()
                } else {
                    model.analyze()
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Remove") {
                showRemoveConfirmation = true
            }
            .buttonStyle(.bordered)

            Button("Clear") {
                showClearConfirmation = true
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .confirmationDialog(
            removeDialogTitle,
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                model.removeSelectedFile()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(removeDialogMessage)
        }
        .confirmationDialog(
            clearDialogTitle,
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) {
                model.clear()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(clearDialogMessage)
        }
    }

    private func liveElapsedText(at currentDate: Date) -> String {
        print("isBusy:", model.isBusy, "start:", model.analysisStartedAt as Any)
        guard model.isBusy, let start = model.analysisStartedAt else {
            return model.elapsedText
        }

        return Self.formatDuration(currentDate.timeIntervalSince(start))
    }

    private func liveRemainingText(at currentDate: Date) -> String {
        guard model.isBusy, let start = model.analysisStartedAt else {
            return model.remainingText
        }

        guard model.progress > 0.01 else {
            return "--:--"
        }

        let elapsed = currentDate.timeIntervalSince(start)
        let estimatedTotal = elapsed / model.progress
        let remaining = max(0, estimatedTotal - elapsed)
        return Self.formatDuration(remaining)
    }

    private var removeDialogTitle: String {
        if model.isBusy {
            return "Stop and remove file?"
        } else {
            return "Remove selected file?"
        }
    }

    private var removeDialogMessage: String {
        if model.isBusy {
            return "This will stop the current analysis and remove the selected file from the queue."
        } else {
            return "This will remove the selected file from the queue."
        }
    }

    private var clearDialogTitle: String {
        if model.isBusy {
            return "Stop and clear queue?"
        } else {
            return "Clear queue?"
        }
    }

    private var clearDialogMessage: String {
        if model.isBusy {
            return "This will stop the current analysis and clear the queue."
        } else {
            return "This will remove all files from the queue. This action cannot be undone."
        }
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let minutes = totalSeconds / 60
        let remaining = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, remaining)
    }
}
