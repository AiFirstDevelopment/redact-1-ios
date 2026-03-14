import SwiftUI

struct FileRow: View {
    let file: EvidenceFile

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.filename)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Text(file.formattedSize)
                    Text("•")
                    Text(file.status.displayName)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            FileStatusIndicator(status: file.status)
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch file.fileType {
        case .image: return "photo"
        case .pdf: return "doc.text"
        }
    }

    private var iconColor: Color {
        switch file.fileType {
        case .image: return .blue
        case .pdf: return .red
        }
    }
}

struct FileStatusIndicator: View {
    let status: FileStatus

    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 10, height: 10)
    }

    private var statusColor: Color {
        switch status {
        case .uploaded: return .gray
        case .processing: return .orange
        case .detected: return .yellow
        case .reviewed: return .green
        case .exported: return .blue
        }
    }
}

#Preview {
    List {
        FileRow(file: EvidenceFile(
            id: "1",
            requestId: "req",
            filename: "bodycam_001.jpg",
            fileType: .image,
            mimeType: "image/jpeg",
            fileSize: 2500000,
            originalR2Key: "key",
            redactedR2Key: nil,
            status: .detected,
            uploadedBy: "user",
            createdAt: 0,
            updatedAt: 0
        ))

        FileRow(file: EvidenceFile(
            id: "2",
            requestId: "req",
            filename: "report.pdf",
            fileType: .pdf,
            mimeType: "application/pdf",
            fileSize: 150000,
            originalR2Key: "key",
            redactedR2Key: nil,
            status: .reviewed,
            uploadedBy: "user",
            createdAt: 0,
            updatedAt: 0
        ))
    }
}
