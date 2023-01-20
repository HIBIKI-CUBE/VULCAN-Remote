//
//  connectivity.swift
//  vulcan-remote-universal
//
//  Created by HIBIKI CUBE on 2023/01/17.
//

import WatchConnectivity

class connectivity: NSObject, ObservableObject, WCSessionDelegate {
  
  public let session: WCSession
  public var isConnected = false
  public var waiting = false
  
  @Published var active: Bool = false
  @Published var fast: Bool = false
  @Published var lidarFront: Bool = true
  @Published var lidarSide: Bool = true
  @Published var distance: Double = 0
  @Published var angle: Double = 0
  
  init(session: WCSession = .default) {
    self.session = session
    super.init()
    self.session.delegate = self
    session.activate()
  }
  
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    if let error = error {
      print(error.localizedDescription)
      isConnected = false
    } else {
      print("The session has completed activation.")
      isConnected = true
    }
  }
  
  func sessionDidBecomeInactive(_ session: WCSession) { }
  func sessionDidDeactivate(_ session: WCSession) { }
  
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
      if let distance = data["distance"] as? Double {
        self.distance = distance
      }
      if let angle = data["angle"] as? Double {
        self.angle = angle
      }
    }
  }
}
