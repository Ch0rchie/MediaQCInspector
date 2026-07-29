import SwiftUI

struct FooterView: View {
    @ObservedObject var model: QCModel

    var body: some View {
        HStack(spacing: 8) {
            Button("Analyze") {
                model.analyze()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(model.files.isEmpty || model.isBusy)

            Button("Remove Selected") {
                model.removeSelectedFile()
            }
            .disabled(!model.canRemoveSelectedFile)

            Button("Clear") {
                model.clear()
            }
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
    }
}
