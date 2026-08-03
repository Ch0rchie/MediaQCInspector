//
//  PDFReportRenderer.swift
//  ProResQCInspector
//
//  Created by gelbda53 on 7/29/26.
//

import Foundation
import AppKit

final class PDFReportRenderer {

    struct Document {
        var title: String
        var sections: [Section]

        init(title: String, sections: [Section] = []) {
            self.title = title
            self.sections = sections
        }

        struct Section {
            var title: String
            var body: String

            init(title: String, body: String) {
                self.title = title
                self.body = body
            }
        }
    }

    // MARK: - Existing attributed-string PDF export

    func renderPDFData(from attributed: NSAttributedString) throws -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 48
        let contentWidth = pageWidth - (margin * 2)

        let boundingRect = attributed.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        let height = max(pageHeight, ceil(boundingRect.height) + (margin * 2))

        let textView = NSTextView(frame: CGRect(x: 0, y: 0, width: pageWidth, height: height))
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = true
        textView.backgroundColor = .white
        textView.textColor = .black
        textView.textContainerInset = NSSize(width: margin, height: margin)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
        textView.textStorage?.setAttributedString(attributed)
        textView.layoutSubtreeIfNeeded()

        return textView.dataWithPDF(inside: textView.bounds)
    }

    // MARK: - New bridge entry point

    func renderPDFData(_ document: Document) throws -> Data {
        let attributed = documentAsAttributedString(document)
        return try renderPDFData(from: attributed)
    }

    // MARK: - Bridge converter

    private func documentAsAttributedString(_ document: Document) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let title = NSAttributedString(
            string: document.title + "\n\n",
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 18),
                .foregroundColor: NSColor.labelColor
            ]
        )
        result.append(title)

        for section in document.sections {
            let sectionTitle = NSAttributedString(
                string: section.title + "\n",
                attributes: [
                    .font: NSFont.boldSystemFont(ofSize: 13),
                    .foregroundColor: NSColor.labelColor
                ]
            )
            result.append(sectionTitle)

            let body = NSAttributedString(
                string: section.body + "\n\n",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.labelColor
                ]
            )
            result.append(body)
        }

        return result
    }
}
