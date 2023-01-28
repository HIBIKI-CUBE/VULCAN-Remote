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
  @StateObject var connection = connectivity()
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
  @State var raderAnimation = 1.0
  let raderTimer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
  @State var fast = false
  @State var distance = 0.0
  @State var angle = 0.0
  @State var rightPower = 0.0
  @State var leftPower = 0.0
  @State var errorNoticed = false
  @State var readDistance = 0.0
  @State var readAngle = 0.0
  @State var secondsBeforeCalibration = 3
  @State var calibrating = false
  @State var calibrated = false
  let recorder = RPScreenRecorder.shared()
  @State var secondsBeforeRecording = 3
  @State var recordingCountdownTimer: Timer?
  @State var message = ""
  @State var priorWatch = false
  let screen = UIScreen.main.bounds
  let vibrate = UINotificationFeedbackGenerator()
  let bleDelay = 0.03
  let testAngle = 90.0
  let testDistance = 1.0
  
  func sendBle(data: String, structSend: Bool = false){
    guard bleManager.isConnected && bleManager.connectedCharacteristic != nil else {
      return
    }
    bleManager.connectedPeripheral.peripheral.writeValue(data.data(using: .utf8)!, for: bleManager.connectedCharacteristic.characteristic, type: .withoutResponse)
    bleWaiting = true
    DispatchQueue.main.asyncAfter(deadline: .now() + bleDelay){
      bleWaiting = false
      structSend ? sendBle(data: data) : nil
    }
  }
  
  public func sendFlags(calibrate: Bool = false, reset: Bool = false){
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
    let sensor = SensorView(width: screen.width * 0.9, active: $active, distance: $readDistance, angle: $readAngle, countdownSeconds: $secondsBeforeCalibration, counting: $calibrating)
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
            switch mode{
            case .remote:
              Joystick(monitor: joystickMonitor, width: screen.width * 0.9, shape: .circle, active: $active)
                .onAppear(){
                  Timer.scheduledTimer(withTimeInterval: bleDelay, repeats: true){ timer in
                    if(!bleWaiting && mode == .remote){
                      distance = sqrt(pow(joystickMonitor.xyPoint.x, 2) + pow(joystickMonitor.xyPoint.y, 2)) / (screen.width * 0.9)
                      angle = joystickMonitor.xyPoint == .zero ? 0 : atan2(joystickMonitor.xyPoint.x, -joystickMonitor.xyPoint.y) * 180.0 / CGFloat.pi
                      if(connection.session.isReachable && distance == 0 && angle == 0){
                        distance = connection.distance
                        angle = connection.angle
                      }
                      if(active){
                        sendBle(data:"""
                        {"d":\(Int(distance * 1000)),"a":\(Int(angle))}
                        """)
                      }
                    }
                  }
                  Timer.scheduledTimer(withTimeInterval: 2, repeats: true){ timer in
                    if connection.session.activationState == .notActivated {
                      connection.session.activate()
                    }
                  }
                }
                .onReceive(connection.$active){ active in
                  self.active = active
                  sendFlags()
                }
                .onReceive(connection.$fast){ fast in
                  self.fast = fast
                  sendFlags()
                }
                .onReceive(connection.$lidarFront){ lidarFront in
                  self.lidarFront = lidarFront
                  sendFlags()
                }
                .onReceive(connection.$lidarSide){ lidarSide in
                  self.lidarSide = lidarSide
                  sendFlags()
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
              sensor.body
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
                  Image(systemName: "car.top.radiowaves.front.fill", variableValue: raderAnimation)
                    .animation(.default, value: raderAnimation)
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
                  connection.sendState(state: "lidarFront", value: lidarFront)
                  if(!lidarFront){
                    raderAnimation = 1
                    withAnimation(Animation.easeIn(duration: 0.75).repeatForever(autoreverses: false)){
                      lidarFrontOpaque = false
                    }
                  }else{
                    lidarFrontOpaque = true
                  }
                }
                .onReceive(raderTimer){_ in
                  if(lidarFront){
                    raderAnimation += 0.5
                    if(raderAnimation > 1){
                      raderAnimation = 0
                    }
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
                      .onDisappear{
                        active = false
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
                .disabled(!(bleManager.isConnected && bleManager.connectedCharacteristic != nil))
                .tint(active ? .blue : .gray)
                .toggleStyle(.button)
                .onChange(of: active) { _ in
                  sendFlags()
                  connection.sendState(state: "active", value: active)
                  UIApplication.shared.isIdleTimerDisabled = (mode == .ride && active)
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
                  connection.sendState(state: "lidarSide", value: lidarSide)
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
                      connection.sendState(state: "fast", value: fast)
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
                          if(secondsBeforeRecording <= 0){
                            recordingCountdownTimer?.invalidate()
                            self.recorder.startRecording()
                          }
                        }
                      }else{
                        if(secondsBeforeRecording <= 0){
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
              active = false
              sendFlags()
            }
            .padding()
            .pickerStyle(SegmentedPickerStyle())
        }
        HStack{
          Button(bleManager.isConnected ? "リセット".budouxed() : "接続設定".budouxed(), action: {
            if(bleManager.isConnected){
              sendFlags(reset: true)
            }else{
              showScanDevice = true
            }
          })
          .padding()
          .foregroundColor(.primary)
          .buttonStyle(.bordered)
          Button("重心補正".budouxed(), action: {
            if(bleManager.isConnected && mode == .ride && !calibrating){
              sendFlags(calibrate: true)
              sensor.countdown(3){
                showMessage(message: "重心補正が完了しました")
                calibrated = true
              }
            }else{
              vibrate.notificationOccurred(.error)
              if(!bleManager.isConnected){
                showMessage(message: "VULCANに接続していません")
              }else if(mode != .ride){
                showMessage(message: "ライドモードに切り替えてください")
              }else if(calibrating){
                showMessage(message: "補正中です")
              }
            }
          })
          .padding()
          .foregroundColor(.primary)
          .buttonStyle(.bordered)
        }
        .frame(height: 60)
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
    }
  }
}
