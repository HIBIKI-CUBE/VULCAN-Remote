//
//  ContentView.swift
//  SwiftUI-BLE-Project
//
//  Created by kazuya ito on 2021/02/02.
//

import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { BaseCameraView() }
    func updateUIView(_ uiView: UIViewType, context: Context) {}
}

class BaseCameraView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        _ = initCaptureSession
        (layer.sublayers?.first as? AVCaptureVideoPreviewLayer)?.frame = frame
    }

    lazy var initCaptureSession: Void = {
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
            .devices.first(where: { $0.position == .back }),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        let session = AVCaptureSession()
        session.addInput(input)
        session.startRunning()

        layer.insertSublayer(AVCaptureVideoPreviewLayer(session: session), at: 0)
    }()
}

struct CameraBackground_Previews: PreviewProvider {
    static var previews: some View {
        CameraBackground()
    }
}
