//
//  HomeView.swift
//  SwiftUI-BLE-Project
//
//  Created by HIBIKI CUBE on 2022/05/23.
//

import SwiftUI
import SwiftUIJoystick
import BudouX
import CoreBluetooth
import simd

enum driveMode: Int {
  case remote
  case ride
  case direct
}


func sigmoidRange(value: Double, center: Double, range: Double, strength: Double = 2.5) -> Double{
  let e = 2.71828182845904523536028747135266249776
  return (1/(1+pow(e, -strength * (value - center + range)))) * (1/(1+pow(e, strength * (value - center - range))))
}


func sigmoid(value: Double, center: Double, strength: Double = -100.0) -> Double{
  let e = 2.71828182845904523536028747135266249776
  return 1/(1+pow(e, -strength * (value - center)))
}

struct HomeView: View {
  @Environment(\.colorScheme) private var colorScheme: ColorScheme
  @Environment(\.scenePhase) private var scenePhase
  
  @EnvironmentObject var bleManager: CoreBluetoothViewModel
  @StateObject var joystickMonitor = JoystickMonitor()
  @State var blur = 30.0
  @State var video = false
  @State var suggestReset = false
  @State var showScanDevice = false
  @State var bleWaiting = false
  @State var mode = driveMode.remote
  @State var active = false
  @State var fast = false
  @State var distance = 0.0
  @State var angle = 0.0
  @State var rightPower = 0.0
  @State var leftPower = 0.0
  @State var errorNoticed = false
  @State var response = ""
  @State var readDistance = 0.0
  @State var readAngle = 0.0
  let screen = UIScreen.main.bounds
  let vibrate = UINotificationFeedbackGenerator()
  let bleDelay = 0.03
  let readDelay = 0.2
  let testAngle = 90.0
  let testDistance = 1.0
  
  var body: some View {
    
    let backgroundBlurColorTint = (colorScheme == .dark ? 0.25 : 1.0)
    ZStack{
      CameraView()
        .blur(radius: blur)
        .scaledToFill()
        .frame(width: screen.width)
        .edgesIgnoringSafeArea(.all)
        .animation(.default, value: blur)
      Rectangle()
        .fill(
          Color.init(
            red: backgroundBlurColorTint,
            green: backgroundBlurColorTint,
            blue: backgroundBlurColorTint
          )
        )
        .opacity(0.5 * (min(blur, 24.0) / 15.0))
        .blendMode(.normal)
        .edgesIgnoringSafeArea(.all)
        .animation(.default, value: blur)
      VStack{
        VStack{
          Spacer()
          if(!bleManager.isConnected){
            Image("App-logo")
              .resizable()
              .aspectRatio(1, contentMode: .fit)
              .frame(width: screen.width / 6)
              .cornerRadius(screen.width / 6 * 0.2237)
            HStack{
              ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.5)
                .padding()
              VStack(alignment:.leading){
                Text("VULCANの電源を入れてください".budouxed())
                  .font(.title2)
                if(suggestReset){
                  Text("接続できない場合はVULCANのリセットを試してください".budouxed())
                    .font(.title3)
                    .padding(.top, 1)
                }
              }
            }.onAppear{
              suggestReset = false
            }.onDisappear{
              blur = 15.0
            }
            Spacer()
          }else{
            switch mode{
            case .remote:
              Joystick(monitor: joystickMonitor, width: screen.width * 0.9, shape: .circle, active: $active)
                .onAppear(){
                  
                  Timer.scheduledTimer(withTimeInterval: bleDelay, repeats: true){ timer in
                    
                    if(!bleWaiting && active){
                      distance = sqrt(pow(joystickMonitor.xyPoint.x, 2) + pow(joystickMonitor.xyPoint.y, 2)) / (screen.width * 0.9) / (fast ? 1 : 3)
                      angle = joystickMonitor.xyPoint == .zero ? 0 : atan2(joystickMonitor.xyPoint.x, -joystickMonitor.xyPoint.y) * 180.0 / CGFloat.pi
                      let data = """
                        {"distance":\(Int(distance * 1000)),"angle":\(Int(angle)),"active":\(active ? "true" : "false")}
                        """.data(using: .utf8)!
                      bleManager.connectedPeripheral.peripheral.writeValue(data, for: bleManager.connectedCharacteristic.characteristic, type: .withoutResponse)
                      bleWaiting = true
                      DispatchQueue.main.asyncAfter(deadline: .now() + bleDelay){
                        bleWaiting = false
                      }
                    }
                  }
                  
                }
                .onChange(of: joystickMonitor.xyPoint){ _ in
                  if(!active && !errorNoticed){
                    vibrate.notificationOccurred(.error)
                    errorNoticed = true
                    return
                  }
                }
            case .ride:
              Text("angle: \(readAngle), distance: \(readDistance)")
                .onAppear(){
                  Timer.scheduledTimer(withTimeInterval: readDelay, repeats: true){ timer in
                    if(!bleWaiting && mode == .ride){
                      bleManager.connectedPeripheral.peripheral.readValue(for: bleManager.connectedCharacteristic.characteristic)
                      response = String(data: bleManager.connectedCharacteristic.characteristic.value ?? "error".data(using: .utf8)!, encoding: .utf8)!
                      print(response)
                      if(response.split(separator: ",").count > 1){
                        readDistance = (Double(response.split(separator: ",")[0]) ?? 0.0) / 3150
                        readAngle = Double(response.split(separator: ",")[1]) ?? 0.0
                      }
                      bleWaiting = true
                      DispatchQueue.main.asyncAfter(deadline: .now() + bleDelay){
                        bleWaiting = false
                      }
                    }
                  }
                }
              ZStack{
                ZStack{
                  if(active){
                    Image(systemName: "arrow.clockwise.circle.fill")
                      .resizable()
                      .symbolRenderingMode(.palette)
                      .foregroundStyle(.white, .blue)
                      .opacity(sigmoidRange(value: readAngle, center: 90, range: 30))
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                      .resizable()
                      .symbolRenderingMode(.palette)
                      .foregroundStyle(.white, .blue)
                      .opacity(sigmoidRange(value: readAngle, center: -90, range: 30))
                    Image(systemName: "chevron.up.circle.fill")
                      .resizable()
                      .symbolRenderingMode(.palette)
                      .foregroundStyle(.white, .blue)
                      .opacity(sigmoidRange(value: readAngle, center: 0, range: 60) + sigmoidRange(value: abs(readAngle), center: 180, range: 60))
                    Image(systemName: "stop.circle.fill")
                      .resizable()
                      .symbolRenderingMode(.palette)
                      .foregroundStyle(.white, .blue)
                      .opacity(sigmoid(value: readDistance, center: 0.3))
                  }else{
                    Image(systemName: "stop.circle.fill")
                      .resizable()
                      .symbolRenderingMode(.palette)
                      .foregroundStyle(.white, .red)
                  }
                }
                .saturation(readDistance)
                .rotationEffect(Angle(degrees:
                                        active && readDistance > 0.3
                                      ?60 <= abs(readAngle) && abs(readAngle) <= 120
                                      ?readAngle > 0
                                      ?90
                                      :-90
                                      :readAngle
                                      :0
                                     ))
                .animation(abs(readAngle) < 150 ? .easeOut(duration: 0.25) : .none, value: readAngle)
                .scaledToFit()
                .scaleEffect(0.25)
                .offset(x: sin(readAngle / 180 * Double(CGFloat.pi)) * readDistance * 185, y: cos(readAngle / 180 * Double(CGFloat.pi)) * readDistance * -185)
                .animation(.easeInOut(duration: readDelay), value: readDistance)
                RadialGradient(gradient: Gradient(colors: [.blue.opacity(0),.blue.opacity(0.2),.blue.opacity(0.5)]), center: .center, startRadius: 0, endRadius: 200)
                  .clipShape(Circle())
              }
              .padding()
//                .background(
//                  RadialGradient(gradient: Gradient(colors: )))
              
//                ,center: .center,startRadius: 0, endRadius: self.dragDiameter / 2)
//                .clipShape(Circle())
              Button("キャリブレーションを行う".budouxed(), action: {
                let data = """
                      {"action":"calibrate"}
                      """.data(using: .utf8)!
                bleManager.connectedPeripheral.peripheral.writeValue(data, for: bleManager.connectedCharacteristic.characteristic, type: .withoutResponse)
                bleWaiting = true
                DispatchQueue.main.asyncAfter(deadline: .now() + bleDelay){
                  bleWaiting = false
                }
              })
              .font(.title2)
              .padding()
              .foregroundColor(.primary)
              .buttonStyle(.bordered)
            case .direct:
              HStack{
                Spacer()
                VStack{
                  Slider(value: $rightPower, in: -1 ... 1)
                    .tint(.blue)
                    .rotationEffect(.degrees(-90))
                    .frame(width: screen.width * 0.9)
                    .frame(width: 20, height: screen.width * 0.9)
                    .padding()
                  Text("\(Int(rightPower * 100))%")
                }
                Spacer()
                VStack{
                  Slider(value: $leftPower, in: -1 ... 1)
                    .tint(.blue)
                    .rotationEffect(.degrees(-90))
                    .frame(width: screen.width * 0.9)
                    .frame(width: 20, height: screen.width * 0.9)
                    .padding()
                  Text("\(Int(leftPower * 100))%")
                }
                Spacer()
              }
            }
            Spacer()
            
            Image(systemName: "power.circle.fill")
              .font(.largeTitle)
              .symbolRenderingMode(.palette)
              .foregroundStyle(.white, active ? .blue : .gray)
              .onTapGesture {
                active.toggle()
                let data = """
                          {"active":\(active ? "true" : "false")}
                          """.data(using: .utf8)!
                bleManager.connectedPeripheral.peripheral.writeValue(data, for: bleManager.connectedCharacteristic.characteristic, type: .withoutResponse)
                bleWaiting = true
                DispatchQueue.main.asyncAfter(deadline: .now() + bleDelay){
                  bleWaiting = false
                }
              }
            HStack{
              if(mode == .remote){
                Spacer()
                HStack{
                  Image(systemName: "tortoise.fill")
                    .symbolRenderingMode(!fast ? .palette : .monochrome)
                    .foregroundStyle(!fast ? .yellow : .primary, .green)
                  Toggle("", isOn: $fast)
                    .labelsHidden()
                    .padding()
                  Image(systemName: "hare.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(fast ? Color(red: 1, green: 0.7098, blue: 0.9412) : .primary)
                }
                Spacer()
                Divider()
                  .blendMode(.difference)
                  .frame(height: 50)
              }
              Spacer()
              HStack{
                Image(systemName: "video.slash.fill")
                  .symbolRenderingMode(.monochrome)
                Toggle("", isOn: $video)
                  .labelsHidden()
                  .padding()
                  .onChange(of: video){ _ in
                    blur = video ? 0.0 : 15.0
                  }
                Image(systemName: "video.fill")
                  .symbolRenderingMode(.monochrome)
              }
              Spacer()
            }
            Spacer()
            Picker(selection: $mode, label: Text("モード選択"), content: {
              Text("リモートモード").tag(driveMode.remote)
              Text("ライドモード").tag(driveMode.ride)
              Text("ダイレクトモード").tag(driveMode.direct)
            })
            .onChange(of: mode){ _ in
              active = false
              let data = """
                    {"mode":\(mode.rawValue),"active":"false"}
                    """.data(using: .utf8)!
              bleManager.connectedPeripheral.peripheral.writeValue(data, for: bleManager.connectedCharacteristic.characteristic, type: .withoutResponse)
              print(mode.rawValue)
              DispatchQueue.main.asyncAfter(deadline: .now() + bleDelay){
                bleManager.connectedPeripheral.peripheral.writeValue(data, for: bleManager.connectedCharacteristic.characteristic, type: .withoutResponse)
              }
            }
            .padding()
            .pickerStyle(SegmentedPickerStyle())
          }
        }
        Button("接続設定", action: {
          showScanDevice = true
        })
        .padding()
        .foregroundColor(.primary)
        .buttonStyle(.bordered)
      }
    }
    .sheet(isPresented: $showScanDevice) {
      NavigationView{
        ScanDevice()
          .toolbar{
            ToolbarItem(placement: .principal){
              Text("接続設定")
                .fontWeight(.semibold)
            }
            ToolbarItem(placement: .primaryAction){
              Button(action: {showScanDevice = false}){
                Text("完了")
                  .foregroundColor(.blue)
                  .fontWeight(.semibold)
              }
            }
          }
      }
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
    Group{
      HomeView()
        .environmentObject(CoreBluetoothViewModel())
        .previewDevice("iPhone 11 Pro Max")
      HomeView()
        .environmentObject(CoreBluetoothViewModel())
        .previewDevice("iPhone 8 Plus")
    }
  }
}
