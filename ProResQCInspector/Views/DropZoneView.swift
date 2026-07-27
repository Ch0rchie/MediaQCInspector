import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @ObservedObject var model: QCModel

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        model.isDropTarget ? Color.accentColor : Color.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                    )
            )
            .overlay(
                VStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 42))
                        .foregroundStyle(.primary)

                    Text("Drop ProRes Files Here")
                        .font(.headline)

                    Text("or")
                        .foregroundStyle(.secondary)

                    Button("Choose Files") {
                        model.chooseFiles()
                    }
                }
                .padding()
            )
            .frame(height: 180)
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $model.isDropTarget) { providers in
                model.handleDrop(providers: providers)
            }
    }
}
