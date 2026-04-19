//
//  DocumentRow.swift
//  lannaapp
//
//  Extracted from ChatComponents.swift
//

import SwiftUI

struct DocumentRow: View {
    let document: SharedDocument
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: DS.spacingS) {
            Image(systemName: documentIcon)
                .font(.system(size: 16))
                .foregroundColor(DS.primary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(document.name)
                    .font(Typography.bodyMedium)
                    .foregroundColor(DS.textPrimary)
                    .lineLimit(1)

                Text("\(document.type.uppercased()) • \(document.uploadedAt, format: .dateTime.month().day().hour().minute())")
                    .font(Typography.caption)
                    .foregroundColor(DS.textSecondary)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DS.textSecondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(DS.spacingS)
        .background(DS.surface)
        .cornerRadius(DS.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius)
                .stroke(DS.textSecondary.opacity(0.1), lineWidth: 1)
        )
    }

    private var documentIcon: String {
        switch document.type.lowercased() {
        case "pdf":
            return "doc.fill"
        case "txt", "text":
            return "doc.text.fill"
        case "rtf":
            return "doc.richtext.fill"
        default:
            return "doc.fill"
        }
    }
}