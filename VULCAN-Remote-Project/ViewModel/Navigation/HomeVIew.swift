//
//  home.swift
//  SwiftUI-BLE-Project
//
//  Created by HIBIKI CUBE on 2022/05/23.
//

import SwiftUI

struct ActivityIndicator: UIViewRepresentable {
    func makeUIView(context: UIViewRepresentableContext<ActivityIndicator>) -> UIActivityIndicatorView {
        return UIActivityIndicatorView(style: .large)
    }
    func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ActivityIndicator>) {
        uiView.startAnimating()
    }
}

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @EnvironmentObject var bleManager: CoreBluetoothViewModel
    @State var bl = 15.0
    @State var showScanDevice = false
    @State var ledState = false
    @State var tryReset = false
    
    let screen = UIScreen.main.bounds
    
    var body: some View {
        
        let backgroundBlurColorTint = (colorScheme == .dark ? 0.25 : 1.0)
        ZStack(alignment: .top){
            CameraView()
                .blur(radius: bl)
                .scaledToFill()
                .frame(width: screen.width)
                .edgesIgnoringSafeArea(.all)
            Rectangle()
                .fill(
                    Color.init(
                        red: backgroundBlurColorTint,
                        green: backgroundBlurColorTint,
                        blue: backgroundBlurColorTint
                    )
                )
                .opacity(0.5)
                .blendMode(.normal)
                .edgesIgnoringSafeArea(.all)
            GeometryReader { bodyView in
                VStack{
                    VStack{
                        if(bleManager.isSearching || !bleManager.targetServiceFound){
                            HStack{
                                ActivityIndicator()
                                VStack{
                                    Text("VULCANの電源をオンにしてください")
                                    if(tryReset){
                                        Text("VULCANをリセットしてみてください")
                                    }
                                }
                            }.onAppear{
                                DispatchQueue.main.asyncAfter(deadline: .now() + 5){
                                    tryReset = true
                                }
                            }
                        }else{
                            Button(action: {
                            })
                            {
                                Circle()
                                    .scaledToFit()
                                    .padding()
                                    .foregroundColor(ledState ? Color.white : Color.gray)
                                    .opacity(0.8)
                            }
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged{ _ in
                                        let data = "1".data(using: .ascii)!
                                        bleManager.connectedPeripheral.peripheral.writeValue(data, for: bleManager.connectedCharacteristic.characteristic, type: .withResponse)
                                        ledState = true
                                    }
                                    .onEnded{ _ in
                                        let data = "0".data(using: .ascii)!
                                        bleManager.connectedPeripheral.peripheral.writeValue(data, for: bleManager.connectedCharacteristic.characteristic, type: .withResponse)
                                        ledState = false
                                    }
                            )
                        }
                    }
                    .frame(height: bodyView.size.height * 3/4)
                    if(bleManager.targetServiceFound){
                    }
                    Button("デバイス設定", action: {
                        showScanDevice = true
                    })
                    .frame(width: screen.width)
                    .foregroundColor(.primary)
                    .buttonStyle(.bordered)
                }
            }
        }.sheet(isPresented: $showScanDevice) {
            ScanDevice()
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .previewDevice("iPhone 11 Pro Max")
            .preferredColorScheme(.dark)
            .previewInterfaceOrientation(.portrait)
    }
}
