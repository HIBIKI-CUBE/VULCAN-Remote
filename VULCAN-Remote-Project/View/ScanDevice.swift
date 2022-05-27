//
//  ScanDevice.swift
//  VULCAN-Remote-Project
//
//  Created by HIBIKI CUBE on 2022/05/27.
//

import SwiftUI
import CoreBluetooth

struct ScanDevice: View {
    @EnvironmentObject var bleManager: CoreBluetoothViewModel
    @State var targetServiceUUID = ""
    @State var targetCharacteristicUUID = ""
    
    var body: some View {
        VStack{
            if !bleManager.foundPeripherals.isEmpty{
                List(bleManager.foundPeripherals){ item in
                    Text("\(item.name)")
                }
            }
            if #available(iOS 15.0, *) {
                VStack(alignment: .leading){
                    Text("Target Service UUID:")
                    TextField("Service UUID", text: $targetServiceUUID)
                        .onSubmit {
                            bleManager.targetServiceUUID = CBUUID(string: targetServiceUUID)
                        }
                    Text("Target Characteristic UUID:")
                    TextField("Characteristic UUID", text: $targetCharacteristicUUID)
                        .onSubmit {
                            bleManager.targetCharacteristicUUID = CBUUID(string: targetCharacteristicUUID)
                        }
                }
                .padding()
            }
        }
        .onAppear{
            targetServiceUUID = bleManager.targetServiceUUID.uuidString
            targetCharacteristicUUID = bleManager.targetCharacteristicUUID.uuidString
        }
    }
}

struct ScanDevice_Previews: PreviewProvider {
    static var previews: some View {
        ScanDevice()
    }
}
