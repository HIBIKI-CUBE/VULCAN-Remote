//
//  ExampleJoystick.swift
//  SwiftUIJoystick
//
//  Created by Michael Ellis on 12/4/21.
//

//
//  Joystick.swift
//  VULCAN-Remote-Project
//
//  Modified by HIBIKI CUBE on 2022/05/30.
//

import SwiftUI
import SwiftUIJoystick

public struct Joystick: View {
  
  @ObservedObject public var joystickMonitor: JoystickMonitor
  private let dragDiameter: CGFloat
  private let shape: JoystickShape
  @Binding private var active: Bool
  @StateObject private var monitorLocking = JoystickMonitor()
  
  public init(monitor: JoystickMonitor, width: CGFloat, shape: JoystickShape = .rect, active: Binding<Bool> = .constant(true)) {
    self.joystickMonitor = monitor
    self.dragDiameter = width
    self.shape = shape
    self._active = active
  }
  
  func sigmoidRange(value: Double, center: Double, range: Double, strength: Double = 2.5) -> Double{
    let e = 2.71828182845904523536028747135266249776
    return (1/(1+pow(e, -strength * (value - center + range)))) * (1/(1+pow(e, strength * (value - center - range))))
  }
  
  func sigmoid(value: Double, center: Double, strength: Double = -100.0) -> Double{
    let e = 2.71828182845904523536028747135266249776
    return 1/(1+pow(e, -strength * (value - center)))
  }
  
  public var body: some View {
    let angle = self.joystickMonitor.xyPoint == .zero
    ? 0
    : atan2(self.joystickMonitor.xyPoint.x, -self.joystickMonitor.xyPoint.y) * 180.0 / CGFloat.pi
    let distance = sqrt(pow(self.joystickMonitor.xyPoint.x, 2) + pow(self.joystickMonitor.xyPoint.y, 2)) / self.dragDiameter
    VStack{
      JoystickBuilder(
        monitor: self.joystickMonitor,
        width: self.dragDiameter,
        shape: self.shape,
        background: {
          RadialGradient(gradient: Gradient(colors: [
            .white.opacity(0),
            .white.opacity(0.2),
            .white.opacity(0.8)
          ]),center: .center,startRadius: 0, endRadius: self.dragDiameter / 2)
          .clipShape(Circle())
        },
        foreground: {
          ZStack{
            if(active){
              Image(systemName: "arrow.clockwise.circle.fill")
                .resizable()
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .blue)
                .opacity(sigmoidRange(value: angle, center: 90, range: 30))
              Image(systemName: "arrow.counterclockwise.circle.fill")
                .resizable()
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .blue)
                .opacity(sigmoidRange(value: angle, center: -90, range: 30))
              Image(systemName: "chevron.up.circle.fill")
                .resizable()
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .blue)
                .opacity(sigmoidRange(value: angle, center: 0, range: 60) + sigmoidRange(value: abs(angle), center: 180, range: 60))
              Image(systemName: "stop.circle.fill")
                .resizable()
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .blue)
                .opacity(sigmoid(value: distance, center: 0.3))
            }else{
              Image(systemName: "multiply.circle.fill")
                .resizable()
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .red)
            }
          }
          .saturation(distance)
          .rotationEffect(Angle(degrees:
            active && distance > 0.3
            ?60 <= abs(angle) && abs(angle) <= 120
              ?angle > 0
                ?90
                :-90
              :angle
            :0
           ))
          .animation(abs(angle) < 150 ? .easeOut(duration: 0.25) : .none, value: angle)
        },
        locksInPlace: false)
    }
  }
}

struct Joystick_Previews: PreviewProvider {
  
  static var previews: some View {
    Joystick(monitor: JoystickMonitor(), width: 150, shape: .circle)
  }
}

