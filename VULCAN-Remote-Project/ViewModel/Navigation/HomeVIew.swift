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
import ReplayKit
import Photos
import OrderedCollections

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

func stopRecording() async {
  let name = "VULACN Remote-\(UUID().uuidString).mov"
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
  
  let recorder = RPScreenRecorder.shared()
  try? await recorder.stopRecording(withOutput: url)
  
  try? await PHPhotoLibrary.shared().performChanges({
    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
  })
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
  @State var lidarFront = true
  @State var lidarFrontOpaque = true
  @State var lidarSide = true
  @State var lidarSideOpaque = true
  @State var fast = false
  @State var distance = 0.0
  @State var angle = 0.0
  @State var rightPower = 0.0
  @State var leftPower = 0.0
  @State var errorNoticed = false
  @State var readDistance = 0.0
  @State var readAngle = 0.0
  let recorder = RPScreenRecorder.shared()
  @State var secondsBeforeRecording = 3
  @State var recordingCountdownTimer: Timer?
  @State var message = ""
  let screen = UIScreen.main.bounds
  let vibrate = UINotificationFeedbackGenerator()
  let bleDelay = 0.03
  let readDelay = 0.03
  let testAngle = 90.0
  let testDistance = 1.0
  
  func sendBle(data: String, structSend: Bool = false){
    guard bleManager.isConnected else {
      return
    }
    bleManager.connectedPeripheral.peripheral.writeValue(data.data(using: .utf8)!, for: bleManager.connectedCharacteristic.characteristic, type: .withoutResponse)
    bleWaiting = true
    DispatchQueue.main.asyncAfter(deadline: .now() + bleDelay){
      bleWaiting = false
      structSend ? sendBle(data: data) : nil
    }
  }
  
  func sendFlags(calibrate: Bool = false, reset: Bool = false){
    guard bleManager.isConnected else {
      return
    }
    let flags: OrderedDictionary<String, Bool> = [
      "active": active,
      "remote": mode == .remote,
      "ride": mode == .ride,
      "fast": fast,
      "lidarFront": lidarFront,
      "lidarSide": lidarSide,
      "calibrate": calibrate,
      "reset": reset
    ]
    var data: UInt8 = 0
    flags.enumerated().forEach { (index, flag) in
      data += (flag.value ? 1 : 0) << (flags.count - index - 1)
    }
    sendBle(data: """
    {"f":\(data)}
    """)
  }
  
  func showMessage(message: String, duration: Double = 3.0, remainUntilOverride: Bool = false){
    self.message = message
    if(!remainUntilOverride && self.message == message){
      DispatchQueue.main.asyncAfter(deadline: .now() + duration){
        self.message = ""
      }
    }
  }
  
  var body: some View {
    let backgroundBlurColorTint = (colorScheme == .dark ? 0.25 : 0.8)
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
          if(!bleManager.isConnected && false) {
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
              blur = 30.0
            }.onDisappear{
              blur = video ? 0.0 : 15.0
            }
            Spacer()
          }else{
            switch mode{
            case .remote:
              Joystick(monitor: joystickMonitor, width: screen.width * 0.9, shape: .circle, active: $active)
                .onAppear(){
                  Timer.scheduledTimer(withTimeInterval: bleDelay, repeats: true){ timer in
                    if(active && !bleWaiting && mode == .remote){
                      distance = sqrt(pow(joystickMonitor.xyPoint.x, 2) + pow(joystickMonitor.xyPoint.y, 2)) / (screen.width * 0.9)
                      angle = joystickMonitor.xyPoint == .zero ? 0 : atan2(joystickMonitor.xyPoint.x, -joystickMonitor.xyPoint.y) * 180.0 / CGFloat.pi
                      sendBle(data:"""
                      {"d":\(Int(distance * 1000)),"a":\(Int(angle))}
                      """)
                    }
                  }
                }
                .onChange(of: joystickMonitor.xyPoint){ _ in
                  if(!active && !errorNoticed){
                    vibrate.notificationOccurred(.error)
                    errorNoticed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1){
                      errorNoticed = false
                    }
                    return
                  }
                }
            case .ride:
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
                      .opacity(sigmoid(value: readDistance, center: 0.05))
                  }else{
                    Image(systemName: "stop.circle.fill")
                      .resizable()
                      .symbolRenderingMode(.palette)
                      .foregroundStyle(.white, .red)
                  }
                }
                .saturation(readDistance)
                .rotationEffect(Angle(degrees:
                                        active && readDistance > 0.05
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
              .onReceive(bleManager.$connectedCharacteristic, perform: { _ in
                if(bleManager.connectedCharacteristic != nil){
                  bleManager.connectedPeripheral.peripheral.setNotifyValue(true, for: bleManager.connectedCharacteristic.characteristic)
                }
              })
              .onChange(of: bleManager.response){ _ in
                if(bleManager.response.split(separator: ",").count > 1){
                  readDistance = (Double(bleManager.response.split(separator: ",")[0]) ?? 0.0) / 1500
                  readAngle = Double(bleManager.response.split(separator: ",")[1]) ?? 0.0
                }
              }
              .padding()
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
              }//Direct mode
            } //modes
            Spacer()
            VStack{
              HStack{
                Spacer()
                Text(message)
                  .frame(maxWidth: .infinity, maxHeight: 30)
                  .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.thinMaterial)
                  )
                Spacer()
              }
              .opacity(message != "" ? 1.0 : 0.0)
              .animation(.default, value: message)
              HStack{
                Spacer()
                Toggle(isOn: $lidarFront){
                  Image(systemName: "car.top.radiowaves.front.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(active && lidarFront ? .blue : active ?  .yellow : .gray, lidarFront ? .white : .red)
                    .opacity(lidarFrontOpaque ? 1.0 : 0.2)
                    .frame(width: 50, height: 55)
                }
                .tint(active && lidarFront ? .blue : .gray)
                .toggleStyle(.button)
                .onChange(of: lidarFront) { _ in
                  if(lidarFront){
                    showMessage(message: "前方衝突保護オン")
                  }else{
                    showMessage(message: "前方衝突保護がオフになっています", remainUntilOverride: true)
                  }
                  sendFlags()
                  if(!lidarFront){
                    withAnimation(Animation.easeIn(duration: 0.75).repeatForever(autoreverses: false)){
                      lidarFrontOpaque = false
                    }
                  }else{
                    lidarFrontOpaque = true
                  }
                }
                Spacer()
                Toggle(isOn: $active){
                  if(bleManager.isConnected && bleManager.connectedCharacteristic != nil){
                    Image(systemName: "power.circle.fill")
                      .font(.largeTitle)
                      .symbolRenderingMode(.palette)
                      .foregroundStyle(.white, active ? .blue : .gray)
                      .frame(width: 50, height: 55)
                      .onAppear{
                        showMessage(message: "VULCANに接続しました")
                        sendFlags()
                      }
                  }else{
                    ProgressView()
                      .progressViewStyle(.circular)
                      .scaleEffect(1.5)
                      .frame(width: 50, height: 55)
                      .onAppear{
                        active = false
                        showMessage(message: "VULCANの電源を入れてください", remainUntilOverride: true)
                      }
                  }
                }
                .tint(active ? .blue : .gray)
                .toggleStyle(.button)
                .onChange(of: active) { isActive in
                  sendFlags()
                }
                Spacer()
                Toggle(isOn: $lidarSide){
                  Image(systemName: "car.top.lane.dashed.arrowtriangle.inward.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(lidarSide ? .white : .red, active && lidarSide ? .blue : active ?  .yellow : .gray)
                    .opacity(lidarSideOpaque ? 1.0 : 0.2)
                    .frame(width: 50, height: 55)
                }
                .tint(active && lidarSide ? .blue : .gray)
                .toggleStyle(.button)
                .onChange(of: lidarSide) { _ in
                  if(lidarSide){
                    showMessage(message: "側面衝突保護オン")
                  }else{
                    showMessage(message: "側面衝突保護がオフになっています", remainUntilOverride: true)
                  }
                  sendFlags()
                  if(!lidarSide){
                    withAnimation(Animation.easeIn(duration: 0.75).repeatForever(autoreverses: false)){
                      lidarSideOpaque = false
                    }
                  }else{
                    lidarSideOpaque = true
                  }
                }
                Spacer()
              }
            }
            HStack{
              Spacer()
              ZStack{
                HStack{
                  Image(systemName: "tortoise.fill")
                    .symbolRenderingMode(!fast ? .palette : .monochrome)
                    .foregroundStyle(!fast ? .yellow : .primary, .green)
                  Toggle("", isOn: $fast)
                    .labelsHidden()
                    .padding()
                    .onChange(of: fast){ _ in
                      sendFlags()
                    }
                  Image(systemName: "hare.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(fast ? Color(red: 1, green: 0.7098, blue: 0.9412) : .primary)
                }
                Rectangle()
                  .opacity(0)
              }
              Divider()
                .background(.primary)
              ZStack{
                HStack{
                  Image(systemName: "video.slash.fill")
                    .symbolRenderingMode(.monochrome)
                  Toggle("", isOn: $video)
                    .labelsHidden()
                    .padding()
                    .onChange(of: video){ _ in
                      blur = video ? 0.0 : 15.0
                      if(video){
                        secondsBeforeRecording = 3
                        recordingCountdownTimer =  Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                          secondsBeforeRecording -= 1
                          if(secondsBeforeRecording < 0){
                            recordingCountdownTimer?.invalidate()
                            self.recorder.startRecording()
                          }
                        }
                      }else{
                        if(secondsBeforeRecording < 0){
                          Task{
                            await stopRecording()
                          }
                        }
                      }
                    }
                  Image(systemName: "video.fill")
                    .symbolRenderingMode(.monochrome)
                }//Video toggle
                ZStack{
                  Rectangle()
                    .fill(.red)
                    .opacity(0.5)
                    .cornerRadius(8)
                  Text("\(secondsBeforeRecording)")
                    .font(.title)
                    .padding()
                }//Countdown overlay
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .opacity((video && secondsBeforeRecording > 0) ? 1.0 : 0.0)
                .animation(.default, value: video)
                .animation(.default, value: secondsBeforeRecording)
              }
              .onDisappear{
                recordingCountdownTimer?.invalidate()
              }
              Spacer()
            }
            .fixedSize(horizontal: false, vertical: true)
            Picker(selection: $mode, label: Text("モード選択"), content: {
              Text("リモートモード").tag(driveMode.remote)
              Text("ライドモード").tag(driveMode.ride)
            })
            .onChange(of: mode){ _ in
              sendFlags()
              active = false
            }
            .padding()
            .pickerStyle(SegmentedPickerStyle())
          }
        }
        HStack{
          Button("接続設定", action: {
            showScanDevice = true
          })
          .padding()
          .foregroundColor(.primary)
          .buttonStyle(.bordered)
          if(mode == .ride){
            Button("センサー補正".budouxed(), action: {
              sendFlags(calibrate: true)
            })
            .padding()
            .foregroundColor(.primary)
            .buttonStyle(.bordered)
          }
          if(bleManager.isConnected){
            Button("リセット".budouxed(), action: {
              sendFlags(reset: true)
            })
            .padding()
            .foregroundColor(.primary)
            .buttonStyle(.bordered)
          }
        }
        .animation(.default, value: mode)
        .animation(.default, value: bleManager.isConnected)
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
        .previewDevice("iPhone 14 Pro Max")
      HomeView()
        .environmentObject(CoreBluetoothViewModel())
        .previewDevice("iPhone 12 Pro Max")
      HomeView()
        .previewDevice("iPhone SE (3rd generation)")
        .environmentObject(CoreBluetoothViewModel())
      //        .previewDevice("iPhone 7 Plus")
    }
  }
}
