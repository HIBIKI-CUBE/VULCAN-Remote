//
//  home.swift
//  SwiftUI-BLE-Project
//
//  Created by HIBIKI CUBE on 2022/05/23.
//

import SwiftUI
import SwiftUIJoystick
import CoreBluetooth

struct ActivityIndicator: UIViewRepresentable {
  func makeUIView(context: UIViewRepresentableContext<ActivityIndicator>) -> UIActivityIndicatorView {
    return UIActivityIndicatorView(style: .large)
  }
  func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ActivityIndicator>) {
    uiView.startAnimating()
  }
}

func bleFinish(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
  let data: Data = characteristic.value!
  let hexStr = data.map { String(format: "%02hhx ", $0) }.joined()
  print(hexStr)
}

struct HomeView: View {
  @Environment(\.colorScheme) private var colorScheme: ColorScheme
  @Environment(\.scenePhase) private var scenePhase
  
  @EnvironmentObject var bleManager: CoreBluetoothViewModel
  @State var bl = 15.0
  @State var showScanDevice = false
  @State var ledState = false
  @State var suggestReset = false
  @State var mode = 0
  @StateObject var joystickMonitor = JoystickMonitor()
  @State var rightPower = 0.0
  @State var leftPower = 0.0
  @State var active = false
  @State var distance = 0.0
  @State var angle = 0.0
  @State var bleWaiting = false
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
            if(!bleManager.isConnected){
              Image("App-logo")
                .resizable()
                .frame(width: screen.size.width / 6, height: screen.size.width / 6)
                .cornerRadius(screen.size.width / 6 * 0.2237)
              HStack{
                ActivityIndicator()
                VStack{
                  Text("VULCANの電源を入れてください")
                    .font(.title2)
                  if(suggestReset){
                    Text("VULCANをリセットしてみてください")
                      .font(.title3)
                  }
                }
              }.onAppear{
                suggestReset = false
              }
            }else{
              Spacer()
              switch mode{
              case 0:
                Joystick(monitor: joystickMonitor, width: bodyView.size.width * 0.8, shape: .circle)
                  .onChange(of: joystickMonitor.xyPoint){ value in
                    if(joystickMonitor.xyPoint == .zero){
                      let data = """
                        {"distance":\(Int(0)),"angle":\(Int(0)),"active":false}
                        """.data(using: .utf8)!
                      bleManager.connectedPeripheral.peripheral.writeValue(data, for: bleManager.connectedCharacteristic.characteristic, type: .withResponse)
                      
                      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05){
                        
                      bleManager.connectedPeripheral.peripheral.writeValue(data, for: bleManager.connectedCharacteristic.characteristic, type: .withResponse)
                      }
                      print("stop")
                    }
                    if(!bleWaiting){
                      distance = sqrt(pow(joystickMonitor.xyPoint.x, 2) + pow(joystickMonitor.xyPoint.y, 2)) / (bodyView.size.width * 0.8) / 3
                      angle = joystickMonitor.xyPoint == .zero ? 0 : atan2(joystickMonitor.xyPoint.x, -joystickMonitor.xyPoint.y) * 180.0 / CGFloat.pi
                      let data = """
                      {"distance":\(Int(distance * 1000)),"angle":\(Int(angle)),"active":\(active ? "true" : "false")}
                      """.data(using: .utf8)!
                      bleManager.connectedPeripheral.peripheral.writeValue(data, for: bleManager.connectedCharacteristic.characteristic, type: .withResponse)
                      bleWaiting = true
                      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05){
                        bleWaiting = false
                      }
                    }
                  }
                Spacer()
                Text("""
                  dis: \(distance), angle: \(angle), send: {"distance":\(Int(distance * 1000)),"angle":\(Int(angle))}
                  """)
              case 1:
                Text("ライドモード")
                  .font(.largeTitle)
                Spacer()
              case 2:
                HStack{
                  VStack{
                    Slider(value: $rightPower, in: -1 ... 1)
                      .padding()
                      .rotationEffect(Angle(degrees: 90))
                    Text("\(rightPower)")
                  }
                  VStack{
                    Slider(value: $leftPower, in: -1 ... 1)
                      .padding()
                      .rotationEffect(Angle(degrees: 90))
                    Text("\(leftPower)")
                  }
                }
                Spacer()
              default:
                Text("不正なモードです")
                Spacer()
              }
              Toggle("Active", isOn: $active)
                .scaledToFit()
                .onChange(of: active){ value in
                  let data = """
                    {"active":\(active ? "true" : "false")}
                    """.data(using: .utf8)!
                  bleManager.connectedPeripheral.peripheral.writeValue(data, for: bleManager.connectedCharacteristic.characteristic, type: .withResponse)
                  print(data)
                  bleWaiting = true
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.05){
                    bleWaiting = false
                  }
                }
              Picker(selection: $mode, label: Text("モード選択"), content: {
                Text("リモートモード").tag(0)
                Text("ライドモード").tag(1)
                Text("ダイレクトモード").tag(2)
              })
              .padding()
              .pickerStyle(SegmentedPickerStyle())
            }
          }
          .frame(height: bodyView.size.height * 3/4)
          Button("デバイス設定", action: {
            showScanDevice = true
          })
          .frame(width: screen.width)
          .foregroundColor(.primary)
          .buttonStyle(.bordered)
        }
      }
    }
    .sheet(isPresented: $showScanDevice) {
      ScanDevice()
    }
    .onChange(of: scenePhase) { phase in
      if(phase == .background || phase == .inactive){
        suggestReset = false
      }
      if(phase == .active){
        DispatchQueue.main.asyncAfter(deadline: .now() + 5){
          suggestReset = true
        }
      }
    }
  }
}

struct HomeView_Previews: PreviewProvider {
  static var previews: some View {
    HomeView()
      .previewDevice("iPhone 11 Pro Max")
      .preferredColorScheme(.dark)
  }
}
