//
//  CoreBluetoothViewModel.swift
//  SwiftUI-BLE-Project
//
//  Created by kazuya ito on 2021/02/02.
//

import SwiftUI
import CoreBluetooth

class CoreBluetoothViewModel: NSObject, ObservableObject, CBPeripheralProtocolDelegate, CBCentralManagerProtocolDelegate {
  
  @Published var isBlePower: Bool = false
  @Published var isSearching: Bool = false
  @Published var isConnected: Bool = false
  
  @Published var foundPeripherals: [Peripheral] = []
  @Published var foundServices: [Service] = []
  @Published var foundCharacteristics: [Characteristic] = []
  @Published var targetServiceFound = false
  @Published var targetCharacteristicFound = false
  
  @Published var targetServiceUUID = CBUUID(string: "2ba23aa3-f921-451e-a54b-e3093e5e3112")
  @Published var targetCharacteristicUUID = CBUUID(string: "f46a5236-5e85-4933-b171-48b7461722c3")
  
  #if !os(watchOS)
  private var centralManager: CBCentralManagerProtocol!
  #endif
  @Published var connectedPeripheral: Peripheral!
  @Published var connectedCharacteristic: Characteristic!
  @Published var connectedService: Service!
  
  @Published var written = false
  
  @Published var response = ""
  
  private let serviceUUID: CBUUID = CBUUID()
  
  override init() {
    super.init()
    #if !os(watchOS)
#if targetEnvironment(simulator)
    centralManager = CBCentralManagerMock(delegate: self, queue: nil)
#else
    centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
#endif
    #endif
    
  }
  
  private func resetConfigure() {
    withAnimation {
      isSearching = false
      isConnected = false
      
      foundPeripherals = []
      foundServices = []
      foundCharacteristics = []
    }
  }
  
  //Control Func
  func startScan() {
    let scanOption = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
    centralManager?.scanForPeripherals(withServices: [targetServiceUUID], options: scanOption)
    print("# Start Scan")
    isSearching = true
  }
  
  func stopScan(){
    disconnectPeripheral()
    centralManager?.stopScan()
    print("# Stop Scan")
    isSearching = false
  }
  
  func connectPeripheral(_ selectPeripheral: Peripheral?) {
    guard let connectPeripheral = selectPeripheral else { return }
    connectedPeripheral = selectPeripheral
    centralManager.connect(connectPeripheral.peripheral, options: nil)
  }
  
  func disconnectPeripheral() {
    guard let connectedPeripheral = connectedPeripheral else { return }
    centralManager.cancelPeripheralConnection(connectedPeripheral.peripheral)
  }
  
  //MARK: CoreBluetooth CentralManager Delegete Func
  func didUpdateState(_ central: CBCentralManagerProtocol) {
    if central.state == .poweredOn {
      startScan()
      isBlePower = true
    } else {
      startScan()
      isBlePower = false
    }
  }
  
  func didDiscover(_ central: CBCentralManagerProtocol, peripheral: CBPeripheralProtocol, advertisementData: [String : Any], rssi: NSNumber) {
    if rssi.intValue >= 0 { return }
    
    let peripheralName = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? nil
    var _name = "NoName"
    
    if peripheralName != nil {
      _name = String(peripheralName!)
    } else if peripheral.name != nil {
      _name = String(peripheral.name!)
    }
    
    let foundPeripheral: Peripheral = Peripheral(_peripheral: peripheral,
                                                 _name: _name,
                                                 _advData: advertisementData,
                                                 _rssi: rssi,
                                                 _discoverCount: 0)
    
    if let index = foundPeripherals.firstIndex(where: { $0.peripheral.identifier.uuidString == peripheral.identifier.uuidString }) {
      if foundPeripherals[index].discoverCount % 50 == 0 {
        foundPeripherals[index].name = _name
        foundPeripherals[index].rssi = rssi.intValue
        foundPeripherals[index].discoverCount += 1
      } else {
        foundPeripherals[index].discoverCount += 1
      }
    } else {
      foundPeripherals.append(foundPeripheral)
      DispatchQueue.main.async { self.isSearching = false }
    }
    
    connectPeripheral(foundPeripheral)
    targetServiceFound = true
  }
  
  func didConnect(_ central: CBCentralManagerProtocol, peripheral: CBPeripheralProtocol) {
    guard let connectedPeripheral = connectedPeripheral else { return }
    isConnected = true
    connectedPeripheral.peripheral.delegate = self
    connectedPeripheral.peripheral.discoverServices(nil)
  }
  
  func didFailToConnect(_ central: CBCentralManagerProtocol, peripheral: CBPeripheralProtocol, error: Error?) {
    disconnectPeripheral()
  }
  
  func didDisconnect(_ central: CBCentralManagerProtocol, peripheral: CBPeripheralProtocol, error: Error?) {
    print("disconnect")
    resetConfigure()
  }
  
  func connectionEventDidOccur(_ central: CBCentralManagerProtocol, event: CBConnectionEvent, peripheral: CBPeripheralProtocol) {
    
  }
  
  func willRestoreState(_ central: CBCentralManagerProtocol, dict: [String : Any]) {
    
  }
  
  func didUpdateANCSAuthorization(_ central: CBCentralManagerProtocol, peripheral: CBPeripheralProtocol) {
    
  }
  
  //MARK: CoreBluetooth Peripheral Delegate Func
  func didDiscoverServices(_ peripheral: CBPeripheralProtocol, error: Error?) {
    peripheral.services?.forEach { service in
      let setService = Service(_uuid: service.uuid, _service: service)
      
      foundServices.append(setService)
      connectedService = setService
      peripheral.discoverCharacteristics(nil, for: service)
    }
  }
  
  func didDiscoverCharacteristics(_ peripheral: CBPeripheralProtocol, service: CBService, error: Error?) {
    service.characteristics?.forEach { characteristic in
      let setCharacteristic: Characteristic = Characteristic(_characteristic: characteristic,
                                                             _description: "",
                                                             _uuid: characteristic.uuid,
                                                             _readValue: "",
                                                             _service: characteristic.service!)
      foundCharacteristics.append(setCharacteristic)
      connectedCharacteristic = setCharacteristic
      
      guard setCharacteristic.uuid == targetCharacteristicUUID else { return }
      connectedCharacteristic = setCharacteristic
      if connectedCharacteristic.characteristic.isNotifying {
        //              print("キャラクタリスティックの通知が開始されている")
      } else {
        //              print("キャラクタリスティックの通知が止まっています。接続をキャンセルします。")
        //                centralManager.cancelPeripheralConnection(connectedPeripheral.peripheral)
      }
      //            connectedPeripheral.peripheral.readValue(for: connectedCharacteristic.characteristic)
    }
  }
  
  func didUpdateValue(_ peripheral: CBPeripheralProtocol, characteristic: CBCharacteristic, error: Error?) {
    guard let characteristicValue = characteristic.value else { return }
    
    response = String(data: characteristic.value ?? "error".data(using: .utf8)!, encoding: .utf8)!
    
    if let index = foundCharacteristics.firstIndex(where: { $0.uuid.uuidString == characteristic.uuid.uuidString }) {
      
      foundCharacteristics[index].readValue = characteristicValue.map({ String(format:"%02x", $0) }).joined()
    }
  }
  
  func didWriteValue(_ peripheral: CBPeripheralProtocol, descriptor: CBDescriptor, error: Error?) {
    print("sent")
  }
}
