import SwiftUI

struct FooterView: View {
    @ObservedObject var model: QCModel
    @State private var showingStopConfirmation = false
    @State private var showingRemoveConfirmation = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if model.isBusy {
                Button("Stop") {
                    showingStopConfirmation = true
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button(model.primaryActionTitle) {
                    model.analyze()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!model.canAnalyzeOrResume)
            }

            Button("Remove") {
                showingRemoveConfirmation = true
            }
            .buttonStyle(.bordered)
            .disabled(!model.canRemoveSelectedFile)

            Button("Clear") {
                model.clear()
            }
            .buttonStyle(.bordered)
            .disabled(model.files.isEmpty || model.isBusy)

            Spacer(minLength: 0)

            if model.isBusy {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text("Status:")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(model.statusText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    HStack(alignment: .center, spacing: 6) {
                        Text("Queue")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ProgressView(value: model.progress)
                            .frame(width: 175)

                        Text("\(Int((model.progress * 100).rounded()))%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 18) {
                        HStack(spacing: 4) {
                            Text("Elapsed:")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(model.elapsedText)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 4) {
                            Text("Remaining:")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(remainingValue)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: 350, alignment: .leading)
                .offset(x: 30)
            } else {
                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 6)
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
        .frame(height: 74)
        .confirmationDialog(
            "Stop analysis?",
            isPresented: $showingStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("Stop", role: .destructive) {
                model.stopAnalysis()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will stop the current file and pause the queue. You can resume later.")
        }
        .confirmationDialog(
            model.shouldConfirmStopAndRemoveSelectedFile ? "Stop and remove this file?" : "Remove selected file?",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            if model.shouldConfirmStopAndRemoveSelectedFile {
                Button("Stop & Remove", role: .destructive) {
                    model.removeSelectedFile()
                }
            } else {
                Button("Remove", role: .destructive) {
                    model.removeSelectedFile()
                }
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            if model.shouldConfirmStopAndRemoveSelectedFile {
                Text("This file is currently being analyzed. Stopping now will remove it from the queue and continue with the next file.")
            } else {
                Text("Remove the selected file from the queue?")
            }
        }
    }

    private var remainingValue: String {
        model.etaText.replacingOccurrences(of: "ETA ", with: "")
    }
}
