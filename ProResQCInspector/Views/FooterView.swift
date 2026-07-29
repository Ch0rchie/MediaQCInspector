import SwiftUI

struct FooterView: View {
    @ObservedObject var model: QCModel
    @State private var showingStopAndRemoveConfirmation = false

    var body: some View {
        HStack(spacing: 8) {
            if model.isBusy {
                Button("Stop") {
                    model.stopAnalysis()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button("Analyze") {
                    model.analyze()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(model.files.isEmpty)
            }

            Button("Remove") {
                if model.shouldConfirmStopAndRemoveSelectedFile {
                    showingStopAndRemoveConfirmation = true
                } else {
                    model.removeSelectedFile()
                }
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
                VStack(alignment: .trailing, spacing: 4) {
                    Text(model.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ProgressView(value: model.progress)
                            .frame(width: 180)

                        Text(model.elapsedText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .trailing)
                    }
                }
            } else {
                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
        .padding(.horizontal, 4)
        .frame(height: 36)
        .confirmationDialog(
            "Stop analysis and remove this file?",
            isPresented: $showingStopAndRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Stop & Remove", role: .destructive) {
                model.removeSelectedFile()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This file is currently being analyzed. Stopping now will remove it from the queue and continue with the next file.")
        }
    }
}
