//
//  PDFReportRenderer.swift
//  ProResQCInspector
//
//  Created by gelbda53 on 7/29/26.
//


import Foundation
import AppKit

final class PDFReportRenderer {
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
}