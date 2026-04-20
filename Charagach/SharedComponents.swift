//
//  SharedComponents.swift
//  Charagach
//
//  Created by macOS on 3/17/26.
//

import SwiftUI
import PhotosUI
import UIKit

// MARK: - Tag Pill

struct TagView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - Condition Badge

struct ConditionBadge: View {
    let condition: PlantCondition

    var color: Color {
        switch condition {
        case .excellent: return .green
        case .good:      return .blue
        case .fair:      return .orange
        }
    }

    var body: some View {
        Text(condition.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - Flow Layout (wrapping HStack)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxH: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += maxH + spacing
                x = 0
                maxH = 0
            }
            maxH = max(maxH, size.height)
            x += size.width + spacing
        }
        height = y + maxH
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var maxH: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += maxH + spacing
                x = bounds.minX
                maxH = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            maxH = max(maxH, size.height)
            x += size.width + spacing
        }
    }
}

// MARK: - Listing Image Pickers

struct ListingImagePickerControls: View {
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var selectedImageData: [Data]
    @Binding var showCamera: Bool
    @Binding var errorMessage: String?

    let maxImageCount: Int

    private var remainingSlots: Int {
        max(0, maxImageCount - selectedImageData.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: max(1, remainingSlots),
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
                .disabled(remainingSlots == 0)

                Spacer()

                Button {
                    openCamera()
                } label: {
                    Label("Open Camera", systemImage: "camera.fill")
                }
                .disabled(remainingSlots == 0)
            }

            if maxImageCount == 0 {
                Text("Remove an existing picture before adding another one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if selectedImageData.isEmpty {
                Text("Add up to \(maxImageCount) clear picture\(maxImageCount == 1 ? "" : "s"). The first picture appears on the marketplace card.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(selectedImageData.enumerated()), id: \.offset) { index, data in
                            SelectedListingImageThumb(data: data) {
                                selectedImageData.remove(at: index)
                                selectedPhotoItems = []
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                Text("\(remainingSlots) picture slot\(remainingSlots == 1 ? "" : "s") left.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "Camera is not available on this device."
            return
        }

        showCamera = true
    }
}

struct SelectedListingImageThumb: View {
    let data: Data
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.green.opacity(0.12))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.green)
                        }
                }
            }
            .frame(width: 86, height: 86)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.65))
            }
            .buttonStyle(.plain)
            .padding(4)
        }
    }
}

struct ExistingListingImageThumb: View {
    let imageURL: String
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.green.opacity(0.12))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.green)
                        }
                }
            }
            .frame(width: 86, height: 86)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.65))
            }
            .buttonStyle(.plain)
            .padding(4)
        }
    }
}

// MARK: - Camera Picker

struct CameraImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraImagePicker

        init(parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
