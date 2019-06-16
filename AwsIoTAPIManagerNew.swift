//
//  AwsIoTAPIManager.swift
//  IotProject
//
//  Created by 黄海 on 2016/08/03.
//  Copyright © 2016年 黄海. All rights reserved.
//

import Foundation
import Moscapsule

open class AwsIoTAPIManager {
    // SINGLETON
    open static let sharedInstance : AwsIoTAPIManager = AwsIoTAPIManager()
    
    let SEND_DATA_CNT = 30
    var getDLFlg: Bool = false
    
    var loginFlg: Bool = false
    var mqttClientPub: MQTTClient?
//    var mqttClientSub: MQTTClient?
    var serviceOpenID: String? = nil
    var organization: String? = nil
    weak var processDataManager = ProcessDataManager.sharedInstance
    
    fileprivate init() {
    }
    
    fileprivate func onMessageCallback(_ action: String, data: JSON) {  // data: JSON
//        print("MQTT Callback: " + action)
        switch action {
        case "getLastDataDate":
            print("onMessageCallback：日付フラグを取得しました。")
            if getDLFlg == true {
                getDLFlg = false
            } else {
                return
            }
            getLastDataDateHandle!(data)
        case "getGlucoseData":
            getGlucoseDataHandle!(data)
//        case "groupGetOrgStaffList":
//            groupGetOrgStaffListHandle!(data)
//        case "groupGetFollowedList":
//            groupGetFollowedListHandle!(data)
        default:
            print(action + "という処理が存在していない")
        }
    }
    
    // １回しか実行できない
    func Initialize() {
        moscapsule_init()
    }
    
    // AWSにログインする(connectionを作成)
    func login(_ userId: String, completionHandler: @escaping (Bool) -> Void) {
        self.close()
        
        serviceOpenID = userId
        
//        let dateFormatter = DateFormatter()
//        dateFormatter.locale = Locale(identifier: "ja_JP")
//        dateFormatter.dateFormat = "HHmmss"
//        let labelTime = dateFormatter.string(from: Date())
        
        var clientID = "pub" + serviceOpenID! // + labelTime
        if clientID.characters.count > 128 {
            let startIndex = clientID.characters.count - 128
            clientID = (clientID as NSString).substring( from: startIndex )
        }
        
//        moscapsule_init()
        let mqttConfigPub = MQTTConfig(clientId: clientID,
                                       host: "ai2h0g49m426.iot.ap-northeast-1.amazonaws.com", port: 8883, keepAlive: 600)
        let certFile = Bundle.main.path(forResource: "5c9322656f-certificate.pem", ofType: "crt")
        let keyFile = Bundle.main.path(forResource: "5c9322656f-private.pem", ofType: "key")
        let caFile = Bundle.main.path(forResource: "ca", ofType: "pem")
        
        mqttConfigPub.mqttServerCert = MQTTServerCert(cafile: caFile, capath: nil)
        mqttConfigPub.mqttClientCert = MQTTClientCert(certfile: certFile!, keyfile: keyFile!, keyfile_passwd: nil)
        
        mqttConfigPub.onConnectCallback = { [weak self] (returnCode: ReturnCode) in
            print("戻り値：connected (returnCode=\(returnCode)")
            if returnCode == .success {
                self?.loginFlg = true
                completionHandler(true)
            } else {
                print("  Publish failed.")
                completionHandler(false)
            }
        }
        
        mqttConfigPub.onPublishCallback = { (messageId : Int) in
//            print("戻り値：publish end messageId:"+String(messageId))
        }

        mqttConfigPub.onSubscribeCallback = { (messageId, grantedQos) in
//            print("戻り値：subscribed (mid=\(messageId),grantedQos=\(grantedQos))")
        }
        
        mqttConfigPub.onMessageCallback = { [weak self] mqttMessage in
            print("戻り値：message is callbacked")
            let json = JSON.parse(mqttMessage.payloadString!)
            let actionType = json["actionType"].asString!
            let returnData = json["data"]
            self?.onMessageCallback(actionType, data: returnData)
        }
        
        mqttClientPub = MQTT.newConnection(mqttConfigPub)
//        mqttClientSub = MQTT.newConnection(mqttConfigSub, connectImmediately : false)

    }
    
    func close() {
        if loginFlg {
            loginFlg = false
//            mqttClientSub?.disconnect()
            mqttClientPub?.disconnect()
        }
    }
    
    // 業務メソッド
    fileprivate var getGlucoseDataHandle: ((JSON) -> Void)? = nil
    func getGlucoseData(_ fromDay: String, toDay: String, updDay: String, completionHandler: @escaping (JSON) -> Void) {
        if !loginFlg || !(mqttClientPub!.isConnected) {
//        if !loginFlg {
            login(processDataManager!.serviceOpenID!, completionHandler: { [weak self]
                    flg in
                    if !flg {
                        completionHandler(JSON([]))
                        return
                    } else {
                        self?.getGlucoseData(fromDay, toDay: toDay, updDay: updDay, completionHandler: completionHandler)
                    }
                })
            return
        }
        getGlucoseDataHandle = completionHandler
        var awsQuery:[String:Any] = [
            "user_id" : serviceOpenID! as Any,
            "actionType": "getGlucoseData" as Any
        ]
        if !fromDay.isEmpty {
            awsQuery["from_day"] = fromDay
        }
        if !toDay.isEmpty {
            awsQuery["to_day"] = toDay
        }
        if !updDay.isEmpty {
            awsQuery["update_date"] = updDay
        }
        let strQuery = JSON(awsQuery).toString()
        let awstopic = (serviceOpenID!.lengthOfBytes(using: .utf8) > SystemConstants.AWS_TOPIC_LEN) ?
            (serviceOpenID! as NSString).substring(to: SystemConstants.AWS_TOPIC_LEN) : serviceOpenID!
        mqttClientPub!.subscribe(SystemConstants.IotIFTopic.IOT_DEV_DATA_RECEIVE.rawValue + awstopic, qos: 1)

        
        let rawData = strQuery.data(using: String.Encoding.utf8)
        mqttClientPub!.publish(rawData!, topic: SystemConstants.IotIFTopic.IOT_DEV_DATA_SEND.rawValue, qos: 1, retain: false)
        
    }
    //  最後同期日付取得
    fileprivate var getLastDataDateHandle: ((JSON) -> Void)? = nil
    func getLastDataDate(_ completionHandler: @escaping (JSON) -> Void) {
        if !loginFlg || !(mqttClientPub!.isConnected) {
//        if !loginFlg {
            login(processDataManager!.serviceOpenID!, completionHandler: { [weak self]
                    flg in
                    if !flg {
                        completionHandler(JSON([]))
                        return
                    } else {
                        self?.getLastDataDate(completionHandler)
                    }
                })
            return
        }
        print("日付フラグを取得します。")
        getLastDataDateHandle = completionHandler
        let awsQuery:[String:Any] = [
            "user_id" : serviceOpenID! as Any,
            "actionType": "getLastDataDate" as Any
        ]
        let strQuery = JSON(awsQuery).toString()
        let awstopic = (serviceOpenID!.lengthOfBytes(using: .utf8) > SystemConstants.AWS_TOPIC_LEN) ?
            (serviceOpenID! as NSString).substring(to: SystemConstants.AWS_TOPIC_LEN) : serviceOpenID!
        mqttClientPub!.subscribe(SystemConstants.IotIFTopic.IOT_DEV_DATA_RECEIVE.rawValue + awstopic, qos: 1)
//        print(SystemConstants.IotIFTopic.IOT_DEV_DATA_RECEIVE.rawValue + serviceOpenID!)
//        mqttClientSub!.subscribe("intasect/service901/#", qos: 1)
        
        let rawData = strQuery.data(using: String.Encoding.utf8)
        getDLFlg = true
        mqttClientPub!.publish(rawData!, topic: SystemConstants.IotIFTopic.IOT_DEV_DATA_SEND.rawValue, qos: 1, retain: false)
    }
    
    //  同期日付フラグ更新
    func updateLastDataDate(_ path: String, dev: String, newDate: String) {
        if !loginFlg {
            return
        }
        
        var sendData: [String:String] = [:]
        
        sendData["user_id"] = serviceOpenID
        sendData["dev"] = dev
        sendData["path"] = path
        sendData["actionType"] = "updateLastDataDate"

        sendData["dateFlg"] = newDate
        let iotRawData = JSON(sendData).toString().data(using: String.Encoding.utf8)
        mqttClientPub!.publish(iotRawData!, topic: SystemConstants.IotIFTopic.IOT_DEV_DATA_SEND.rawValue, qos: 1, retain: false)
    }
    
    //  データAWS同期
    func sendExamData(_ examResultList: [JSON], deleteList:[String], completionHandler: @escaping (Bool) -> Void) {
        if !loginFlg {
            login(processDataManager!.serviceOpenID!, completionHandler: { [weak self]
                    flg in
                    if !flg {
                        return
                    } else {
                        self?.sendExamData(examResultList, deleteList: deleteList, completionHandler: completionHandler)
                    }
                })
            return
        }
        
        if deleteList.count > 0 {
            var sendData: [String:String] = [:]
            let delDay = deleteList.joined(separator: ",")
            sendData["user_id"] = serviceOpenID
            sendData["exam_day"] = delDay
            sendData["exam_data"] = "{}"
            sendData["actionType"] = "updateExamResult"

            let iotRawData = JSON(sendData).toString().data(using: String.Encoding.utf8)
            mqttClientPub!.publish(iotRawData!, topic: SystemConstants.IotIFTopic.IOT_DEV_DATA_SEND.rawValue, qos: 0, retain: false)
        }
        
        for iotDatas:JSON in examResultList {
            var sendData: [String:String] = [:]
            let jsonData = iotDatas.toString()
            sendData["user_id"] = serviceOpenID
            sendData["exam_day"] = iotDatas["examDay"].asString
            sendData["exam_data"] = jsonData
            sendData["actionType"] = "updateExamResult"

            let iotRawData = JSON(sendData).toString().data(using: String.Encoding.utf8)
            mqttClientPub!.publish(iotRawData!, topic: SystemConstants.IotIFTopic.IOT_DEV_DATA_SEND.rawValue, qos: 0, retain: false)
        }
        completionHandler(true)
    }
    
//    private var sendIoTDataHandle: ((String) -> Void)? = nil
    func sendIoTData(_ iotDataList: [JSON], completionHandler: @escaping (Bool) -> Void) {
        if !loginFlg || !(mqttClientPub!.isConnected) {
            login(processDataManager!.serviceOpenID!, completionHandler: { [weak self]
                    flg in
                    if !flg {
                        completionHandler(false)
                        return
                    } else {
                        self?.sendIoTData(iotDataList, completionHandler: completionHandler)
                    }
                })
            return
        }
        
        getLastDataDate({ [weak self]
            json in
            
//            print("Iot Dates: " + json.toString())
            print("getLastDataDate is success.")
            var sendFlg = false
            // 統計データ送信開始日付（デバイス_パス : 送信対象開始日付）
            var sendSumDates:[String : String] = [:]
            // 明細データ送信日付（デバイス_パス : 送信対象日付）
            var sendMeisaiDates:[String : [String:String]] = [:]
            
            // 統計データの送信開始日と明細データの対象日付を設定
            var lstcnt = 1
            for iotDatas:JSON in iotDataList {
    //        sendIoTDataHandle = completionHandler
                let dev = iotDatas["dev"].asString
                let path = iotDatas["path"].asString
                let dev_path = dev! + "_" + path!
                
                // Fitbitにログインしていない場合は、送信しない
                if dev == "Fitbit" && self?.processDataManager!.fitbitManager!.loginFlg == false {
                    continue
                }
                
//                print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " \(lstcnt)件データ処理開始." + dev_path)
                lstcnt += 1
                
                var devKind = dev
            
                var dataDateFlg: String?
                if devKind != "Fitbit" {
                    devKind = "HealthKit"
                }
                var temp_key = ""
                if path! == "speed" {
                    temp_key = (HealthType.ActivityDistance["path"] as! String) + "_" + devKind!
                } else {
                    temp_key = path! + "_" + devKind!
                }
                if let test = json[temp_key].asString {
    //                dataLastDate = (test as NSString).substringToIndex(8)
                    dataDateFlg = test
                } else {
                    let e = json[path! + "_" + devKind!].asError
                    print(e)
                    continue
                }
                
                // AWSからの送信フラグを取得する
                var dateFlg: String = ""    // local日更新フラグ
                var sinceDay: String = ""
//                let kind = (dev == "Fitbit") ? dev : "HealthKit"
                if dataDateFlg!.characters.count <= 10 {
                    dateFlg = self!.processDataManager!.localData!.getInitDateFlg(devKind!)
                    if devKind == dev {
                        sinceDay = self!.processDataManager!.localData!.memberSinceFitbit!
                    } else {
                        sinceDay = self!.processDataManager!.localData!.memberSinceHealthKit!
                    }
                } else {
                    let ary = dataDateFlg?.components(separatedBy: ",")
                    if ary == nil || ary?.count != 2 {
                        print("AWSのIotUserデータ不正: \(dataDateFlg)")
                        completionHandler(false)
                        return
                    }
                    sinceDay = ary![0]
                    // HealthKitの場合
                    if devKind != dev {
                        if self?.processDataManager!.localData!.memberSinceHealthKit != nil {
                            // サーバーの開始日はローカルのと一致の場合
                            if sinceDay == self?.processDataManager!.localData!.memberSinceHealthKit! {
                                dateFlg = ary![1]
                            } else {
                                sinceDay = self!.processDataManager!.localData!.memberSinceHealthKit!
                                dateFlg = self!.processDataManager!.localData!.getInitDateFlg(devKind!)
                            }
                        }
                    } else {
//                        sinceDay = ary![0]
                        dateFlg = ary![1]
                    }
                }
                // 送信対象日を確定する
                let objResults = self!.processDataManager!.getTransDataDates(devKind!, procPath: path!, awsDateFlg: dateFlg)
                if objResults.count < 2 {
                    continue
                }
                // 値ありの日付を洗い出す
                sendMeisaiDates[dev_path] = [:]
                if let meisaiResults = objResults["meisai"] {
                    for (day,val) in meisaiResults {
                        if iotDatas["data"][day].asString != nil {
                            sendMeisaiDates[dev_path]![day] = val
                        }
                    }
                }
//                sendMeisaiDates[dev_path] = objResults["meisai"]!
                
                let objSumDate = objResults["sumary"]!
//                var skey = dev! + "_" + path!
                // 統計データ開始日
                var sendSumStartDate = ""
                for (k,_) in objSumDate {
                    sendSumStartDate = k
                    break
                }
                sendSumDates[dev_path] = sendSumStartDate
            }
            // AUTOモードの送信対象日付を作成(各デバイスの一番小さい日付)
            for (k,v) in sendSumDates {
                let sarr = k.components(separatedBy: "_")
                if sarr.count == 2 {
                    let new_key = "AUTO_" + sarr[1]
//                    if objDays[new_key] == nil {
//                        objDays[new_key] = [:]
//                    }
//                    for (k2,_) in ds {
//                        objDays[new_key]![k2] = "0"
//                    }
                    if sendSumDates[new_key] == nil {
                        sendSumDates[new_key] = v
                    } else {
                        if sendSumDates[new_key]! > v {
                            sendSumDates[new_key] = v
                        }
                    }
                }
            }
            
            // 統計データ送信
            for iotDatas:JSON in iotDataList {
                var sendData: [String:String] = [:]
                
                sendData["user_id"] = self?.serviceOpenID
                sendData["dev"] = iotDatas["dev"].asString
                sendData["path"] = iotDatas["path"].asString
                sendData["actionType"] = "updateUserSumData"

//                    if sendData["dev"] == "Fitbit" {
//                        print("Fitbit found");
//                    }

//                    sendData["iot_data"] = iotDatas["data"].toString()
                // 統計送信データ生成
                let skey = sendData["dev"]! + "_" + sendData["path"]!
                var startDay = ""
                if self!.processDataManager!.initSendMinCheckDate == "" {
                    if sendSumDates[skey] != nil {
                        startDay = sendSumDates[skey]!
                    } else {
                        startDay = CommUtil.date2string(Date(),format: "yyyy-MM-dd")!;
                    }
                } else {
                    if sendSumDates[skey] != nil && sendSumDates[skey]! < self!.processDataManager!.initSendMinCheckDate {
//                        if objDays[skey]! < self!.processDataManager!.initSendMinCheckDate {
                        startDay = sendSumDates[skey]!
                    } else {
                        startDay = self!.processDataManager!.initSendMinCheckDate
                    }
                }
//                    let jsonObjs = JSON(string: iotDatas["data"].toString())
                var datas: [String:AnyObject] = [:]
                if startDay != nil {
                    for (k,v) in iotDatas["data"] {
                        let day = k as! String
                        if day < startDay {
                            continue
                        } else {
                            datas[day] = v
                        }
                    }
                }
//                    if datas.count == 0 {
//                        continue
//                    }
                
                sendData["start_day"] = startDay
                
                sendData["iot_data"] = JSON(datas).toString()
                
//                    if sendData["iot_data"] != "{}" {
                let iotRawData = JSON(sendData).toString().data(using: String.Encoding.utf8)

                self?.mqttClientPub!.publish(iotRawData!, topic: SystemConstants.IotIFTopic.IOT_DEV_DATA_SEND.rawValue, qos: 0, retain: false)
//                    print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 送信統計データ: " + skey + ", " + sendData["iot_data"]!)
                usleep(300);

            }
//                self!.close()
            
            if self!.processDataManager!.initSendMinCheckDate != "" {
                self!.processDataManager!.initSendMinCheckDate = ""
            }
            
            // 明細データ送信
            self!.sendIoTMesaiData(sendMeisaiDates, json: json, completionHandler: { [weak self]
                    sendFlg in
                
                    completionHandler(sendFlg)
                })
            
        })
    }
    
    fileprivate func sendIoTMesaiData(_ meisaiDatas: [String: [String: String]], json: JSON,
        completionHandler: @escaping (Bool) -> Void) {
        
//            print("Iot Dates: " + json.toString())
        var pathIotDatas:[String: [String: [String: String]]] = [:]
        var sendFlg = false
        
        for (dev_path,iotDatas) in meisaiDatas {
//        sendIoTDataHandle = completionHandler
            let ary = dev_path.components(separatedBy: "_")
            let dev = ary[0]
            let path = ary[1]
            
            // AUTOモードは明細がない
            if dev == "AUTO" {
                continue
            }
            // Fitbitにログインしていない場合は、送信しない
            if dev == "Fitbit" && self.processDataManager!.fitbitManager!.loginFlg == false {
                continue
            }
            
            
            if pathIotDatas[path] == nil {
                pathIotDatas[path] = [:]
            }
            pathIotDatas[path]![dev] = iotDatas
        }
        
        for (path, pathDatas) in pathIotDatas {
            let ret = sendPathMeisaiDatas(path, meisaiDatas: pathDatas, json: json)
            if ret == true {
                sendFlg = true
            }
        }
        
//            sendFlg = sendFlg || (dev == "AUTO")
        completionHandler(sendFlg)
        
    }
    
    // 引数：path、指定pathの送信対象明細（dev: [day:value]）、DateFlg情報(JSON)
    fileprivate func sendPathMeisaiDatas(_ path: String, meisaiDatas: [String: [String: String]], json: JSON) -> Bool {
        
        // dev: ソート後の日付配列
        var devDays: [String: [String]] = [:]
        for (dev,meisaiData) in meisaiDatas {
            if meisaiData.count == 0 {
//                    completionHandler(false)
//                    return
                continue
            }
            let meisaiArray: [String] = Array(meisaiData.keys).sorted()
            devDays[dev] = meisaiArray
        }

        var fbObjDays: [[String]] = []
        var hkObjDays: [[String]] = []
        var minHKDate = ""
        // Fitbitの段階送信対象日付設定
        for (dev,meisaiArr) in devDays {
            if dev == "Fitbit" {
                for i in 1...3 {
                    var idxStart = 30 * (i - 1)
                    var idxEnd = meisaiArr.count - 1
                    var flg = false
                    if idxEnd > (30 * i) - 1 {
                        idxEnd = (30 * i) - 1
                    } else {
                        flg = true
                    }
                    
                    fbObjDays.append(Array(meisaiArr[idxStart ..< idxEnd]))
                    if flg == true {
                        break
                    }
                
//                    if meisaiArr.count < (30 * i) {
//                        fbObjDays.append(meisaiArr)
//                    } else {
//                        fbObjDays.append(Array(meisaiArr[0 ..< 30]))
//                    }
                }
            } else {
                continue
            }
        }
        
        // HealthKitの段階送信対象日付設定
        for i in 1...3 {
            for (dev,meisaiArr) in devDays {
                if dev != "Fitbit" {
                
                    var lastDay = ""
                    if meisaiArr.count >= (30 * (i - 1)) && meisaiArr.count < (30 * i) {
                        lastDay = meisaiArr[meisaiArr.count - 1]
                    } else if meisaiArr.count >= (30 * i) {
                        lastDay = meisaiArr[(30 * i) - 1]
                    } else {
                        continue
                    }
                    if minHKDate == "" {
                        minHKDate = lastDay
                    } else if minHKDate > lastDay {
                        minHKDate = lastDay
                    }
                
                }
                
            }
            if minHKDate == "" {
                break
            }
            hkObjDays.append([minHKDate])
            minHKDate = ""
        }
        
        // 段階的に送信
        var tcnt = 1;
        let fbdfArray = getUpdateDateFlg(path, dev: "Fitbit", json: json)
        if fbdfArray.count != 2 {
            return false
        }
        let fbSinceDay = fbdfArray[0]
        var fbDateFlg = fbdfArray[1]
        
        let hkdfArray = getUpdateDateFlg(path, dev: "HealthKit", json: json)
        if hkdfArray.count != 2 {
            return false
        }
        let hkSinceDay = hkdfArray[0]
        var hkDateFlg = hkdfArray[1]
        
        for i in 1...3 {
            // Fitbit
            if i <= fbObjDays.count {
                let sendDates = fbObjDays[i - 1]
                for sendDate in sendDates {
                    self.sendIoTMesaiDataSub(path, dev: "Fitbit", day: sendDate)
                }
                
                if path == HealthType.ActivitySteps["path"] as! String {
                    print("Fitbit steps!")
                }
                
                let newFlg = self.processDataManager!.makeNewAwsDateFlg2(sendDates, kind: "Fitbit", path: path, sinceDay: fbSinceDay, awsDateFlg: fbDateFlg)
                let newDateFlg = fbSinceDay + "," + newFlg

                updateLastDataDate(path, dev: "Fitbit", newDate: newDateFlg)
//                print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 日付フラグ更新\(tcnt)：\(path),\("Fitbit"), \(newDateFlg)")
                fbDateFlg = newFlg
            }
            
            
            // HealthKit
            if hkObjDays.count < i {
                continue
            }
            let limitDay = hkObjDays[i - 1][0]
            var lmtStartDay = "2014-12-31"
            var lmtEndDay = "2999-12-31"
            if i == 1 {
                lmtEndDay = limitDay
            } else if i <= 3 {
                lmtStartDay = hkObjDays[i - 2][0]
                lmtEndDay = limitDay
                
            } else {
                lmtStartDay = limitDay
            }
            for (dev,meisaiArr) in devDays {
                if dev == "Fitbit" {
                    continue
                }
                for j in 0..<(meisaiArr.count - 1) {
                    let day = meisaiArr[j]
                    if day >= lmtStartDay && day < lmtEndDay  {
                        self.sendIoTMesaiDataSub(path, dev: dev, day: day)
                    }
                }
            }
            
            let newFlg2 = self.processDataManager!.makeNewAwsDateFlg2([limitDay], kind: "HealthKit", path: path, sinceDay: hkSinceDay, awsDateFlg: hkDateFlg)
            let newDateFlg = hkSinceDay + "," + newFlg2
        
            updateLastDataDate(path, dev: "HealthKit", newDate: newDateFlg)
//            print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 日付フラグ更新\(tcnt)：\(path),\("HealthKit"), \(newDateFlg)")
            hkDateFlg = newFlg2
            
            tcnt += 1
        }
        return true
    }

    fileprivate func sendIoTMesaiDataSub(_ path: String, dev: String, day: String) {
        // 明細データ送信
        var sendDataDate: [String:String] = [:]
        
        let mdata = self.processDataManager!.getDayMeisaiData(path, dev: dev, day: day)
        // 明細未取得のデータを送信対象外とする
        if mdata.allKeys.count == 0 {
            return
        }
        
        sendDataDate["user_id"] = self.serviceOpenID
        sendDataDate["dev"] = dev
        sendDataDate["path"] = path
        sendDataDate["actionType"] = "updateUserData"
        sendDataDate["date"] = day
        sendDataDate["iot_data"] = JSON(mdata).toString()

        let iotRawData = JSON(sendDataDate).toString().data(using: String.Encoding.utf8)
        self.mqttClientPub!.publish(iotRawData!, topic: SystemConstants.IotIFTopic.IOT_DEV_DATA_SEND.rawValue, qos: 0, retain: false)
//        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 明細データ送信：" + JSON(sendDataDate).toString())
        usleep(100)
    }

    fileprivate func getUpdateDateFlg(_ path:String, dev:String, json:JSON) -> [String] {
        var devKind = dev
        if devKind != "Fitbit" {
            devKind = "HealthKit"
        }

        var dataDateFlg: String?
        if let test = json[path + "_" + devKind].asString {
//                dataLastDate = (test as NSString).substringToIndex(8)
            dataDateFlg = test
        } else {
            // speedは明細データを送信しない
            let e = json[path + "_" + devKind].asError
//                    print(e)
            return []
        }
        var dateFlg: String = ""    // local日更新フラグ
        var sinceDay: String = ""
//                let kind = (dev == "Fitbit") ? dev : "HealthKit"
        if dataDateFlg!.characters.count <= 10 {
            dateFlg = self.processDataManager!.localData!.getInitDateFlg(devKind)
            if devKind == "Fitbit" {
                sinceDay = self.processDataManager!.localData!.memberSinceFitbit!
            } else {
                sinceDay = self.processDataManager!.localData!.memberSinceHealthKit!
            }
        } else {
            let ary = dataDateFlg?.components(separatedBy: ",")
            if ary == nil || ary?.count != 2 {
                print("AWSのIotUserデータ不正: \(dataDateFlg)")
                return []
            }
            sinceDay = ary![0]
            // HealthKitの場合
            if devKind != dev {
                if self.processDataManager!.localData!.memberSinceHealthKit != nil {
                    // サーバーの開始日はローカルのと一致の場合
                    if sinceDay == self.processDataManager!.localData!.memberSinceHealthKit! {
                        dateFlg = ary![1]
                    } else {
                        sinceDay = self.processDataManager!.localData!.memberSinceHealthKit!
                        dateFlg = self.processDataManager!.localData!.getInitDateFlg(devKind)
                    }
                }
            } else {
//                        sinceDay = ary![0]
                dateFlg = ary![1]
            }
        }
        
        return [sinceDay, dateFlg]
    }
}

