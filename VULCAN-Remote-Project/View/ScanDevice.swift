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
            VStack(alignment: .leading){
                
                if #available(iOS 15.0, *) {
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
                }else{
                    Text("Target Service UUID:")
                    Text(bleManager.targetServiceUUID.uuidString)
                    Text("Target Characteristic UUID:")
                    Text(bleManager.targetCharacteristicUUID.uuidString)
                    Divider()
                    Text("これらの値を編集するにはデバイスをiOS 15以降にアップデートしてください。")
                }
            }
            .padding()
            
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
