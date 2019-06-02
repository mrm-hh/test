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
    let SEND_DATA_TOTAL_CNT = 100
    
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
            var sendFlg = false
            // 統計データ送信開始日付（デバイス_パス : 送信対象開始日付）
            var sendSumDates:[String : String] = [:]
            // 明細データ送信日付（デバイス_パス : 送信対象日付）
            var sendMeisaiDates:[String : [String:String]] = [:]
            
            // 統計データの送信開始日と明細データの対象日付を設定
            for iotDatas:JSON in iotDataList {
    //        sendIoTDataHandle = completionHandler
                let dev = iotDatas["dev"].asString
                let path = iotDatas["path"].asString
                let dev_path = dev! + "_" + path!
                
                // Fitbitにログインしていない場合は、送信しない
                if dev == "Fitbit" && self?.processDataManager!.fitbitManager!.loginFlg == false {
                    continue
                }
                
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
                let objResults = self!.processDataManager!.getTransDataDates(devKind!, path: path!, awsDateFlg: dateFlg)
                if objResults.count < 2 {
                    continue
                }
                sendMeisaiDates[dev_path] = objResults["meisai"]!
                
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
                    print("送信統計データ: " + skey + ", " + sendData["iot_data"]!)
                usleep(300);

            }
//                self!.close()
            
            if self!.processDataManager!.initSendMinCheckDate != "" {
                self!.processDataManager!.initSendMinCheckDate = ""
            }
            
            // 明細データ送信
            self!.sendIoTMesaiData(iotDataList, meisaiDatas: sendMeisaiDates, json: json, completionHandler: { [weak self]
                    sendFlg in
                
                    completionHandler(sendFlg)
                })
            
        })
    }
    
    fileprivate func sendIoTMesaiData(_ meisaiDatas: [String: [String: String]], json: JSON,
        completionHandler: @escaping (Bool) -> Void) {
        
//            print("Iot Dates: " + json.toString())
            var sendFlg = false
            var sendCnt = 0
            // HealthKitの場合、path単位のsinceDay〜healthKitMinDayのフラグのみを更新する
            var healthKitMinDay: [String: String] = [:]
        
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
                
                var devKind = dev
                if devKind != "Fitbit" {
                    devKind = "HealthKit"
                }

                var dataDateFlg: String?
                if let test = json[path! + "_" + devKind!].asString {
    //                dataLastDate = (test as NSString).substringToIndex(8)
                    dataDateFlg = test
                } else {
                    // speedは明細データを送信しない
                    let e = json[path! + "_" + devKind!].asError
//                    print(e)
                    continue
                }
                var dateFlg: String = ""    // local日更新フラグ
                var sinceDay: String = ""
//                let kind = (dev == "Fitbit") ? dev : "HealthKit"
                if dataDateFlg!.characters.count <= 10 {
                    dateFlg = self.processDataManager!.localData!.getInitDateFlg(devKind!)
                    if devKind == dev {
                        sinceDay = self.processDataManager!.localData!.memberSinceFitbit!
                    } else {
                        sinceDay = self.processDataManager!.localData!.memberSinceHealthKit!
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
                        if self.processDataManager!.localData!.memberSinceHealthKit != nil {
                            // サーバーの開始日はローカルのと一致の場合
                            if sinceDay == self.processDataManager!.localData!.memberSinceHealthKit! {
                                dateFlg = ary![1]
                            } else {
                                sinceDay = self.processDataManager!.localData!.memberSinceHealthKit!
                                dateFlg = self.processDataManager!.localData!.getInitDateFlg(devKind!)
                            }
                        }
                    } else {
//                        sinceDay = ary![0]
                        dateFlg = ary![1]
                    }
                }
                
                // 該当デバイス＋種類のデータを取得
                let objMeisais = meisaiDatas[dev_path]!
//                let objSumDate = objResults["sumary"]!
                if objMeisais.count == 0 {
//                    completionHandler(false)
//                    return
                    continue
                }
                let meisaiArray: [String] = Array(objMeisais.keys).sorted()
                
                // 明細データ送信
                var sendDataDate: [String:String] = [:]
                
//                // データ30件毎にトランザクション化する
//                var objDates: [String:String] = [:]
//                var cnt = 0;
//                for (k,v) in objMeisais {
//                    if cnt > 29 {
//                        break
//                    }
//                    objDates[k] = v
//                    cnt += 1
//                }
                
                sendDataDate["user_id"] = self.serviceOpenID
                sendDataDate["dev"] = dev
                sendDataDate["path"] = path
    //            sendData["upd_date"] = iotDatas["upddate"].asString
                sendDataDate["actionType"] = "updateUserData"
                
                var objDates: [String:String] = [:]
                var cnt = 0;
                var tcnt = 1;
                for i in 0..<meisaiArray.count {
                    let day = meisaiArray[i]
                    if iotDatas["data"][day].asString != nil {
                        
                        let mdata = self.processDataManager!.getDayMeisaiData(path!, dev: dev!, day: day)
                        // 明細未取得のデータを送信対象外とする
                        if mdata.allKeys.count == 0 {
                            continue
                        }
                        
                        sendDataDate["date"] = day
                        sendDataDate["iot_data"] = JSON(mdata).toString()
//                        sendData["iot_data"] = v.toString()

                        let iotRawData = JSON(sendDataDate).toString().data(using: String.Encoding.utf8)
                        self.mqttClientPub!.publish(iotRawData!, topic: SystemConstants.IotIFTopic.IOT_DEV_DATA_SEND.rawValue, qos: 0, retain: false)
                        if !sendFlg {
                            sendFlg = true
                        }
                        print("明細データ：\(sendDataDate["date"]),\(sendDataDate["dev"]), \(sendDataDate["path"])")
                        sendCnt += 1
                        usleep(100)
                        
                        objDates[day] = "1"
                        cnt += 1
                    }
                    
                    // データ30件毎にトランザクション化する
                    if cnt == 30 {
                        // HealthKitの更新フラグがデバイスを区別しないので、特別扱う
                        var sflg = true
                        if devKind != "Fitbit" {
                            if let minHKDay = healthKitMinDay[path!] {
                                if minHKDay > day {
                                    healthKitMinDay[path!] = day
                                } else {
                                    sflg = false
                                }
                            }
                            objDates = [:]
                            objDates[day] = "1"
                        }
                    
                        if sflg {
                            let newFlg = self.processDataManager!.makeNewAwsDateFlg2(objDates, kind: devKind!, path: path!, sinceDay: sinceDay, awsDateFlg: dateFlg)
                            let newDateFlg = sinceDay + "," + newFlg
                            if dev != "Other" {
                                updateLastDataDate(iotDatas["path"].asString!, dev: iotDatas["dev"].asString!, newDate: newDateFlg)
                                print("日付フラグ更新\(tcnt)：\(iotDatas["path"].asString),\(iotDatas["dev"].asString), \(newDateFlg)")
                                tcnt += 1
                            }
                            dateFlg = newFlg
                            cnt = 0
                            objDates = [:]
                            usleep(100)
                        }
                    }
                    
                    // １回、種類ごとに最大１００件を送信する
                    if sendCnt > 99 {
                        break
                    }
                }
                if objDates.count > 0 {
                    var sflg = true
                    if devKind != "Fitbit" {
                        if let minHKDay = healthKitMinDay[path!] {
                            if minHKDay > day {
                                healthKitMinDay[path!] = day
                            } else {
                                sflg = false
                            }
                        } else {
                            healthKitMinDay[path!] = day
                        }
                        objDates = [:]
                        objDates[day] = "1"
                    }
                    
                    
                    let newDateFlg = sinceDay + "," + self.processDataManager!.makeNewAwsDateFlg2(objDates, kind: devKind!, path: path!, sinceDay: sinceDay, awsDateFlg: dateFlg)
                    // 手入力の場合、過日修正の可能性があるので、全部再送とする
                    if dev != "Other" {
                        updateLastDataDate(iotDatas["path"].asString!, dev: iotDatas["dev"].asString!, newDate: newDateFlg)
                        print("日付フラグ更新\(tcnt)：\(iotDatas["path"].asString),\(iotDatas["dev"].asString), \(newDateFlg)")
                        usleep(100)
                    }
                }
            }
        
//            sendFlg = sendFlg || (dev == "AUTO")
            completionHandler(sendFlg)
        
    }
    
    // 引数：指定pathの送信対象明細（dev: [day:value]）
    // 戻り値：段階送信情報（devkind: [sendDays:[], meisais: []]）
    fileprivate func getPathMeisaiSendDatas(meisaiDatas: [String: [String: String]]) -> [String:[String:[Any]]] {
        let result: [String:[String:[Any]]] = ["Fibit": [:],
                                               "HealthKit": [:]
                                              ]
        var sendDays: [String: [Any]] = [:]
        let meisais: [String: Any] = [:]
        for (dev,meisaiData) in meisaiDatas {
            var devKind = dev
            if devKind != "Fitbit" {
                devKind = "HealthKit"
            }
            if meisaiData.count == 0 {
//                    completionHandler(false)
//                    return
                continue
            }
            let meisaiArray: [String] = Array(meisaiData.keys).sorted()
            
            var fbObjDates: [String:String] = [:]
            var hkObjDates: [String:String] = [:]
            var cnt = 0;
            var tcnt = 1;
            for i in 0..<meisaiArray.count {
                let day = meisaiArray[i]
                if devKind == "Fitbit" {
                    fbObjDates[day] = "1"
                    if i == (SEND_DATA_CNT * tcnt) - 1 {
                        if sendDays[devKind] == nil {
                            sendDays[devKind] = []
                        }
                        sendDays[devKind]!.append(fbObjDates)
                        fbObjDates = [:]
                        tcnt += 1
                    }
                }
        
            }
        }
    }
}
