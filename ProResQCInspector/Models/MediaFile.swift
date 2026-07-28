import Foundation

struct MediaFile: Identifiable, Hashable {
    let id = UUID()
    let url: URL

    var status: String = "Ready to Analyze"
    var result: String = "Not Yet Analyzed"
    var codec: String = "—"
    var resolution: String = "—"
    var frameRate: String = "—"
    var duration: String = "—"
    var fileSize: String = "—"
    var region: String = "—"
    var report: String = ""
}
