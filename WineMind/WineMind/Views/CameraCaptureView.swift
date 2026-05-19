import SwiftUI
import UIKit

struct CameraCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var capturedImage: UIImage?
    @State private var showingPrediction = false
    @State private var showingManualScoring = false
    @State private var isAnalyzing = false
    @State private var wineInfo: WineInfo?
    @State private var errorMessage: String?
    @State private var showingCameraPicker = false
    @State private var showingLibraryPicker = false

    private let recognitionService = WineRecognitionService()

    var body: some View {
        NavigationStack {
            ZStack {
                WineTheme.backgroundGradient.ignoresSafeArea()

                if let image = capturedImage {
                    capturedImageView(image)
                } else {
                    cameraPrompt
                }
            }
            .navigationTitle("Add Wine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(WineTheme.mutedText)
                }
            }
            .sheet(isPresented: $showingCameraPicker) {
                ImagePicker(image: $capturedImage, sourceType: .camera)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showingLibraryPicker) {
                ImagePicker(image: $capturedImage, sourceType: .photoLibrary)
            }
            .fullScreenCover(isPresented: $showingPrediction) {
                if let info = wineInfo {
                    WinePredictionView(
                        wineInfo: info,
                        photoData: capturedImage?.jpegData(compressionQuality: 0.8)
                    )
                }
            }
            .fullScreenCover(isPresented: $showingManualScoring) {
                if let info = wineInfo {
                    WineScoringView(
                        wineInfo: info,
                        photoData: capturedImage?.jpegData(compressionQuality: 0.8)
                    )
                }
            }
        }
    }

    private var cameraPrompt: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(WineTheme.gold.opacity(0.3), lineWidth: 1)
                    .frame(width: 200, height: 200)
                Circle()
                    .stroke(WineTheme.gold.opacity(0.2), lineWidth: 1)
                    .frame(width: 160, height: 160)
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 80))
                    .foregroundStyle(WineTheme.gold.opacity(0.7))
            }

            VStack(spacing: 8) {
                Text("Capture the Label")
                    .font(.wineTitle2)
                    .foregroundStyle(WineTheme.cream)

                GoldDivider().frame(width: 80)

                Text("We'll read the wine details\nautomatically from the photo")
                    .font(.wineCallout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(WineTheme.mutedText)
            }

            VStack(spacing: 12) {
                Button {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showingCameraPicker = true
                    } else {
                        showingLibraryPicker = true
                    }
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WineButtonStyle(prominent: true))

                Button {
                    showingLibraryPicker = true
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WineButtonStyle())

                Button("Enter Manually") {
                    wineInfo = WineInfo(
                        name: "", winery: "", variety: "", region: "",
                        vintage: Calendar.current.component(.year, from: Date()),
                        color: .red, body: .medium, sweetness: .dry
                    )
                    showingManualScoring = true
                }
                .font(.wineCaption)
                .foregroundStyle(WineTheme.dimText)
                .padding(.top, 8)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .onChange(of: capturedImage) { _, newValue in
            if newValue != nil {
                analyzeImage()
            }
        }
    }

    private func capturedImageView(_ image: UIImage) -> some View {
        VStack(spacing: 24) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(WineTheme.gold.opacity(0.4), lineWidth: 1)
                }
                .padding(.horizontal)

            if isAnalyzing {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(WineTheme.gold)
                        .scaleEffect(1.5)
                    Text("Reading the label…")
                        .font(.wineCallout)
                        .italic()
                        .foregroundStyle(WineTheme.gold)
                }
                .padding(.vertical)
            }

            if let error = errorMessage {
                VStack(spacing: 12) {
                    Text(error)
                        .font(.wineCallout)
                        .foregroundStyle(WineTheme.burgundyLight)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Enter Manually") {
                        wineInfo = WineInfo(
                            name: "", winery: "", variety: "", region: "",
                            vintage: Calendar.current.component(.year, from: Date()),
                            color: .red, body: .medium, sweetness: .dry
                        )
                        showingManualScoring = true
                    }
                    .buttonStyle(WineButtonStyle(prominent: true))
                }
                .padding()
            }

            Button("Retake") {
                capturedImage = nil
                errorMessage = nil
            }
            .buttonStyle(WineButtonStyle())
        }
    }

    private func analyzeImage() {
        guard let image = capturedImage else { return }
        isAnalyzing = true
        errorMessage = nil

        Task {
            do {
                let info = try await recognitionService.recognizeWine(from: image)
                await MainActor.run {
                    wineInfo = info
                    isAnalyzing = false
                    showingPrediction = true
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    errorMessage = "Could not read the label. Try a clearer photo."
                }
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
