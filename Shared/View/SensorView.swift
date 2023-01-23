//
//  SensorView.swift
//  VULCAN-Remote-Project
//
//  Created by HIBIKI CUBE on 2022/06/13.
//

import SwiftUI


public struct SensorView: View {

  @Binding private var active: Bool
  @Binding private var distance: Double
  @Binding private var angle: Double
  @Binding private var countdownSeconds: Int
  @Binding private var counting: Bool
  private let width: CGFloat
  private let readDelay = 0.03
  
  public init(width: CGFloat, active: Binding<Bool> = .constant(true), distance: Binding<Double> = .constant(0), angle: Binding<Double> = .constant(0), countdownSeconds: Binding<Int> = .constant(3), counting: Binding<Bool> = .constant(false)) {
    self.width = width
    self._active = active
    self._distance = distance
    self._angle = angle
    self._countdownSeconds = countdownSeconds
    self._counting = counting
  }
  
  private func sigmoidRange(value: Double, center: Double, range: Double, strength: Double = 2.5) -> Double{
    let e = 2.71828182845904523536028747135266249776
    return (1/(1+pow(e, -strength * (value - center + range)))) * (1/(1+pow(e, strength * (value - center - range))))
  }
  
  private func sigmoid(value: Double, center: Double, strength: Double = -100.0) -> Double{
    let e = 2.71828182845904523536028747135266249776
    return 1/(1+pow(e, -strength * (value - center)))
  }
  
  func countdown(_ seconds: Int, closure: @escaping () -> Void){
    if(!counting){
      countdownSeconds = seconds
      counting = true
      Timer.scheduledTimer(withTimeInterval: 1, repeats: true){timer in
        countdownSeconds -= 1
        if(countdownSeconds <= 0 || !counting){
          closure()
          timer.invalidate()
          counting = false
        }
      }
    }
  }

public var body: some View {
  VStack{
    ZStack{
      RadialGradient(gradient: Gradient(colors: [.blue.opacity(0),.blue.opacity(0.2),.blue.opacity(0.5)]), center: .center, startRadius: 0, endRadius: 200)
        .clipShape(Circle())
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
            .opacity(sigmoid(value: distance, center: 0.05))
        }else{
          Image(systemName: "multiply.circle.fill")
            .resizable()
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .red)
        }
      }
      .saturation(distance)
      .rotationEffect(Angle(degrees:
                              active && distance > 0.05
                            ?60 <= abs(angle) && abs(angle) <= 120
                            ?angle > 0
                            ?90
                            :-90
                            :angle
                            :0
                           ))
      .animation(abs(angle) < 150 ? .easeOut(duration: 0.25) : .none, value: angle)
      .animation(.easeInOut(duration: readDelay), value: distance)
      .scaledToFit()
      .scaleEffect(0.25)
      .offset(x: sin(angle / 180 * Double(CGFloat.pi)) * distance * 185, y: cos(angle / 180 * Double(CGFloat.pi)) * distance * -185)
      Text("\(countdownSeconds)")
        .font(.system(size: 200, weight: .bold))
        .opacity(counting ? 0.7 : 0)
        .animation(.default, value: counting)
    }
    .frame(width: width)
  }
}
}

struct SensorView_Previews: PreviewProvider {
  static var previews: some View {
    SensorView(width: 400)
  }
}
