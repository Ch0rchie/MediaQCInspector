import SwiftUI

struct FooterView: View {
    @ObservedObject var model: QCModel

    var body: some View {
        HStack {
            Button("Analyze") {
                model.analyze()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(model.files.isEmpty || model.isBusy)

            Button("Clear") {
                model.clear()
            }
            .disabled(model.files.isEmpty && !model.isBusy)

            Button("Copy Report") {
                model.copyReport()
            }
            .disabled(!model.canCopyReport)

            Spacer()
        }
        .padding(.top, 4)
    }
}
