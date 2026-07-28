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

            Button("Clear") {
                model.clear()
            }
            .disabled(model.files.isEmpty || model.isBusy)

            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .padding(.horizontal, 4)
    }
}
