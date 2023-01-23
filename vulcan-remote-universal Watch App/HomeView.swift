//
//  ContentView.swift
//  vulcan-remote-universal Watch App
//
//  Created by HIBIKI CUBE on 2023/01/17.
//

import SwiftUI
import SwiftUIJoystick
import WatchConnectivity

struct HomeView: View {
  @StateObject var joystickMonitor = JoystickMonitor()
  @State var active = false
  @State var fast = false
  @State var lidarFront = true
  @State var lidarFrontOpaque = true
  @State var lidarSide = true
  @State var lidarSideOpaque = true
  @State var sendReady = false
  let screen = WKInterfaceDevice.current().screenBounds
  let bleDelay = 0.03
  let connection = connectivity()
  
  var body: some View {
    NavigationView{
      ScrollView{
        VStack{
          ZStack{
            Joystick(monitor: joystickMonitor, width: screen.width, shape: .circle, active: $active)
              .onAppear{
                Timer.scheduledTimer(withTimeInterval: bleDelay, repeats: true){ timer in
                  if(active){
                    let distance = sqrt(pow(joystickMonitor.xyPoint.x, 2) + pow(joystickMonitor.xyPoint.y, 2)) / (screen.width * 0.9)
                    let angle = joystickMonitor.xyPoint == .zero ? 0 : atan2(joystickMonitor.xyPoint.x, -joystickMonitor.xyPoint.y) * 180.0 / CGFloat.pi
                    connection.sendControl(distance: distance, angle: angle)
                  }
                }
              }
              .onReceive(connection.$active){ active in
                self.active = active
              }
              .onReceive(connection.$fast){ fast in
                self.fast = fast
              }
              .onReceive(connection.$lidarFront){ lidarFront in
                self.lidarFront = lidarFront
              }
              .onReceive(connection.$lidarSide){ lidarSide in
                self.lidarSide = lidarSide
              }
          }
          Spacer(minLength: 20)
          VStack{
            HStack{
              Toggle(isOn: $active, label: {
                Image(systemName: "power.circle.fill")
                  .font(.largeTitle)
                  .symbolRenderingMode(.palette)
                  .foregroundStyle(.white, active ? .blue : .gray)
                  .frame(width: 50, height: 55)
              })
              .onChange(of: active){ _ in
                connection.sendState(state: "active", value: active)
              }
              Toggle(isOn: $fast, label: {
                if(fast){
                  Image(systemName: "hare.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color(red: 1, green: 0.7098, blue: 0.9412))
                    .frame(width: 50, height: 55)
                }else{
                  Image(systemName: "tortoise.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.yellow, .green)
                    .frame(width: 50, height: 55)
                }
              })
              .onChange(of: fast){ _ in
                connection.sendState(state: "fast", value: fast)
              }
            }
            HStack{
              Toggle(isOn: $lidarFront){
                VStack{
                  Image(systemName: "car.top.radiowaves.front.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(active && lidarFront ? .blue : active ?  .yellow : .gray, lidarFront ? .white : .red)
                    .opacity(lidarFrontOpaque ? 1.0 : 0.2)
                    .frame(width: 50, height: 55)
                }
              }
              .onChange(of: lidarFront) { _ in
                connection.sendState(state: "lidarFront", value: lidarFront)
                if(!lidarFront){
                  withAnimation(Animation.easeIn(duration: 0.75).repeatForever(autoreverses: false)){
                    lidarFrontOpaque = false
                  }
                }else{
                  lidarFrontOpaque = true
                }
              }
              Toggle(isOn: $lidarSide){
                VStack{
                  Image(systemName: "car.top.lane.dashed.arrowtriangle.inward.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(lidarSide ? .white : .red, active && lidarSide ? .blue : active ?  .yellow : .gray)
                    .opacity(lidarSideOpaque ? 1.0 : 0.2)
                    .frame(width: 50, height: 55)
                }
              }
              .onChange(of: lidarSide) { _ in
                connection.sendState(state: "lidarSide", value: lidarSide)
                if(!lidarSide){
                  withAnimation(Animation.easeIn(duration: 0.75).repeatForever(autoreverses: false)){
                    lidarSideOpaque = false
                  }
                }else{
                  lidarSideOpaque = true
                }
              }
            }
          }
          .toggleStyle(.button)
        }
      }
      .navigationTitle{
        HStack{
          Image(systemName: "power.circle.fill")
            .scaledToFit()
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, active ? .blue : .gray)
          if(fast){
            Image(systemName: "hare.fill")
              .scaledToFit()
              .symbolRenderingMode(.palette)
              .foregroundStyle(Color(red: 1, green: 0.7098, blue: 0.9412))
          }else{
            Image(systemName: "tortoise.fill")
              .scaledToFit()
              .symbolRenderingMode(.palette)
              .foregroundStyle(.yellow, .green)
          }
          Image(systemName: "car.top.radiowaves.front.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(active && lidarFront ? .blue : active ?  .yellow : .gray, lidarFront ? .white : .red)
            .opacity(lidarFrontOpaque ? 1.0 : 0.2)
          Image(systemName: "car.top.lane.dashed.arrowtriangle.inward.fill")
            .scaledToFit()
            .symbolRenderingMode(.palette)
            .foregroundStyle(lidarSide ? .white : .red, active && lidarSide ? .blue : active ?  .yellow : .gray)
            .opacity(lidarSideOpaque ? 1.0 : 0.2)
          Spacer()
        }
      }
      .frame(alignment: .trailing)
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    Group{
      NavigationView{
        HomeView()
          .previewDevice("Apple Watch Ultra")
      }
      NavigationView{
        HomeView()
          .previewDevice("Apple Watch Series 7 (45mm)")
      }
    }
  }
}
