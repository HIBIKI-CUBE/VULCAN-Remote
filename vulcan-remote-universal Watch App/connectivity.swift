//
//  connectivity.swift
//  vulcan-remote-universal Watch App
//
//  Created by HIBIKI CUBE on 2023/01/17.
//

import WatchConnectivity
import SwiftUI

class connectivity: NSObject, WCSessionDelegate {
  
  public let session: WCSession
  public var waiting = false
  
  @Published var active: Bool = false
  @Published var fast: Bool = false
  @Published var lidarFront: Bool = true
  @Published var lidarSide: Bool = true
  
  init(session: WCSession = .default) {
    self.session = session
    super.init()
    self.session.delegate = self
    session.activate()
  }
  
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    if let error = error {
      print(error.localizedDescription)
    } else {
      print("The session has completed activation.")
    }
  }
  
  func sendState(state: String, value: Bool) {
    guard session.isReachable else {
      return
    }
    let data: [String: Any] = [
      state: value
    ]
    session.sendMessage(data, replyHandler: nil) { (error) in
      print(error.localizedDescription)
    }
  }
  
  func sendControl(distance: Double, angle: Double) {
    guard session.isReachable else {
      return
    }
    let data: [String: Any] = [
      "distance": distance,
      "angle": angle
    ]
    session.sendMessage(data, replyHandler: nil) { (error) in
      print("Watchエラーだよ")
      print(error.localizedDescription)
    }
  }
  
  func session(_ session: WCSession, didReceiveMessage data: [String : Any]) {
    DispatchQueue.main.async {[self] in
      if let active = data["active"] as? Bool {
        self.active = active
      }
      if let fast = data["fast"] as? Bool {
        self.fast = fast
      }
      if let lidarFront = data["lidarFront"] as? Bool {
        self.lidarFront = lidarFront
      }
      if let lidarSide = data["lidarSide"] as? Bool {
        self.lidarSide = lidarSide
      }
    }
  }
}
