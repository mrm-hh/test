//
//  ProcessDataManager.swift
//  IotProject
//
//  Created by 黄海 on 2016/05/23.
//  Copyright © 2016年 黄海. All rights reserved.
//

import Foundation
import UIKit
import HealthKit
import CoreLocation

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


open class ProcessDataManager: NSObject {
    // SINGLETON
    open static let sharedInstance : ProcessDataManager = ProcessDataManager()
    
    open static let LOCAL_STORAGE_KEY = "IOT_PG_DATA"
    
    private let Realm_Ext = [
                             "intasect" : "",
                             "nuture" : "nn",
                             "keieiken" : "kk",
                             "shinanen" : "snn",
                             "tawara" : "twr",
                             "osaka-u" : "osku",
                             "tmi" : "tmi"
                            ]
    
    weak var healthkitManager = HealthKitAPIManager.sharedInstance
    weak var fitbitManager = FitbitAPIManager.sharedInstance
    weak var configManager = ConfigManager.sharedInstance
    weak var startupViewController: Startup?
    var groupViewBackFlg: Bool = false
    // 初回インストールフラグ、ロカールデータなし、AWSにユーザー情報なし
    var firstStartupFlg: Bool = false
    // 新規インストールフラグ、ロカールデータなし、AWSにユーザー情報ありなしを問わず
    var installStartFlg = false
    
    var isWaitOpenAMCallBack = false
    var isFitbitCallBackFlg = false
    
    // アプリのバージョン (ex. 1.7)
    var appVersion = ""
    
    // タイマー
    var iotTimerOne: Timer? = nil
    var iotTimerOne2: Timer? = nil
    var iotTimerRpt: Timer? = nil
    var iotTimerProgress: Timer? = nil
    
    var iotProgress: Float = 0
    weak var currentViewCtl: UIViewController? = nil

    // 初期処理フラグ
    var initProcFlg: Bool = false
    // 統計データ送信最小日付
    var initSendMinCheckDate=""
    
    var isProfileChanged: Bool = false
    var isExamDataChanged: Bool = false
    
    // 日ごとのサマリー
    fileprivate var _iotSummaryDatas:[String:SummaryItem]?
    
//    // 取得されたIoTデータ(path : [activityItem])
//    private var _iotDatas:[String:[ActivityItem]]?

    // 全デバイスの日ごとの集計値(path : [daySumItem])
    fileprivate var _iotDayDatas:[String:[DaySumItem]]?
    
    // クラウドなどから取った健康データ
    fileprivate var _iotDayGetDatas:[String:[DaySumItem]]?
    
    // AUTOモードフラグ
    var autoModeFlg: Bool = true
    // AUTOモード用
    //  _iotDayDatasの各種類の最大値インデックス(path : [day : kindIdx])
    //   kindIdx => 1:Fitbit, 2:Xiaomi, 3:iPhone, 4:Other
    fileprivate var _autoDayIdxs:[String:[String:Int]]?
    
    // ローカルストレージデータ(path : ActiveTypeRecord)
    fileprivate var _allStorageData:[String: ActiveTypeRecord]?
    
    // アニメコントロールセット配列
    var animeSets: [String : AnimeSet]?
    
    var profileData: ProfileData?
    var examResults: [[String: String]]?
    var delExamResultDic: [String: String] = [:]
    
    // 現在位置情報
    var curtLocation: CLLocation?
    
    var pgUID: String?
    var userOrgID: String?      // 所属会社ID
    var orgEnsureKbn: String?   // 所属確認済区分（1:済、以外:未）
    var serviceOpenID: String?
    var serviceToken: String?
    var deviceToken: String?    // Push通知用デバイストークン
    var hasDeviceFb: Bool?  // Fitbit のデバイスがあるか
    var hasDeviceFsl: Bool?  // FreeStyle Libre のデバイスがあるか
    var isGroupManager: Bool?   // マネージャ権限あるか
    
    // データありのデバイスリスト
    var existDevices: [String]?
    // 前回選択されたデバイス
    var currentDevice: String?
    
    var initGroup:DispatchGroup?
    
    weak var groupTabBarItem: UITabBarItem?
    weak var adminBarButton: UIBarButtonItem?
    
    var faqWebVC: FAQWebVC?
    var memberWebVc: ManagerWebVC?
    
    var glucoseLimitHighVal: Int = 0
    var glucoseLimitLowVal: Int = 0
    
    // 管理者画面からの未読メッセージ情報
    var groupNewMsgInfo: JSON?  // {"detail":[
                                //    {"newCnt":n1,"titelID":"xxxxx"},
                                //    {"newCnt":n2,"titelID":"xxxxx"},...
                                //   ],
                                //   "cnt":n,"user":"doctor1"
                                // }
    
    fileprivate override init() {
    
        super.init()
        userOrgID = nil
        orgEnsureKbn = nil
        serviceOpenID = nil
        serviceToken = nil
//        _iotDatas = [:]
        _iotDayDatas = [:]
        _iotDayGetDatas = [:]
        _autoDayIdxs = [:]
        
        curtLocation = nil
        
        _allStorageData = [:]
//        _newHealthData = [:]
        hasDeviceFb = false
        hasDeviceFsl = false
        currentDevice = Defaults[.curtDevice]
        autoModeFlg = Defaults[.autoModeFlg]
        
        animeSets = [:]
        examResults = []
        
        if initGroup == nil {
            initGroup = DispatchGroup()
        }
        
        // GPS情報取得
        Location.getLocation(accuracy: .room, frequency: .oneShot, timeout: nil, success: {
            (request, location) in
                print("現在地を取得しました \(location)")
                request.cancel()
            }){ (request, last, error) in
                print("Location get failed due to an error \(error)")
            }
        
        Location.onReceiveNewLocation = { location in
            self.curtLocation = location
//            print("- lat,lng=\(location.coordinate.latitude),\(location.coordinate.longitude), h-acc=\(location.horizontalAccuracy) mts\n")
        }
        // 管理者画面からの未読メッセージ情報を登録する
        NotificationCenter.default.addObserver(self, selector: #selector(refreshNewMsg(_:)), name: NSNotification.Name(rawValue: "NewMsgInfoComing2"), object: nil)

    }
    
    func getIotDayDatas(_ typePath: String) -> [DaySumItem] {
        if typePath != (HealthType.Glucose["path"] as! String) {
            if _iotDayDatas == nil || _iotDayDatas![typePath] == nil {
                return []
            }
            return _iotDayDatas![typePath]!
        } else {
//            _iotDayGetDatas![typePath] = _iotDayDatas![HealthType.ActivitySteps["path"] as! String]
            if _iotDayGetDatas == nil || _iotDayGetDatas![typePath] == nil {
                return []
            }
//            for glucoseData in _iotDayGetDatas![typePath]! {
//                let dayitems = glucoseData.dayItems
//                glucoseData.sumValue = glucoseData.sumValue / Double(dayitems.count)
//            }
            return _iotDayGetDatas![typePath]!
        }
    }
    
    func getIotDayData(_ typePath: String, dev: String, day: String) -> DaySumItem? {
        let rec = _allStorageData![typePath]
        if rec != nil {
            if let data = rec!.getDayItems(dev)![day] {
                return data
            }
        }
        return nil
    }
    
    func getDayMeisaiData(_ path: String, dev: String, day: String) -> NSDictionary {
        
//        var idx: Int? = nil
//        
//        if _iotDayIdxs![path] != nil {
//            idx = _iotDayIdxs![path]![day]
//        }
//        if idx != nil {
//            let dayItem = _iotDayDatas![path]![idx!]
//            return dayItem.toStorageDictionary(dev)
//        }
        let rec = _allStorageData![path]
        if rec != nil {
            if let data = rec!.getDayItems(dev)![day] {
                return data.toStorageDictionary(dev)
            }
        }
        
        return NSDictionary()
    }
    
    func getSummaryData(_ date: String) -> SummaryItem? {
        if _iotSummaryDatas == nil || _iotSummaryDatas![date] == nil {
            return nil
        }
        return _iotSummaryDatas![date]
    }

    func getSummaryDatas() -> [SummaryItem] {
        if _iotSummaryDatas == nil {
            return []
        }
        return Array(_iotSummaryDatas!.values).sorted(by: summarySort)
    }
    
    func addSummaryData(_ day:String, typePath:String, value:Double) {
        if _iotSummaryDatas![day] == nil {
            _iotSummaryDatas![day] = SummaryItem()
            _iotSummaryDatas![day]!.day = day
        }
        if value == 0 {
            return
        }
        
        if typePath != HealthType.Heart["path"] as! String && typePath != HealthType.Speed["path"] as! String {
            _iotSummaryDatas![day]!.kinds[typePath] = _iotSummaryDatas![day]!.kinds[typePath]! + value
        } else {
            if _iotSummaryDatas![day]!.kinds[typePath] == 0 {
                _iotSummaryDatas![day]!.kinds[typePath] = value
            } else {
                _iotSummaryDatas![day]!.kinds[typePath] = _iotSummaryDatas![day]!.kinds[typePath]! + value / 2
            }
        }
    }
    
    func addIotDataItem(_ typePath: String, item: ActivityItem) {
        _allStorageData![typePath]?.addActItem(item)
    }
    
    // データソート
    fileprivate func actSort(_ o1: ActivityItem, _ o2: ActivityItem) -> Bool {
        var result: Bool = false
        if o1.startTime! > o2.startTime! {
            result = true
        } else {
            if o1.startTime == o2.startTime && o1.deviceName > o2.deviceName {
                result = true
            } else {
                result = false
            }
        }
        
        return result
    }
    fileprivate func actSort2(_ o1: ActivityItem, _ o2: ActivityItem) -> Bool {
        var result: Bool = false
        if o1.startTime! < o2.startTime! {
            result = true
        } else {
            result = false
        }
        return result
    }
    fileprivate func daySumSort(_ o1: DaySumItem, _ o2: DaySumItem) -> Bool {
        return o1.day > o2.day
    }
    func summarySort(_ o1: SummaryItem, _ o2: SummaryItem) -> Bool {
        return o1.day > o2.day
    }
    
    func calcDaySumItems(_ actTypeRecord: ActiveTypeRecord) {
        let typePath = actTypeRecord.typePath!
        
        // 日明細(ActivityItem)データをローカルに保存する
        let queue = DispatchQueue.global(qos: .background)
//        queue.async { [weak self] in
            for k in actTypeRecord.fitbitDatas.keys {
                let newDayItem: DaySumItem = actTypeRecord.fitbitDatas[k]!
                // 明細ありのデータのみをロカール保存する
                if newDayItem.dayItems.count > 1 || (newDayItem.dayItems.count == 1 && newDayItem.dayItems["000000"] == nil) {
                    let fbData = self.getIotDayData(typePath, dev: "Fitbit", day: k)
                    if fbData != nil {
                        fbData?.toStorageData(true)
                    }
                }
            }
            if typePath == (HealthType.Sleep["path"] as! String) {
                for k in actTypeRecord.xiaomiDatas.keys {
                    let xmData = self.getIotDayData(typePath, dev: "Xiaomi", day: k)
                    if xmData != nil {
                        xmData?.toStorageData(true)
                    }
                }
                for k in actTypeRecord.iphoneDatas.keys {
                    let ipData = self.getIotDayData(typePath, dev: "iPhone", day: k)
                    if ipData != nil {
                        ipData?.toStorageData(true)
                    }
                }
                for k in actTypeRecord.applewatchDatas.keys {
                    let iwData = self.getIotDayData(typePath, dev: "AppleWatch", day: k)
                    if iwData != nil {
                        iwData?.toStorageData(true)
                    }
                }
                for k in actTypeRecord.otherDatas.keys {
                    let otData = self.getIotDayData(typePath, dev: "Other", day: k)
                    if otData != nil {
                        otData?.toStorageData(true)
                    }
                }
            }
            print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + "   明細データStorage保存済み。（" + typePath + "）")
//        }
//        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + "  日明細データStorage保存済")
        if self.installStartFlg == true && self.initProcFlg == true {
            self.updateInitProgress(progress: 0.02, title: "集計データ生成")
        }
        
        if _autoDayIdxs![typePath] == nil {
            _autoDayIdxs![typePath] = [:]
        }
        // 全デバイスにデータあるの日付を取得する
        if _allStorageData![typePath] != nil {
            for k in _allStorageData![typePath]!.fitbitDatas.keys {
                _autoDayIdxs![typePath]![k] = 0;
            }
            for k in _allStorageData![typePath]!.xiaomiDatas.keys {
                _autoDayIdxs![typePath]![k] = 0;
            }
            for k in _allStorageData![typePath]!.iphoneDatas.keys {
                _autoDayIdxs![typePath]![k] = 0;
            }
            for k in _allStorageData![typePath]!.applewatchDatas.keys {
                _autoDayIdxs![typePath]![k] = 0;
            }
            for k in _allStorageData![typePath]!.otherDatas.keys {
                _autoDayIdxs![typePath]![k] = 0;
            }
        }
//        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + "  全デバイス日付取得済")
        if self.installStartFlg == true && self.initProcFlg == true {
            self.updateInitProgress(progress: 0.06, title: "集計データ生成")
        }

        // AUTOモードの対象確定
        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + "  AUTOデータ生成開始")
        for (k,_) in _autoDayIdxs![typePath]! {
            var val = 0.0;
            if _allStorageData![typePath]!.fitbitDatas[k] != nil {
                _autoDayIdxs![typePath]![k] = 1
                val = _allStorageData![typePath]!.fitbitDatas[k]!.sumValue
            }
            if _allStorageData![typePath]!.xiaomiDatas[k] != nil && _allStorageData![typePath]!.xiaomiDatas[k]!.sumValue > val {
                _autoDayIdxs![typePath]![k] = 2
                val = _allStorageData![typePath]!.xiaomiDatas[k]!.sumValue
            }
            if _allStorageData![typePath]!.iphoneDatas[k] != nil && _allStorageData![typePath]!.iphoneDatas[k]!.sumValue > val {
                _autoDayIdxs![typePath]![k] = 3
                val = _allStorageData![typePath]!.iphoneDatas[k]!.sumValue
            }
            if _allStorageData![typePath]!.otherDatas[k] != nil && _allStorageData![typePath]!.otherDatas[k]!.sumValue > val {
                _autoDayIdxs![typePath]![k] = 4
//                val = _allStorageData![typePath]!.otherDatas[k]!.sumValue
            }
            if _allStorageData![typePath]!.applewatchDatas[k] != nil && _allStorageData![typePath]!.applewatchDatas[k]!.sumValue > val {
                _autoDayIdxs![typePath]![k] = 5
                val = _allStorageData![typePath]!.applewatchDatas[k]!.sumValue
            }
//            if _autoDayDatas![typePath] == nil {
//                _autoDayDatas![typePath] = []
//            }
//            switch _autoDayIdxs![typePath]![k]! {
//                case 1:
//                    _autoDayDatas![typePath]!.append(_allStorageData![typePath]!.fitbitDatas[k]!)
//                case 2:
//                    _autoDayDatas![typePath]!.append(_allStorageData![typePath]!.xiaomiDatas[k]!)
//                case 3:
//                    _autoDayDatas![typePath]!.append(_allStorageData![typePath]!.iphoneDatas[k]!)
//                case 4:
//                    _autoDayDatas![typePath]!.append(_allStorageData![typePath]!.otherDatas[k]!)
//                default:
//                    print("AUTOモードデータ不正：" + typePath + "," + k)
//            }
            
        }
        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + "  AUTOデータ生成済")
        if self.installStartFlg == true && self.initProcFlg == true {
            self.updateInitProgress(progress: 0.10, title: "集計データ生成")
        }
    }
    
    fileprivate func getAutoDayItem(typePath: String, day: String, kindIdx: Int) -> DaySumItem? {
        var dayItem: DaySumItem?

//        if _autoDayIdxs![typePath] == nil || _autoDayIdxs![typePath]![day] == nil {
//            return nil
//        }
        switch kindIdx {
            case 1:
                dayItem = _allStorageData![typePath]!.fitbitDatas[day]
            case 2:
                dayItem = _allStorageData![typePath]!.xiaomiDatas[day]
            case 3:
                dayItem = _allStorageData![typePath]!.iphoneDatas[day]
            case 4:
                dayItem = _allStorageData![typePath]!.otherDatas[day]
            case 5:
                dayItem = _allStorageData![typePath]!.applewatchDatas[day]
            default:
                print("AUTOモードデータ不正：" + typePath + "," + day)
        }
        
        return dayItem
    }
    
    func getExistDevices() -> [String] {
        var chkdic: [String:String] = [:]
        var result: [String] = []
//        var all_path: [String] = []
//        
//        all_path.append(HealthType.ActivitySteps["path"] as! String)
//        all_path.append(HealthType.ActivityCalories["path"] as! String)
//        all_path.append(HealthType.Sleep["path"] as! String)
//        all_path.append(HealthType.Heart["path"] as! String)
//        all_path.append(HealthType.ActivityDistance["path"] as! String)
        
        for path in _allStorageData!.keys {
            if _allStorageData![path]?.fitbitDatas.keys.count > 0 {
                chkdic["Fitbit"] = "OK"
            }
            if _allStorageData![path]?.xiaomiDatas.keys.count > 0 {
                chkdic["Xiaomi"] = "OK"
            }
            if _allStorageData![path]?.iphoneDatas.keys.count > 0 {
                chkdic["iPhone"] = "OK"
            }
            if _allStorageData![path]?.otherDatas.keys.count > 0 {
                chkdic["Other"] = "OK"
            }
            if _allStorageData![path]?.applewatchDatas.keys.count > 0 {
                chkdic["AppleWatch"] = "OK"
            }
        }
        if chkdic["Fitbit"] != nil {
            result.append("Fitbit")
        }
        if chkdic["Xiaomi"] != nil {
            result.append("Xiaomi")
        }
        if chkdic["iPhone"] != nil {
            result.append("iPhone")
        }
        if chkdic["AppleWatch"] != nil {
            result.append("AppleWatch")
        }
        if chkdic["Other"] != nil {
            result.append("Other")
        }
        
        
        return result
    }
    
    func selectViewData(_ dev: String) {
        if dev == "auto_mode" {
            for (path, dic) in _autoDayIdxs! {
                _iotDayDatas![path] = []
                
                for (day, idx) in dic {
                    if let autoDayItem = getAutoDayItem(typePath: path, day: day, kindIdx: idx) {
                        _iotDayDatas![path]!.append(autoDayItem)
                    } else {
                        print("AUTOモードデータ不正：" + path + ", DAY:" + day + ", KINDIDX:" + String(idx))
                    }
                }
                
                if _iotDayDatas![path]!.count > 0 {
                    _iotDayDatas![path] = _iotDayDatas![path]!.sorted(by: daySumSort)
                }
            }
            print("AUTO MODE")
        } else {
        
//            _iotDayDatas = [:]
            for (path, rec) in _allStorageData! {
                _iotDayDatas![path] = []
                
                switch dev {
                    case "Fitbit":
                        for (day, item) in rec.fitbitDatas {
    //                        _iotDayIdxs![path]![day] = _iotDayDatas![path]!.count
                            _iotDayDatas![path]!.append(item)
                        }
                    case "Xiaomi":
                        for (day, item) in rec.xiaomiDatas {
    //                        _iotDayIdxs![path]![day] = _iotDayDatas![path]!.count
                            _iotDayDatas![path]!.append(item)
                        }
                    case "iPhone":
                        for (day, item) in rec.iphoneDatas {
    //                        _iotDayIdxs![path]![day] = _iotDayDatas![path]!.count
                            _iotDayDatas![path]!.append(item)
                        }
                    case "Other":
                        for (day, item) in rec.otherDatas {
    //                        _iotDayIdxs![path]![day] = _iotDayDatas![path]!.count
                            _iotDayDatas![path]!.append(item)
                        }
                    case "AppleWatch":
                        for (day, item) in rec.applewatchDatas {
                            _iotDayDatas![path]!.append(item)
                        }
                    default:
                        print("対象外デバイス: " + dev)
                        return
                }
                
                if _iotDayDatas![path]!.count > 0 {
                    _iotDayDatas![path] = _iotDayDatas![path]!.sorted(by: daySumSort)
    //                for i in 0..<_iotDayDatas![path]!.count {
    //                    let day = _iotDayDatas![path]![i].day
    //                    _iotDayIdxs![path]![day] = i
    //                }
                }
            }
        }
        calcSummaryData()
    }

//  全Dev合算 のメッソド
//    func calcDaySumItems(actTypeRecord: ActiveTypeRecord) {
//        let typePath = actTypeRecord.typePath!
//
//        // 全デバイスレコードに集計する（ローカルデータ＋更新分データ）
//        for date in actTypeRecord.itemDays.keys {
//            
//            let sumDayItem = actTypeRecord.getSumDayItem(date)
//            if sumDayItem != nil {
//                _addIotDaySumData(typePath, data: sumDayItem!)
//                
//                // 日明細(ActivityItem)データをローカルに保存する
//                let fbData = getIotDayData(typePath, dev: "Fitbit", day: date)
//                if fbData != nil {
//                    fbData?.toStorageData(true)
//                }
//                let xmData = getIotDayData(typePath, dev: "Xiaomi", day: date)
//                if xmData != nil {
//                    xmData?.toStorageData(true)
//                }
//                let ipData = getIotDayData(typePath, dev: "iPhone", day: date)
//                if ipData != nil {
//                    ipData?.toStorageData(true)
//                }
//                let otData = getIotDayData(typePath, dev: "Other", day: date)
//                if otData != nil {
//                    otData?.toStorageData(true)
//                }
//            }
//        }
//        
//        // _iotDayDatas[]のindexを設定する
//        if _iotDayDatas![typePath] != nil {
//            _iotDayDatas![typePath] = _iotDayDatas![typePath]!.sort(daySumSort)
//            for i in 0..<_iotDayDatas![typePath]!.count {
//                let day = _iotDayDatas![typePath]![i].day
//                _iotDayIdxs![typePath]![day] = i
//            }
//        }
//
//    }
    
    func calcSummaryData() {
        _iotSummaryDatas = [:]
        for (path, datas) in _iotDayDatas! {
//            var typePath = path as! String
            for data in datas {
                let day = data.day
                addSummaryData(day, typePath: path, value: data.sumValue)
            }
        }
    }
    
    func setDeviceStatus(){
        if let bfb = localData!.profileDataJSON!["isUseDeviceFitbit"].asBool {
            hasDeviceFb = bfb
        } else {
            hasDeviceFb = false
        }
        if let bfb = localData!.profileDataJSON!["isUseDeviceFSL"].asBool {
            hasDeviceFsl = bfb
        } else {
            hasDeviceFsl = false
        }
        
//        // 20170111 デモ用追加対応（データ合算しないため）
//        if (hasDeviceFb == true){
//            hasDeviceXm = false
//        } else {
//            hasDeviceXm = true
//        }
//        // ----------------------------------------
    }
    
    //
    func examSort(_ o1: [String:String], _ o2: [String:String]) -> Bool {
        var result: Bool = false
        if o1["examDay"]! > o2["examDay"]! {
            result = true
        } else {
            result = false
        }
        return result
    }
    
    func examUnique(_ arry: [[String:String]]) -> [[String:String]] {
    
        var result:[[String:String]] = []
        var tempDic:[String:Any] = [:]
        
        for data in arry {
            tempDic[data["examDay"]!] = data        
        }
        for (k,v) in tempDic {
            result.append(v as! [String : String])
        }
        
        return result
    }
    
    func initDatasFromStorage() {
        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " initDatasFromStorage start")
        setDeviceStatus()
        
        // 個人設定データを読み込む
        if localData!.profileDataJSON == nil {
            profileData = ProfileData()
        } else {
            let jsonObj : JSON = (localData!.profileDataJSON)!
            profileData = ProfileData()
            profileData!.setValue(jsonObj)
            
            
//            if jsonObj["displayName"].asString == "" {
//                if (fitbitManager?.loginFlg)! {
//                    let fitbitProfile : ProfileData = (fitbitManager?.getProfile())!
//                    profileData?.displayName = fitbitProfile.displayName
//                    profileData?._gender = fitbitProfile.gender
//                    profileData?.age = fitbitProfile.age
//                }
//                setData()
//                if jsonObj["displayName"].asString == "" {
//                    present(alert, animated: true, completion: nil)
//                    return
//                }
//                saveToLocalStorage()
//            } else {
//                setData()
//            }
        }

        // 健康診断結果データを読み込む
        if examResults!.count == 0 && localData!.examResultData != nil {
            for exam in localData!.examResultData!.asArray! {
                var examData: [String: String] = [:]
                for (k,v) in exam.asDictionary! {
                    examData[k] = v.asString
                }
                examResults!.append(examData)
            }
//            examResults = examResults!.reversed()
            if examResults?.count == 0 || examResults?[0].count == 0 {
                examResults = []
            } else {
                examResults = self.examUnique(examResults!)
                examResults!.sort(by: examSort)
            }
        }
        if delExamResultDic.count == 0 && localData!.delExamResultData != nil {
            for (k,v) in localData!.delExamResultData! {
                delExamResultDic[k as! String] = "D"
            }
//            if delExamResultDic.count > 0 {
//                isExamDataChanged = true
//            }
        }
        
        // ヘルスケアデータを読み込む
        if localData == nil || localData?.healthcareData == nil {
            print("ローカルヘルスケアデータが存在していない")
            return
        }
        var speedCreateKbn : Int
        if let speedData = localData?.healthcareData![HealthType.Speed["path"] as! String].asDictionary {
            //------ ver2.2.5以降削除可 ------
            // ver2.2.3の修正区分
            let fixKbn = DB.store["fix-223"]
            if fixKbn == "fixed" {
                speedCreateKbn = 0
            } else {
                speedCreateKbn = 1
                DB.store["fix-223"] = "fixed"
            }
            //------------------------------
//            speedCreateKbn = 0
        } else {
            speedCreateKbn = 1
            DB.store["fix-223"] = "fixed"
        }
        for (path, pathData) in (localData?.healthcareData)! {
            initGroup!.enter()
            DispatchQueue.global(qos: .background).async { [weak self] () -> Void in
                // distance、且つSpeedデータ作成されていない場合: 1、以外の場合: 0
                let kbn = ((path as! String) == (HealthType.ActivityDistance["path"] as! String)
                           && speedCreateKbn == 1) ? 1 : 0
                let mvdatas = self!.makeViewDataFromJSON(path as! String,
                    jsonData: pathData, addKbn: kbn)
                let rec: ActiveTypeRecord = mvdatas[0]
                self!._allStorageData![path as! String] = rec
                if kbn == 1 && speedCreateKbn == 1 && mvdatas.count > 1 {
                    let rec2: ActiveTypeRecord = mvdatas[1]
                    self!._allStorageData![HealthType.Speed["path"] as! String] = rec2
                }
                print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " makeViewData end (" + (path as! String) + ")")
                
                self!.initGroup!.leave()
            }
        }
        
//        // グルコースデータ
//        makeFSLViewData()
        
//        // Path別のDaySumItemデータロード 
//        if localData?.daySumDatas == nil {
//            print("ローカルヘルスケアデータが存在していない")
//            return
//        }
//        _iotDayDatas = [:]
//        _iotDayIdxs = [:]
//        for (path, pathData) in (localData?.daySumDatas)! {
//            var cnt: Int = 0
//            var arr: [DaySumItem] = []
//            var idxdic: [String:Int] = [:]
//            for (day, sumval) in pathData {
//                let sumItem = DaySumItem(path: path as! String, dev: "", day: day as! String)
//                sumItem.sumValue = Double(sumval.asString!)!
//                arr.append(sumItem)
//                
//                idxdic[day as! String] = cnt
//                cnt = cnt + 1
//            }
//            _iotDayDatas![path as! String] = arr
//            _iotDayIdxs![path as! String] = idxdic
//        }
    }
    
    func makeFSLViewData() {
        if let fslDataStr = localData!.freestylelibreData!["glucose"].asString {
            let glucoseJson = JSON.parse(fslDataStr)
            var datas: [DaySumItem] = []
            var createTimes: [String] = []
            for(k, ddata) in glucoseJson {
                let day = k as! String
                let dayItem = DaySumItem(path: "glucose", dev: "FreeStyleLibre", day: day)
                let meisaiJson = JSON.parse(ddata["meisai"].asString!)
                for (time, mval) in meisaiJson {
                    let keyary = (time as! String).split(separator: "_")
                    if keyary.count == 2 {
                        let aitem = ActivityItem()
                        aitem.startTime = CommUtil.string2date(day + " " + String(keyary[0]), format: "yyyy-MM-dd HHmm")
                        aitem.endTime = aitem.startTime
                        let sVal = mval.asDouble
                        aitem.value = (sVal == nil) ? 0.0 : sVal!
                        aitem.subType = String(keyary[1])
                        
                        dayItem.addActItem(aitem)
                    }
                }
                if let avgVal = ddata["val"].asString {
                    dayItem.sumValue = Double(avgVal)!
                }
                if let ct = ddata["createtime"].asString {
                    createTimes.append(ct)
                }
                datas.append(dayItem)
            }
            self._iotDayGetDatas!["glucose"] = datas.sorted(by: daySumSort)
            // 取得されたデータの最後作成日時を保存する
            if createTimes.count > 0 {
                createTimes = createTimes.sorted()
    //            self.localData!.fslUpdateDateTime = createTimes[createTimes.count - 1]
                if createTimes[createTimes.count - 1] > self.localData!.fslUpdateDateTime {
                    self.localData!.fslUpdateDateTime = createTimes[createTimes.count - 1]
                }
            }
            
        }
    }
    
    // addKbn-> 0: 一般処理、1:speed算出要
    func makeViewDataFromJSON(_ path: String, jsonData: JSON, addKbn: Int = 0) -> [ActiveTypeRecord] {
        let result = ActiveTypeRecord(path: path)
        
        for (dev,devData) in jsonData {
//            // 20170111 デモ用追加対応（データ合算しないため）
//            if hasDeviceFb! {
//                if dev as! String == "iPhone" || dev as! String == "Xiaomi" {
//                    continue
//                }
//            } else {
//                if dev as! String == "Fitbit" {
//                    continue
//                }
//            }
//            // ----------------------------------------
        
            result.initFormJson(devData)
        }
        var retDatas = [result];
        if addKbn == 1 {
            let result2 = self.createSpeedRecord(by: result)
            retDatas.append(result2)
        }
        
        return retDatas
    }
    
    func createSpeedRecord(by distanceRecord: ActiveTypeRecord) -> ActiveTypeRecord {
        let path = HealthType.Speed["path"] as! String
        let speedRecord = ActiveTypeRecord(path: path)
        
        // k: day(yyyy-mm-dd)
        for k in distanceRecord.fitbitDatas.keys {
            let fbDistanceDayItem: DaySumItem = distanceRecord.fitbitDatas[k]!
            // 明細ありのデータのみを算出する
            if fbDistanceDayItem.dayItems.count > 1 || (fbDistanceDayItem.dayItems.count == 1 && fbDistanceDayItem.dayItems["000000"] == nil) {
                let fbData = createSpeedDayItem(by: fbDistanceDayItem)
                // Speed明細保存不要
//                fbData.toStorageData(true)
                speedRecord.add(fbData)
            }
        }
        
        for k in distanceRecord.xiaomiDatas.keys {
            let distanceDayItem: DaySumItem = distanceRecord.xiaomiDatas[k]!
            let xmData = createSpeedDayItem(by: distanceDayItem)
//            xmData.toStorageData(true)
            speedRecord.add(xmData)
            
        }
        for k in distanceRecord.iphoneDatas.keys {
            let distanceDayItem: DaySumItem = distanceRecord.iphoneDatas[k]!
            let ipData = createSpeedDayItem(by: distanceDayItem)
//            ipData.toStorageData(true)
            speedRecord.add(ipData)
        }
        for k in distanceRecord.applewatchDatas.keys {
            let distanceDayItem: DaySumItem = distanceRecord.applewatchDatas[k]!
            let iwData = createSpeedDayItem(by: distanceDayItem)
//            iwData.toStorageData(true)
            speedRecord.add(iwData)
        }
        for k in distanceRecord.otherDatas.keys {
            let distanceDayItem: DaySumItem = distanceRecord.otherDatas[k]!
            let otData = createSpeedDayItem(by: distanceDayItem)
//            otData.toStorageData(true)
            speedRecord.add(otData)
        }
        return speedRecord
    }
    
    func createSpeedDayItem(by distanceDayItem: DaySumItem) -> DaySumItem {
        let path = HealthType.Speed["path"] as! String
        let newItem = DaySumItem(path: path, dev: distanceDayItem.dev, day: distanceDayItem.day)
        newItem.dayItems = [:]
        
        // 日合計歩き時間(単位：秒)
        var dayItemTotalTimes = distanceDayItem.extData
        
        // 既存データなら、1日実際の運動時間を計算する
        if dayItemTotalTimes == 0 {
            // mk: time(hhmmss)
            for mk in distanceDayItem.dayItems.keys {
                let actDistanceItem = distanceDayItem.dayItems[mk]
    //            let newActItem = ActivityItem()
    //            newActItem.startTime = actDistanceItem?.startTime
    //            newActItem.endTime = actDistanceItem?.endTime
    //            newActItem.deviceName = actDistanceItem?.deviceName
                // 間隔時間(単位：秒)を取得
                var interSeconds = 0
                // Fitbitの明細が分単位なので、分けて処理する
                if distanceDayItem.dev != "Fitbit" {
                    interSeconds = CommUtil.getDateInterVal(actDistanceItem!.startTime!, toDate:actDistanceItem!.endTime!, kbn: "s")
                } else {
                    interSeconds = 60
                }
                dayItemTotalTimes = dayItemTotalTimes + Double(interSeconds)
    //            // 速度算出(km/h)
    //            if interSeconds == 0 {
    //                newActItem.value = 0
    //            } else {
    //                newActItem.value = actDistanceItem!.value / Double(interSeconds) * 3600
    //            }
    //            let stime = CommUtil.date2string(newActItem.startTime, format: "HHmmss")
    //            newItem.dayItems[stime!] = newActItem
            }
        }
        if dayItemTotalTimes == 0 {
            newItem.sumValue = 0
        } else {
            // 単位： km/h
            newItem.sumValue = distanceDayItem.sumValue / Double(dayItemTotalTimes) * 3600
        }
        return newItem
    }
    
    func createSpeedActItem(by actDistanceItem: ActivityItem) -> ActivityItem {
        let newActItem = ActivityItem()
        var dayItemTotalTimes = 0
        newActItem.startTime = actDistanceItem.startTime
        if actDistanceItem.deviceName == "Fitbit" {
            newActItem.endTime = actDistanceItem.startTime?.addingTimeInterval(TimeInterval(59))
        } else {
            newActItem.endTime = actDistanceItem.endTime
        }
        newActItem.deviceName = actDistanceItem.deviceName
        // 間隔時間(単位：秒)を取得
        let interSeconds = CommUtil.getDateInterVal(newActItem.startTime!, toDate:newActItem.endTime!, kbn: "s")
        dayItemTotalTimes += interSeconds
        // 速度算出(km/h)
        if interSeconds == 0 {
            newActItem.value = 0
        } else {
            newActItem.value = actDistanceItem.value / Double(interSeconds) * 3600
        }
        return newActItem
    }

    func makeStorageDaySumData() -> JSON {
        // 全デバイスの日ごとの集計情報
        var result: [String:Any] = [:]
        var all_path: [String] = []
        
        all_path.append(HealthType.ActivitySteps["path"] as! String)
        all_path.append(HealthType.ActivityCalories["path"] as! String)
        all_path.append(HealthType.Sleep["path"] as! String)
        all_path.append(HealthType.Heart["path"] as! String)
        all_path.append(HealthType.ActivityDistance["path"] as! String)
        
        for path in all_path {
            let pathDatas = _iotDayDatas![path]
            if pathDatas != nil {
                var sumdic:[String:String] = [:]
                for i in 0..<pathDatas!.count {
                    sumdic[pathDatas![i].day] = pathDatas![i].toStorageData()
                }
                result[path] = sumdic as Any
            }
        }
        return JSON(result)
    }
    
    func makeAllStorageData() -> JSON {
        var result: [String:Any] = [:]
        var all_path: [String] = []
        
        all_path.append(HealthType.ActivitySteps["path"] as! String)
        all_path.append(HealthType.ActivityCalories["path"] as! String)
        all_path.append(HealthType.Sleep["path"] as! String)
        all_path.append(HealthType.Heart["path"] as! String)
        all_path.append(HealthType.ActivityDistance["path"] as! String)
        all_path.append(HealthType.Speed["path"] as! String)
        
        for path in all_path {
            if _allStorageData![path] == nil {
                _allStorageData![path] = ActiveTypeRecord(path: path)
            }
            var data:[String:JSON] = _allStorageData![path]!.toDictionary()
            
            // AUTOモードのデータを特殊なデバイスとして追加する
            //   _autoDayIdxs => (path : [day : kindIdx])
            let autoDevDatas: [String:Any] = ["path": path,
                                              "dev": "AUTO",
                                              "data": _autoDayIdxs![path]
                                             ]
            data["AUTO"] = JSON(autoDevDatas)
            
            result[path] = data as Any
            
        }
        return JSON(result)
    }
    
//    private func getLastUpdateDay(dev: String, kind: String? = nil) -> String? {
//        var lastUpdateDay: String?
//        
//        if dev == "Fitbit" {
//            let fitbitDates = localData!.storageDate["Fitbit"] as! [String:String]
//            lastUpdateDay = fitbitDates[kind!]
//        } else {
//            lastUpdateDay = localData!.storageDate["HealthKit"] as? String
//        }
//
//        return lastUpdateDay
//    }
    
    func refreshNewMsg(_ notification: Notification) {
        if let userInfo = notification.userInfo {
//            let storyboard = UIStoryboard(name: "Group", bundle: NSBundle.mainBundle())
//            let groupViewController = storyboard.instantiateInitialViewController() as? UINavigationController
//            let vc = CommUtil.getTopMostViewController()
//            if let tabbarCtl = vc!.tabBarController {
            if groupTabBarItem != nil {
//                let item = tabbarCtl.viewControllers?[2].tabBarItem
                let result = userInfo["cnt"]! as! Int
                if result > 0 {
                    let valueStr = result > 9 ? "..." : String(result)
                    groupTabBarItem!.badgeValue = valueStr
                    if adminBarButton != nil {
                        adminBarButton?.addBadge(number: result)
                    }
                    // バッジナンバーを初期化
                    UIApplication.shared.applicationIconBadgeNumber = result
                } else {
                    groupTabBarItem!.badgeValue = nil
                    if adminBarButton != nil {
                        adminBarButton?.removeBadge()
                    }
                    // バッジナンバーを初期化
                    UIApplication.shared.applicationIconBadgeNumber = 0
                }
            }
        }
    }


    // ----------------- DATA I/O -------------------
    // Local Data ->
    //  pgUID : xxxxx
    //  inputHealthData : xxxxx
    //  dayNoteData : { yyyyMMdd : { kibun : nn, syokuji : nn, pic : [picID], memo : String }
    //                  ......
    //                }
    var localData: LocalData?
    
    func localSave() {
        
        if localData == nil {
            return
        }
        var isNewUser = false
        if localData?.profileDataJSON == nil {
            isNewUser = true
        }
        
        TransDataManager.sharedInstance.isRuning = true;
        let n : Notification = Notification(name: Notification.Name(rawValue: "DataTransformBegin"), object: self, userInfo: [:])
        NotificationCenter.default.post(n)
        // 健康データ
        localData!.healthcareData = makeAllStorageData()
        // 個人設定データ
//        let cloudstr = configManager!.toJsonStr()
//        if profileData!.cloudSettingStr != cloudstr {
//            profileData!.isChanged = true
//            profileData!.cloudSettingStr = cloudstr
//        }
//        let fitselectstr = JSON(localData!.fitSelectedPgList).toString()
//        if profileData!.fitSelectedPgStr != fitselectstr {
//            profileData!.isChanged = true
//            profileData!.fitSelectedPgStr = fitselectstr
//        }
        profileData!.cloudSettingStr = configManager!.toJsonStr()
        profileData!.fitSelectedPgStr = JSON(localData!.fitSelectedPgList).toString()
        if profileData!.isChanged || localData?.profileDataJSON == nil {
            isProfileChanged = true
            localData?.profileDataJSON = JSON(profileData!.toDictionary())
        }
        // 健診データ
        localData!.examResultData = JSON(examResults!)
        localData!.delExamResultData = JSON(delExamResultDic)
        
//        print("fitbit storage date:" + JSON(localData!.storageDate["Fitbit"] as! NSDictionary).toString())
//        print("healthKit storage date:" + JSON(localData!.storageDate["HealthKit"] as! NSDictionary).toString())
        
        // 日記データ
        localData!.saveDayNoteData()
        
        // FreeStyleLibreデータ
        if self.hasDeviceFsl == true {
            localData!.saveFSLData()
        }
        
        let json = JSON((localData!.toDictionary())!)
//        Defaults[.localData] = json.toString().data(using: .utf8)
//        Defaults[.localData] = json.toString()
        DB.store[ProcessDataManager.LOCAL_STORAGE_KEY] = json.toString()

        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " Local save is success!")

        // データクラウド同期
//        initGroup!.notify(queue: .global(qos: DispatchQoS.QoSClass.background)) { () -> Void in
        if !isNewUser {
            TransDataManager.sharedInstance.transAllData()
//            // TEST CODE
//            TransDataManager.sharedInstance.isRuning = false
        }
//        }
    }
    
    func localRead() -> Bool {
//        let n : Notification = Notification(name: Notification.Name(rawValue: "StartProcess"), object: self, userInfo: ["action":"localRead"])
//                NotificationCenter.default.post(n)
        
        var result: Bool = false
//        let defaults = NSUserDefaults.standardUserDefaults();
//        pgUID = nil

//        let json = JSON(defaults.dictionaryForKey(ProcessDataManager.LOCAL_STORAGE_KEY)!)
//        let data = defaults.objectForKey(ProcessDataManager.LOCAL_STORAGE_KEY)
        var data: String? = nil
//        if let ld = Defaults[.localData] {
        data = DB.store[ProcessDataManager.LOCAL_STORAGE_KEY]
//        if ld != nil && ld != "" {
////            data = String(data:ld, encoding: .utf8)
//            data = ld
//        }
//        var oldOpenId = Defaults[.openAmOpenID];
//        if data != nil && oldOpenId == nil {
        if data != nil && data != "" {
//            installStartFlg = false
            let json = JSON.parse(data!)
//            print(CommUtil.date2string(NSDate(), format: "yyyy-MM-dd HH:mm:ss")! + " localData create start")
            localData = LocalData(json: json)
            pgUID = localData?.pgUID
            // データが正しく保存されていない場合
            if localData!.memberSinceHealthKit == nil {
                installStartFlg = true
            }
            
//            dispatch_group_enter(initGroup!)
//            dispatch_group_async(initGroup!, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in

            initDatasFromStorage()
            

//            }
//                dispatch_group_leave(initGroup!)
//            }

            result = true
        } else {
            // 新規インストール
            DB.store["fix-223"] = "fixed"   // ver2.2.3不具合修正
//            installStartFlg = true
//            Defaults.remove(.openAmOpenID)
            pgUID = UUID().uuidString
            localData = LocalData()
            localData!.pgUID = pgUID
            _allStorageData = [:]
            localData!.healthcareData = makeAllStorageData()
            
            // 初期設定は同期項目を全てONにする
            configManager!.fbStepSaveFlg = true
            configManager!.fbHeartSaveFlg = true
            configManager!.fbSleepSaveFlg = true
            configManager!.fbCaloliSaveFlg = true
            configManager!.fbDistanceSaveFlg = true
            
            configManager!.xmStepSaveFlg = true
            configManager!.xmHeartSaveFlg = true
            configManager!.xmSleepSaveFlg = true
            configManager!.xmCaloliSaveFlg = true
            configManager!.xmDistanceSaveFlg = true
            
            configManager!.profileSaveFlg = true
            configManager!.dayNoteSaveFlg = true
            configManager!.examResultSaveFlg = true
            // profileDataは初期Profile画面表示する時、作成
            // self.profileData = ProfileData()
            
            // デフォルトはAUTOモードを有効にする
            autoModeFlg = true
        }
        
        // TODO : ファイルから読込
        var animeSet = AnimeSet()
        animeSet.animeName = "yoshida"
        animeSet.fileCount = 6
//        animeSet.showDay = 1
        animeSets![animeSet.animeName!] = animeSet
        
        animeSet = AnimeSet()
        animeSet.animeName = "honda"
        animeSet.fileCount = 6
//        animeSet.showDay = 2
        animeSets![animeSet.animeName!] = animeSet
        
        animeSet = AnimeSet()
        animeSet.animeName = "ogata"
        animeSet.fileCount = 6
//        animeSet.showDay = 3
        animeSets![animeSet.animeName!] = animeSet
        
        animeSet = AnimeSet()
        animeSet.animeName = "ikyu"
        animeSet.fileCount = 6
//        animeSet.showDay = 4
        animeSets![animeSet.animeName!] = animeSet
        
        animeSet = AnimeSet()
        animeSet.animeName = "moshi"
        animeSet.fileCount = 6
//        animeSet.showDay = 5
        animeSets![animeSet.animeName!] = animeSet
        
        animeSet = AnimeSet()
        animeSet.animeName = "desca"
        animeSet.fileCount = 6
//        animeSet.showDay = 6
        animeSets![animeSet.animeName!] = animeSet
        
        animeSet = AnimeSet()
        animeSet.animeName = "bee"
        animeSet.fileCount = 6
//        animeSet.showDay = 7
        animeSets![animeSet.animeName!] = animeSet
        
        // 10/5 コンテンツ追加
        animeSet = AnimeSet()
        animeSet.animeName = "dosto"
        animeSet.fileCount = 6
        animeSet.extName = ".jpg"
        animeSets![animeSet.animeName!] = animeSet
        
        animeSet = AnimeSet()
        animeSet.animeName = "frank"
        animeSet.fileCount = 6
        animeSet.extName = ".jpg"
        animeSets![animeSet.animeName!] = animeSet
        
        animeSet = AnimeSet()
        animeSet.animeName = "goe"
        animeSet.fileCount = 6
        animeSet.extName = ".jpg"
        animeSets![animeSet.animeName!] = animeSet
        
        animeSet = AnimeSet()
        animeSet.animeName = "kant"
        animeSet.fileCount = 6
        animeSet.extName = ".jpg"
        animeSets![animeSet.animeName!] = animeSet
        
        animeSet = AnimeSet()
        animeSet.animeName = "mac"
        animeSet.fileCount = 6
        animeSet.extName = ".jpg"
        animeSets![animeSet.animeName!] = animeSet
        
        animeSet = AnimeSet()
        animeSet.animeName = "masa"
        animeSet.fileCount = 6
        animeSet.extName = ".jpg"
        animeSets![animeSet.animeName!] = animeSet
        
        animeSet = AnimeSet()
        animeSet.animeName = "mau"
        animeSet.fileCount = 6
        animeSet.extName = ".jpg"
        animeSets![animeSet.animeName!] = animeSet
        
        animeSet = AnimeSet()
        animeSet.animeName = "pro"
        animeSet.fileCount = 6
        animeSet.extName = ".jpg"
        animeSets![animeSet.animeName!] = animeSet
        
        animeSet = AnimeSet()
        animeSet.animeName = "shake"
        animeSet.fileCount = 6
        animeSet.extName = ".jpg"
        animeSets![animeSet.animeName!] = animeSet
        
        animeSet = AnimeSet()
        animeSet.animeName = "temp"
        animeSet.fileCount = 6
        animeSet.extName = ".jpg"
        animeSets![animeSet.animeName!] = animeSet
        
        glucoseLimitHighVal = (configManager!.glsLimitHighVal == 0) ? 110 : configManager!.glsLimitHighVal
        glucoseLimitLowVal = (configManager!.glsLimitLowVal == 0) ? 70 : configManager!.glsLimitLowVal
        
        return result
    }
    
    // AWS更新用DateFlg作成
    func makeNewAwsDateFlg(_ kind: String, path: String, awsDateFlg: String) -> String {
        var result: String = awsDateFlg
        var procDates:[String:String] = localData!.storageDate[kind] as! [String:String]
        
        if procDates.count == 0 {
            return "";
        }
        
        var baseDateFlg: String = procDates[path]!
//        if baseDateFlg.characters.count < 100 {
//            baseDateFlg = "11111111111111111111110"
//        }
        if baseDateFlg.characters.count > result.characters.count {
            let interVal = baseDateFlg.characters.count - result.characters.count
//            let subStr =  NSString(format: "%0" + String(interVal) + "d", 0) as String
            let subStr = CommUtil.get0String(interVal)
            result = result + subStr
        }
        let baseArray = baseDateFlg.characters.map { String($0) }
        var resultArray = result.characters.map { String($0) }
        for i in 0..<baseArray.count {
            if baseArray[i] > resultArray[i] {
                resultArray[i] = "1"
            }
        }
        result = resultArray.joined(separator: "")
        
        return result
    }
    
    // AWS更新用DateFlg作成2(datesにより、awsDateFlgを更新して戻す)
    func makeNewAwsDateFlg2(_ dates: [String:String], sinceDay: String, awsDateFlg: String) -> String {
        var baseDateFlg: String = awsDateFlg
        var baseArray = baseDateFlg.characters.map { String($0) }
        var uptDateIdxs: [String:String] = [:]
        
        let fromDay = CommUtil.string2date(sinceDay, format: "yyyy-MM-dd")
        for (day,_) in dates {
            let toDay = CommUtil.string2date(day, format: "yyyy-MM-dd")
            let idx = CommUtil.getDateInterVal(fromDay!, toDate: toDay!)
            uptDateIdxs[String(idx)] = "1";
        }
        
        for i in 0..<baseArray.count {
            if uptDateIdxs[String(i)] != nil {
                baseArray[i] = "1"
            }
        }
        let result = baseArray.joined(separator: "")
        
        return result
    }
    
    // ヘルスケアデータ送信対象日取得
    // ["meisai": [String:String], "sumary": [String:String]]
    func getTransDataDates(_ kind: String, path: String, awsDateFlg: String) -> [String:[String:String]] {
        var result: [String:String] = [:]
        var sumret: [String:String] = [:]
        var procDates:[String:String] = localData!.storageDate[kind] as! [String:String]
        if procDates.count == 0 {
            return [:]
        }
        var baseDateFlg: String = procDates[path]!
//        if baseDateFlg.characters.count < 100 {
//            baseDateFlg = "11111111111111111111110"
//        }
        var compDateFlg: String = awsDateFlg
        var sinceDay: String = ""
        var toDay: String = CommUtil.date2string(Date(), format: "yyyy-MM-dd")!
        var interVal: Int = 0
        
        if kind == "Fitbit" {
            sinceDay = localData!.memberSinceFitbit!
            if fitbitManager?.lastSyncDay != nil && fitbitManager?.lastSyncDay != "" {
                toDay = fitbitManager!.lastSyncDay!
                interVal = localData!.getProcDayInterVal(kind, kind2: path, procDate: toDay)
            }
        } else {
            sinceDay = localData!.memberSinceHealthKit!
            interVal = localData!.getProcDayInterVal(kind, kind2: path, procDate: toDay)
        }
        
        if baseDateFlg.characters.count <= interVal {
//            let subStr =  NSString(format: "%0" + String(interVal - baseDateFlg.characters.count + 1) + "d", 0) as String
            let subStr = CommUtil.get0String(interVal - baseDateFlg.characters.count + 1)
            baseDateFlg = baseDateFlg + subStr
            
            procDates[path] = baseDateFlg
            localData!.storageDate[kind] = procDates as Any
        }
        if compDateFlg.characters.count <= interVal {
//            let subStr =  NSString(format: "%0" + String(interVal - compDateFlg.characters.count + 1) + "d", 0) as String
            let subStr = CommUtil.get0String(interVal - compDateFlg.characters.count + 1)
            compDateFlg = compDateFlg + subStr
        }
        
        // DateFlgが同じの場合、システム日付のみを対象となる
        if baseDateFlg == compDateFlg {
            result[toDay] = "0"
            sumret[toDay] = "0"
        } else {
            let baseArray = baseDateFlg.characters.map { String($0) }
            let compArray = compDateFlg.characters.map { String($0) }
            
            for i in 0..<baseArray.count {
                // ローカル未送信分の日付を追加
                if i<compArray.count && baseArray[i] > compArray[i] {
                    let objDay = CommUtil.getDayFromBaseDay(sinceDay, interVal: i)
                    result[objDay] = "0"
                }
            }
            // 当日を必ず送信
            result[toDay] = "0"
            
            // 最後送信日を統計データの送信開始日とする
            for i in 0..<compArray.count {
                let descIdx = compArray.count - 1 - i
                if compArray[descIdx] > "0" {
                    let objDay = CommUtil.getDayFromBaseDay(sinceDay, interVal: descIdx)
                    sumret[objDay] = "0"
                    break
                }
            }
            if sumret.count == 0 {
//                sumret[toDay] = "0"
                sumret[sinceDay] = "0"
            }
        }
        
        return ["meisai":result, "sumary":sumret]
    }
    
    // デバイスデータ取得対象開始日を取得
    func getStartDate(_ kind: String, path: String) -> String {
        var retDate: String = ""
        let pathDates = localData?.storageDate[kind] as! [String:String]
        let checkArr: [String] = pathDates[path]!.characters.map { String($0) }
        var idx: Int = 0
        
        for i in 0..<checkArr.count {
            if checkArr[i] == "0" {
                idx = i
                break
            }
        }
        
        if kind == "Fitbit" {
            if idx == 0 {
                retDate = localData!.memberSinceFitbit!
            } else {
                let sinceDate = CommUtil.string2date(localData!.memberSinceFitbit!, format: "yyyy-MM-dd")
                let date = Date(timeInterval: 60 * 60 * 24 * Double(idx), since: sinceDate!)
                retDate = CommUtil.date2string(date, format: "yyyy-MM-dd")!
            }
        } else {
            if idx == 0 {
                retDate = localData!.memberSinceHealthKit!
            } else {
                let sinceDate = CommUtil.string2date(localData!.memberSinceHealthKit!, format: "yyyy-MM-dd")
                let date = Date(timeInterval: 60 * 60 * 24 * Double(idx), since: sinceDate!)
                retDate = CommUtil.date2string(date, format: "yyyy-MM-dd")!
            }
        }
        return retDate
    }
    
    func getNewHealthcareData(_ getDataKBN: Int, getFBmeisai: Bool, completionHandler: @escaping ( Bool ) -> Void) {
//    func getNewHealthcareData(getFBmeisai: Bool, completionHandler: ( flg: Bool ) -> Void) {
        if localData == nil {
            print("予想外エラー：LocalDataが存在していない！")
            completionHandler(false)
            return
        }
        
        if TransDataManager.sharedInstance.isRuning && self.firstStartupFlg == false {
            print("処理中止：データ取得中。。。")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                SwiftSpinner.hide()
            }
            completionHandler(false)
            return
        }
        TransDataManager.sharedInstance.isRuning = true;
        self.progressStart()
        
        let n : Notification = Notification(name: Notification.Name(rawValue: "DataTransformBegin"), object: self, userInfo: [:])
        NotificationCenter.default.post(n)
        
        let getFBFlg = (getDataKBN != AppConstants.GetDataKBN_HK) ? true : false
        let getHKFlg = (getDataKBN != AppConstants.GetDataKBN_FB) ? true : false
        var all_path: [String] = []
        
        all_path.append(HealthType.ActivitySteps["path"] as! String)
        all_path.append(HealthType.ActivityCalories["path"] as! String)
        all_path.append(HealthType.Sleep["path"] as! String)
        all_path.append(HealthType.Heart["path"] as! String)
        all_path.append(HealthType.ActivityDistance["path"] as! String)
        all_path.append(HealthType.Speed["path"] as! String)
        
        // path : 各デバイスデータ
        var newHealthData:[String: ActiveTypeRecord] = [:]
        for path in all_path {
            newHealthData[path] = ActiveTypeRecord(path: path)
        }
        
//        let queue:DispatchQueue = DispatchQueue.global(qos: .default)
        let queue = DispatchQueue(label: "get_data_que")
        let group:DispatchGroup = DispatchGroup()
        var periodStartDateFB: String?
        var periodStartDateHK: String?
        
        // Fitbit
        if fitbitManager!.loginFlg && getFBFlg {
            fitbitManager!.getMeisaiFlg = getFBmeisai
            let periodEndDateFB: String = fitbitManager!.lastSyncDay!
            
            // ①Steps
            // グループに 「+1」
            group.enter()
            queue.async(group: group) { [weak self] () -> Void in
                periodStartDateFB = self?.getStartDate("Fitbit", path: HealthType.ActivitySteps["path"] as! String)
            
                self?.fitbitManager!.getActivityTimeSeries(HealthType.ActivitySteps["Fitbit"]! as! String, dateParam1: periodStartDateFB!, dateParam2: periodEndDateFB) {
                    daySumItems in
                    
                    for items in daySumItems {
                        newHealthData[HealthType.ActivitySteps["path"] as! String]?.add(items)
                    }
//                    print("成功　Fitbit step data")
                    
                    // グループに 「-1」
                    group.leave()
                }
            }
            
            // ②カロリー
            // グループに 「+1」
            group.enter()
            queue.async(group: group) { [weak self] () -> Void in
                periodStartDateFB = self?.getStartDate("Fitbit", path: HealthType.ActivityCalories["path"] as! String)
            
                self?.fitbitManager!.getActivityTimeSeries(HealthType.ActivityCalories["Fitbit"]! as! String, dateParam1: periodStartDateFB!, dateParam2: periodEndDateFB) {
                    daySumItems in
                    
                    for items in daySumItems {
                        newHealthData[HealthType.ActivityCalories["path"] as! String]?.add(items)
                    }
//                    print("成功　Fitbit energy data")
                    
                    // グループに 「-1」
                    group.leave()
                }
            }

            // ③心拍率
            // グループに 「+1」
            group.enter()
            queue.async(group: group) { [weak self] () -> Void in
                periodStartDateFB = self?.getStartDate("Fitbit", path: HealthType.Heart["path"] as! String)
                
                self?.fitbitManager!.getActivityTimeSeries(HealthType.Heart["Fitbit"]! as! String, dateParam1: periodStartDateFB!, dateParam2: periodEndDateFB) {
                    daySumItems in
                    
                    for items in daySumItems {
                        newHealthData[HealthType.Heart["path"] as! String]!.add(items)
                        // 心拍率
//                        let dayItem = newHealthData[HealthType.Heart["path"] as! String]!.getDayItems("Fitbit")![items.day]
//                        if dayItem!.dayItems.count > 0 {
//                            dayItem!.sumValue = Double(Int(Int(dayItem!.sumValue) / dayItem!.dayItems.count))
//                        }
                        
                    }
//                    print("成功　Fitbit heartrate data")
                    
                    // グループに 「-1」
                    group.leave()
                }
            }
            
            // ④睡眠
            // グループに 「+1」
            group.enter()
            queue.async(group: group) { [weak self] () -> Void in
                periodStartDateFB = self?.getStartDate("Fitbit", path: HealthType.Sleep["path"] as! String)
            
                self?.fitbitManager!.getActivityTimeSeries((HealthType.Sleep["Fitbit"] as! String) + "/timeInBed", dateParam1: periodStartDateFB!, dateParam2: periodEndDateFB) {
                    daySumItems in
                    
                    for items in daySumItems {
                        newHealthData[HealthType.Sleep["path"] as! String]?.add(items)
                    }
//                    print("成功　Fitbit sleep data")
                    
                    // グループに 「-1」
                    group.leave()
                }
            }

            // ⑤距離
            // グループに 「+1」
            group.enter()
            queue.async(group: group) { [weak self] () -> Void in
                periodStartDateFB = self?.getStartDate("Fitbit", path: HealthType.ActivityDistance["path"] as! String)
            
                self?.fitbitManager!.getActivityTimeSeries(HealthType.ActivityDistance["Fitbit"]! as! String, dateParam1: periodStartDateFB!, dateParam2: periodEndDateFB) {
                    daySumItems in
                    
                    for items in daySumItems {
                        newHealthData[HealthType.ActivityDistance["path"] as! String]?.add(items)
                    }
//                    print("成功　Fitbit distance data")
                    
                    // グループに 「-1」
                    group.leave()
                }
            }

        }

        // HealthKit
        if healthkitManager!.loginFlg && getHKFlg {
            var semaphore = DispatchSemaphore(value: 0)
            
            // ①Steps
            // グループに 「+1」
            group.enter()
            queue.async(group: group) { [weak self] () -> Void in
                periodStartDateHK = self?.getStartDate("HealthKit", path: HealthType.ActivitySteps["path"] as! String)
                let startDate: Date = CommUtil.string2date(periodStartDateHK, format: "yyyy-MM-dd")!
                
                // 処理中ProgressBar
                if self!.initProcFlg == true {
                    if self!.installStartFlg == true {
                        self!.ini_progress = 0.0
                        self!.updateInitProgress(progress: 0.0, title: "歩数取得中")
                    } else {
//                        DispatchQueue.main.async {
//    //                        CommUtil.spinnerTimerFire(0.2, showStr: "歩数")
//                            SwiftSpinner.show(delay: 0.5, title:"歩数取得中", animated: true)
//                        }
                        self?.delay(seconds:0.5, completion: { [weak self] in
                            SwiftSpinner.show("歩数取得中", animated: true)
                        })
                    }
                }
                self!.healthkitManager!.producingCallback = { datacnt in
//                    ProcessDataManager.sharedInstance.updateInitProgress(progress: 0.05, title: "歩数取得中")
                    if self!.installStartFlg == true && self!.initProcFlg == true {
                        self!.updateInitProgress(progress: 0.02, title: "歩数取得中", totalcnt: datacnt)
                    }
                }
                
                self?.healthkitManager!.fetchActivity(HealthType.ActivitySteps["HealthKit"] as! HKQuantityTypeIdentifier, startDate: startDate, endDate: Date()) { daySumItems, success in
                    
                    if success {
//                        addIotDatas(HealthType.ActivitySteps["path"] as! String, datas: activityItems)
                        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + "    Add dayItems.")
                        
                        for ditem in daySumItems {
                            newHealthData[HealthType.ActivitySteps["path"] as! String]?.add(ditem)
                        }
                        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 成功　Health step data")
                        if self!.installStartFlg == true && self!.initProcFlg == true {
                            self!.updateInitProgress(progress: 0.1, title: "歩数取得中")
                        }
                        
                    } else {
                        print("失敗　Health step data is not existed")
                    }
                    // グループに 「-1」
                    group.leave()
                    semaphore.signal()
                }
                semaphore.wait()
            }
            
            // ②カロリー
            // グループに 「+1」
            semaphore = DispatchSemaphore(value: 0)
            group.enter()
            queue.async(group: group) { [weak self] () -> Void in
                periodStartDateHK = self?.getStartDate("HealthKit", path: HealthType.ActivityCalories["path"] as! String)
                let startDate: Date = CommUtil.string2date(periodStartDateHK, format: "yyyy-MM-dd")!
                
                if self?.initProcFlg == true {
//                    DispatchQueue.main.async {
//                        SwiftSpinner.show(delay: 0.5, title:"カロリー取得中", animated: true)
//                    }
                    self?.delay(seconds:0.5, completion: { [weak self] in
                        SwiftSpinner.show("カロリー取得中", animated: true)
                    })
                }
                self?.healthkitManager!.fetchActivity(HealthType.ActivityCalories["HealthKit"] as! HKQuantityTypeIdentifier, startDate: startDate, endDate: Date()) { daySumItems, success in
                    
                    if success {
//                        addIotDatas(HealthType.ActivityCalories["path"] as! String, datas: activityItems)
                        for ditem in daySumItems {
                            newHealthData[HealthType.ActivityCalories["path"] as! String]?.add(ditem)
                        }
                        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 成功　Health calorie data")
                        
                    } else {
                        print("失敗　Health calorie data is not existed")
                    }
                    // グループに 「-1」
                    group.leave()
                    semaphore.signal()
                }
                semaphore.wait()
                
            }
            
            // ③Sleep
            // グループに 「+1」
            semaphore = DispatchSemaphore(value: 0)
            group.enter()
            queue.async(group: group) { [weak self] () -> Void in
                periodStartDateHK = self?.getStartDate("HealthKit", path: HealthType.Sleep["path"] as! String)
                let startDate: Date = CommUtil.string2date(periodStartDateHK, format: "yyyy-MM-dd")!
                
                
//                let ss = getIotDatas(HealthType.Sleep["path"] as! String)
//                print("ss:\(ss.count)")
                if self?.initProcFlg == true {
//                    DispatchQueue.main.async {
//                        SwiftSpinner.show(delay: 0.5, title:"睡眠時間取得中", animated: true)
//                    }
                    self?.delay(seconds:0.5, completion: { [weak self] in
                        SwiftSpinner.show("睡眠時間取得中", animated: true)
                    })
                }
                self?.healthkitManager!.fetchCategory(HealthType.Sleep["HealthKit"] as! HKCategoryTypeIdentifier, startDate: startDate, endDate: Date()) { activityItems, success in
                    
                    if success {
//                        addIotDatas(HealthType.Sleep["path"] as! String, datas: activityItems)
                        for aitem in activityItems {
                            newHealthData[HealthType.Sleep["path"] as! String]?.addActItem(aitem)
                        }
                        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 成功　Health sleep data")
                        
                    } else {
                        print("失敗　Health sleep data is not existed")
                    }
                    // グループに 「-1」
                    group.leave()
                    semaphore.signal()
                }
                semaphore.wait()
                
            }
 
            // ④Heart
            // グループに 「+1」
            semaphore = DispatchSemaphore(value: 0)
            group.enter()
            queue.async(group: group) { [weak self] () -> Void in
                periodStartDateHK = self?.getStartDate("HealthKit", path: HealthType.Heart["path"] as! String)
                let startDate: Date = CommUtil.string2date(periodStartDateHK, format: "yyyy-MM-dd")!
                
//                let ss = getIotDatas(HealthType.Heart["path"] as! String)
//                print("ss:\(ss.count)")
                if self?.initProcFlg == true {
//                    DispatchQueue.main.async {
//                        SwiftSpinner.show(delay: 0.5, title:"心拍数取得中", animated: true)
//                    }
                    self?.delay(seconds:0.5, completion: { [weak self] in
                        SwiftSpinner.show("心拍数取得中", animated: true)
                    })
                }
                self?.healthkitManager!.fetchActivity(HealthType.Heart["HealthKit"] as! HKQuantityTypeIdentifier, startDate: startDate, endDate: Date()) { daySumItems, success in
                    
                    if success {
//                        addIotDatas(HealthType.Heart["path"] as! String, datas: activityItems)
                        for ditem in daySumItems {
                            newHealthData[HealthType.Heart["path"] as! String]?.add(ditem)
                        }
                        // 心拍率は平均値で更新する
                        for (_,v) in newHealthData[HealthType.Heart["path"] as! String]!.xiaomiDatas {
                            v.sumValue = Double(Int(v.sumValue / Double(v.dayItems.count)))
                        }
                        for (_,v) in newHealthData[HealthType.Heart["path"] as! String]!.iphoneDatas {
                            v.sumValue = Double(Int(v.sumValue / Double(v.dayItems.count)))
                        }
                        for (_,v) in newHealthData[HealthType.Heart["path"] as! String]!.applewatchDatas {
                            v.sumValue = Double(Int(v.sumValue / Double(v.dayItems.count)))
                        }
                        for (_,v) in newHealthData[HealthType.Heart["path"] as! String]!.otherDatas {
                            v.sumValue = Double(Int(v.sumValue / Double(v.dayItems.count)))
                        }
                        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 成功　Health heart-rates data")
                    } else {
                        print("失敗　Health heart-rates data is not existed")
                    }
                    // グループに 「-1」
                    group.leave()
                    semaphore.signal()
                }
                semaphore.wait()
                
            }
            
            // ⑤距離
            // グループに 「+1」
            group.enter()
            queue.async(group: group) { [weak self] () -> Void in
                periodStartDateHK = self?.getStartDate("HealthKit", path: HealthType.ActivityDistance["path"] as! String)
                let startDate: Date = CommUtil.string2date(periodStartDateHK, format: "yyyy-MM-dd")!
                
//                if self?.initProcFlg == true {
//                    self?.delay(seconds:0.5, completion: { [weak self] in
//                        SwiftSpinner.show("距離取得中", animated: true)
//                    })
//                }
                // 処理中ProgressBar
                if self!.initProcFlg == true {
                    if self!.installStartFlg == true {
                        self!.ini_progress = 0.0
                        self!.updateInitProgress(progress: 0.0, title: "距離取得中")
                    } else {
                        self?.delay(seconds:0.5, completion: { [weak self] in
                            SwiftSpinner.show("距離取得中", animated: true)
                        })
                    }
                }
                self!.healthkitManager!.producingCallback = { datacnt in
//                    ProcessDataManager.sharedInstance.updateInitProgress(progress: 0.05, title: "歩数取得中")
                    if self!.installStartFlg == true && self!.initProcFlg == true {
                        self!.updateInitProgress(progress: 0.02, title: "距離取得中", totalcnt: datacnt)
                    }
                }
                
                self?.healthkitManager!.fetchActivity(HealthType.ActivityDistance["HealthKit"] as! HKQuantityTypeIdentifier, startDate: startDate, endDate: Date()) { daySumItems, success in
                    
                    if success {
                        for ditem in daySumItems {
                            newHealthData[HealthType.ActivityDistance["path"] as! String]?.add(ditem)
                        }
                        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 成功　Health distance data")
                        if self!.installStartFlg == true && self!.initProcFlg == true {
                            self!.updateInitProgress(progress: 0.1, title: "距離取得中")
                        }
                        
                    } else {
                        print("失敗　Health distance data is not existed")
                    }
                    // グループに 「-1」
                    group.leave()
                }
            }
        }
        
        group.notify(queue: queue) { [weak self] () -> Void in
            if self?.localData?.dailyGoal == nil {
                self?.localData?.dailyGoal = ActivityGoal()
                // デフォルト値
                self?.localData?.dailyGoal?.steps = 10000
                self?.localData?.dailyGoal?.caloriesOut = 2000
                self?.localData?.dailyGoal?.distance = 8
            }
            
            self!.initGroup?.notify(queue: .global(qos: .background)) { [weak self] in
//                print("【Local】: " + JSON(_allStorageData![HealthType.Heart["path"] as! String]!.toDictionary()).toString())
//                print("【New Data】: " + JSON(newHealthData[HealthType.Heart["path"] as! String]!.toDictionary()).toString())
                if self!.initProcFlg == true {
//                    DispatchQueue.main.async {
//                        SwiftSpinner.show(delay: 0.5, title:"集計データ生成", animated: true)
//                    }
                    if self!.installStartFlg == true {
                        if  self!.initProcFlg == true {
                            self!.ini_progress = 0.0
                            self!.updateInitProgress(progress: 0.0, title: "集計データ生成")
                        }
                    } else if self!.initProcFlg == true {
                        DispatchQueue.main.async {
                            SwiftSpinner.show(delay: 0.5, title:"集計データ生成", animated: true)
                        }
                    }
                    print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 集計処理が準備します")
                }
                
                // デバイス別個別対応：小米の距離データ補足
                self?.addXiaomiDistanceData(healthData: newHealthData)
//                if self!.initProcFlg == true {
//                    self!.updateInitProgress(progress: 0.05, title: "集計データ生成")
                    print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 小米の距離データが補足完了")
//                }

                // 速度データ生成
                if self!.installStartFlg == true && self!.initProcFlg == true {
                    self!.updateInitProgress(progress: 0.02, title: "速度データ生成")
                }
                let distanceRecord = newHealthData[HealthType.ActivityDistance["path"] as! String]
                newHealthData[HealthType.Speed["path"] as! String] = self!.createSpeedRecord(by: distanceRecord!)
                
                // ロカール分に更新分を追加する（デバイス別）
                for path in all_path {
                    self?._allStorageData![path]?.addRec(newHealthData[path]!)
                }
                if self!.installStartFlg == true && self!.initProcFlg == true {
                    self!.updateInitProgress(progress: 0.01, title: "集計データ生成")
                }
//                newHealthData = [:]
                
                print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 日集計データ算出処理が始まります")
                print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 歩数")
                self?.calcDaySumItems(newHealthData[HealthType.ActivitySteps["path"] as! String]!)
                print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " カロリー")
                self?.calcDaySumItems(newHealthData[HealthType.ActivityCalories["path"] as! String]!)
                print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 睡眠")
                self?.calcDaySumItems(newHealthData[HealthType.Sleep["path"] as! String]!)
                print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 心拍率")
                self?.calcDaySumItems(newHealthData[HealthType.Heart["path"] as! String]!)
                print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 距離")
                self?.calcDaySumItems(newHealthData[HealthType.ActivityDistance["path"] as! String]!)
                print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 速度")
                self?.calcDaySumItems(newHealthData[HealthType.Speed["path"] as! String]!)
                print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " サマリー情報")
                
                self?.existDevices = self?.getExistDevices()
                
                if self?.currentDevice == nil || self?.currentDevice == "" {
                    if self?.existDevices!.count == 0 {
                        self?.currentDevice = "Fitbit"
                    } else {
//                        self?.currentDevice = self?.existDevices![0]
                        self?.currentDevice = "iPhone"
                    }
                    Defaults[.curtDevice] = (self?.currentDevice)!
                }
                if (self?.autoModeFlg)! {
                    self?.selectViewData("auto_mode")
                } else {
                    self?.selectViewData((self?.currentDevice)!)
                }
                if self?.installStartFlg == true && self?.initProcFlg == true {
                    self?.updateInitProgress(progress: 0.1, title: "集計データ生成")
                }
                
//                calcSummaryData()
                print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 日集計データ算出処理が終わりました")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    SwiftSpinner.hide()
                }

                DispatchQueue.main.async {() -> Void in
                    // 画面リフレッシュ通知を発行する
                    let n : Notification = Notification(name: Notification.Name(rawValue: "refresh"), object: self, userInfo: ["cmd": "refreshChart"])
                    //通知を送る
                    NotificationCenter.default.post(n)
                }
                
//                // TEST CODE: LAMBDAテストのため
//                TransDataManager.sharedInstance.isRuning = false
                // ローカルデータ更新
                self?.localSave()
                
                self?.progressFinish()
            }
        
            completionHandler(true)
        }
    }
    
    // Xiaomi距離データ作成処理
    fileprivate func addXiaomiDistanceData(healthData: [String: ActiveTypeRecord]) {
        let stepsRecord = healthData[HealthType.ActivitySteps["path"] as! String]!
        let distanceRecord = healthData[HealthType.ActivityDistance["path"] as! String]!
        
        if stepsRecord.xiaomiDatas.keys.count > 0 && distanceRecord.xiaomiDatas.keys.count == 0 {
            var stepLength = AppConstants.DefaultStepLength // Default: 0.7m
            
            if stepsRecord.iphoneDatas.keys.count > 0 && distanceRecord.iphoneDatas.keys.count > 0 {
                let sampleDate = stepsRecord.iphoneDatas.keys.first
                let steps1 = stepsRecord.iphoneDatas[sampleDate!]
                let distance1 = distanceRecord.iphoneDatas[sampleDate!]
                if steps1 != nil && steps1?.sumValue > 0 && distance1 != nil && distance1?.sumValue > 0 {
                    stepLength = round((distance1?.sumValue)! * 1000 * 100 / (steps1?.sumValue)!) / 100    // 1桁小数の歩長を求める
                }
                
                // Stepsデータより距離データを作る
                let chkVal = stepsRecord.xiaomiDatas.count / 5
                var icnt = 0
                for k in stepsRecord.xiaomiDatas.keys {
                    let sourceData = stepsRecord.xiaomiDatas[k]!
                    let distanceData = DaySumItem(path: HealthType.ActivityDistance["path"] as! String!
                                                , dev: "Xiaomi"
                                                , day: k )
                    distanceData.dayItems = [:]
                    for l in sourceData.dayItems.keys {
                        let item = sourceData.dayItems[l]!
                        let actItem: ActivityItem = ActivityItem()
                        if item.value > 0 {
                            actItem.startTime = item.startTime
                            actItem.endTime = item.endTime
                            actItem.deviceName = "Xiaomi"
                            actItem.value = round(item.value * stepLength) / 1000
                            
                            distanceData.addActItem(actItem)
                        }
                    }
                    distanceData.toStorageData(true)
                    distanceRecord.add(distanceData)
                    
                    icnt += 1
                    if chkVal != 0 && icnt % chkVal == 0 {
                        if self.installStartFlg == true && self.initProcFlg == true {
                            self.updateInitProgress(progress: 0.01, title: "集計データ生成")
                        }
                    }
                }

            }
        }
    }
    
//    func cloudSave() {
//    
//    }
//    
//    func cloudRead() {
//    
//    }

    func saveOAuth2Credential(_ serviceOpenID:String, accessToken:String, expiresAt:Date, refreshToken:String){
//        Defaults[.serviceOpenID] = serviceOpenID
//        Defaults[.accessToken] = accessToken
//        Defaults[.expiresAt] = CommUtil.date2string(expiresAt)!
        DB.store[AppConstants.ServiceOpenID] = serviceOpenID
        DB.store[AppConstants.AccessToken] = accessToken
        DB.store[AppConstants.ExpiresAt] = CommUtil.date2string(expiresAt)!
        
        print("refreshToken save:" + refreshToken)
//        Defaults[.refreshToken] = refreshToken
        DB.store[AppConstants.RefreshToken] = refreshToken
    }
    
    func saveFitBitOAuth2Credential(_ accessToken:String, expiresAt:Date, refreshToken:String){
        let expiresAtStr = CommUtil.date2string(expiresAt)!
//        Defaults[.accessTokenFitBit] = accessToken
//        Defaults[.expiresAtFitBit] = expiresAtStr
//        Defaults[.refreshTokenFitBit] = refreshToken
        DB.store[AppConstants.AccessTokenFitBit] = accessToken
        DB.store[AppConstants.ExpiresAtFitBit] = expiresAtStr
        DB.store[AppConstants.RefreshTokenFitBit] = refreshToken
        
        print("saveFitBitOAuth2Credential expiresAtFitBit:"+expiresAtStr);
    }
    
    func getOAuth2AccessToken() -> String{
        var accessTokenExpiresAtString = Defaults[.expiresAt]
        if accessTokenExpiresAtString == nil || accessTokenExpiresAtString == ""{
            accessTokenExpiresAtString = DB.store[AppConstants.ExpiresAt]!
        } else {
            DB.store[AppConstants.ExpiresAt] = accessTokenExpiresAtString
            DB.store[AppConstants.AccessToken] = Defaults[.accessToken]
            DB.store[AppConstants.RefreshToken] = Defaults[.refreshToken]
            Defaults.remove(.expiresAt)
            Defaults.remove(.accessToken)
            Defaults.remove(.refreshToken)
            
        }
        if accessTokenExpiresAtString != nil && accessTokenExpiresAtString != "" {
            let accessTokenExpiresAt = CommUtil.string2date(accessTokenExpiresAtString)
            if( accessTokenExpiresAt > Date()){
                let accessToken = DB.store[AppConstants.AccessToken]
                return accessToken!;
            }
        }
        
        return "";
    }
    
    func getServiceOpenID() -> String{
        var serviceOpenID = Defaults[.serviceOpenID]
        
        if serviceOpenID != nil && serviceOpenID != "" {
            DB.store[AppConstants.ServiceOpenID] = serviceOpenID
            Defaults.remove(.serviceOpenID)
            return serviceOpenID
        } else {
            serviceOpenID = DB.store[AppConstants.ServiceOpenID]!
            return serviceOpenID;
        }
    }
    
    func getOAuth2RefreshToken() -> String{
        let refreshToken = DB.store[AppConstants.RefreshToken]
        if refreshToken != nil {
            return refreshToken!
        } else {
            return "";
        }
    }
    
    func getFitBitOAuth2AccessToken() -> String{
        var accessTokenExpiresAtString = Defaults[.expiresAtFitBit]
        if accessTokenExpiresAtString == nil || accessTokenExpiresAtString == "" {
            accessTokenExpiresAtString = DB.store[AppConstants.ExpiresAt]!
        } else {
            DB.store[AppConstants.ExpiresAtFitBit] = accessTokenExpiresAtString
            DB.store[AppConstants.AccessTokenFitBit] = Defaults[.accessTokenFitBit]
            DB.store[AppConstants.RefreshTokenFitBit] = Defaults[.refreshTokenFitBit]
            Defaults.remove(.expiresAtFitBit)
            Defaults.remove(.accessTokenFitBit)
            Defaults.remove(.refreshTokenFitBit)
        }
        if accessTokenExpiresAtString != nil {
            print("getFitBitOAuth2AccessToken expiresAtFitBit:"+accessTokenExpiresAtString);
            let accessTokenExpiresAt = CommUtil.string2date(accessTokenExpiresAtString)
            if( accessTokenExpiresAt > Date()){
                let accessToken = DB.store[AppConstants.AccessTokenFitBit]
                return accessToken!;
            }
        }
        
        return "";
    }
    
    func getFitBitOAuth2AccessTokenExpiresAt() -> Date?{
        let accessTokenExpiresAtString = DB.store[AppConstants.ExpiresAtFitBit]
        if accessTokenExpiresAtString != nil && accessTokenExpiresAtString != ""{
            let accessTokenExpiresAt = CommUtil.string2date(accessTokenExpiresAtString)
            return accessTokenExpiresAt!;
        }
        
        return nil;
    }
    
    func getFitBitOAuth2RefreshToken() -> String{
        let refreshToken = DB.store[AppConstants.RefreshTokenFitBit]
        if refreshToken != nil {
            return refreshToken!
        } else {
            return "";
        }
    }
    
    // 定期Fitbit明細取得処理
    func addTimerGetFBMeisai(_ vc: UIViewController) {
        weak var viewControl = vc
        // 次の時間の頭に実行する
        let now = Date()
        let nextTime = Date(timeInterval: 3600, since: now)
        let tempStr = CommUtil.date2string(nextTime, format: "yyyy-MM-dd HH")
        let newNextTime = CommUtil.string2date(tempStr! + ":00:00")
        let interMinutes = CommUtil.getDateInterVal(now, toDate: newNextTime!, kbn: "m")
        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 間隔" + String(interMinutes) + "分")
        iotTimerOne = Timer.scheduledTimer(timeInterval: Double(interMinutes + 1) * 60, target: self, selector: #selector(ProcessDataManager.addTimerGetFBMeisai_Sub), userInfo: viewControl!, repeats: true)
//        iotTimerOne = Timer.scheduledTimer(timeInterval: Double(1 + 1) * 60, target: self, selector: #selector(ProcessDataManager.addTimerGetFBMeisai_Sub), userInfo: viewControl, repeats: true)
        
        if interMinutes > 1 && self.hasDeviceFb! == true {
            // 30秒後、先に実行する
            iotTimerOne2 = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(ProcessDataManager.timergetFitbitMeisai), userInfo: viewControl, repeats: true)
        }
    }
    
    // 定期Fitbit明細取得サブ処理
    func addTimerGetFBMeisai_Sub() {
        let viewCtl = iotTimerOne!.userInfo
        iotTimerOne!.invalidate()
        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " １回タイマー：TimerOne is called only one time.")
        // （3600+乱数）秒後実行
        let startSec = 3600 + arc4random_uniform(300 - 1) + 1
        iotTimerRpt = Timer.scheduledTimer(timeInterval: TimeInterval(startSec), target: self, selector: #selector(ProcessDataManager.timergetFitbitMeisai), userInfo: viewCtl, repeats: true)
        iotTimerRpt!.fire()
    }
    
    // 定期明細取得業務処理
    func timergetFitbitMeisai () {
        if TransDataManager.sharedInstance.isRuning {
            print("同期中で定期処理一時停止。")
            if iotTimerOne2 != nil {
                return;
            } else if iotTimerRpt != nil {
                // 30秒後、再実行をする
                let viewCtl1 : UIViewController = iotTimerRpt!.userInfo as! UIViewController
                iotTimerOne2 = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(ProcessDataManager.timergetFitbitMeisai), userInfo: viewCtl1, repeats: true)
            }
            return;
        }
        var viewCtl: UIViewController? = nil
        if iotTimerOne2 != nil {
            viewCtl = iotTimerOne2!.userInfo as! UIViewController
            iotTimerOne2!.invalidate()
            iotTimerOne2 = nil
            print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 初回明細データ取得.")
        } else {
            viewCtl = iotTimerRpt!.userInfo as! UIViewController
            print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " 定期タイマー：Timer repeat caled.")
        }
        
//            progressStart()
        self.fitbitManager!.login(viewCtl!, completionHandler: {
            loginFlg in
                
            DispatchQueue.global(qos: .background).async { [weak self] () -> Void in
                self?.getNewHealthcareData(AppConstants.GetDataKBN_FB, getFBmeisai: true, completionHandler: { (flg) in
                    if flg {
                        print("Meisai Data getted.")
                    } else {
                        print("Meisai Data get error.")
                    }
//                    progressFinish()
                })
            }
        })
    }

    // バージョンチェック
    func getNewVersion(curView: UIViewController) {
        HttpAPIManager.sharedInstance.checkVersion(self.appVersion, verKbn: AppConstants.VersionKbn, completionHandler: {
            [weak self] newFlg in
            
            if newFlg {
                let alertController = UIAlertController(title: "新バージョン検出", message: "新しいバージョンが見つかりました。今更新しますか？", preferredStyle: .alert)
            
                let cancelAction = UIAlertAction(title: "いいえ", style: .cancel, handler: { (action) in
                    print("バージョンアップグレードを取り消し")
                })
                alertController.addAction(cancelAction)
            
                let okAction = UIAlertAction(title: "はい", style: .destructive, handler: { [weak self] (action) in
                // 西中さんのところ遷移できないため、下記のロジックの問題を疑って、固定値に変更する（全社統合後、もう必要ないから）
//                    var appRealm = Defaults[.realm]
//                    appRealm = self!.Realm_Ext[appRealm]!
//                    let extNm = (appRealm == nil || appRealm == "") ? ".html" : "_" + appRealm + ".html"
                    var extNm = "adhoc.html"
//                    // テスト版の場合
//                    if AppConstants.VersionKbn == 2 {
//                        extNm = "test.html"
//                    }
                    let downloadUrl = AppConstants.ManagerServer + "/download/" + extNm

                    let url = URL(string: downloadUrl)!
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    } else {
                        UIApplication.shared.openURL(url)
                    }
                })
                alertController.addAction(okAction)
            
                curView.present(alertController, animated: true, completion: {})
            
            } else {
                print("現在のバージョンは最新です。")
            }
        })
    }
    
    // 機構リスト取得
    func getOrgList(_ completionHandler: () -> Void) {
        HttpAPIManager.sharedInstance.groupGetAllOrgList({
            jsonall in
            
            localData!.allOrgListData = []
            if let arr = jsonall["data"].asArray {
                for data0 in arr {
                    let data = data0.asDictionary!
                    let orgKind = (data["kind"]?.asString == nil ) ? "1" : data["kind"]!.asString!
                    let item = GroupOrg(imgName: data["id"]!.asString!,
                                        oName: data["orgName"]!.asString!,
                                        info: data["infoText"]!.asString!,
                                        kind: orgKind)
                    localData!.allOrgListData.append(item)
                }
                
                HttpAPIManager.sharedInstance.groupGetOrgList({
                    json in
                    
                    localData!.orgListData = []
                    if let arr = json["data"].asArray {
        //                procDataManager.localData!.orgListData = arr
                        
                        for data0 in arr {
                            let data = data0.asDictionary!
                            let orgKind = (data["kind"]?.asString == nil ) ? "1" : data["kind"]!.asString!
                            let item = GroupOrg(imgName: data["id"]!.asString!,
                                                oName: data["orgName"]!.asString!,
                                                info: data["infoText"]!.asString!,
                                                kind: orgKind)
                            localData!.orgListData.append(item)
                        }
                    }
                })
            }
            completionHandler();
        })
    }
    
    // 所属情報取得
    func getUserOrgInfo(_ completionHandler: () -> Void) {
        HttpAPIManager.sharedInstance.getUserOrgInfo ({
            json in
            
            if let orgInfo = json["data"].asDictionary {
                if let orgId = orgInfo["org_id"]?.asString {
                    self.userOrgID = orgId
                } else {
                    self.userOrgID = "other"
                }
                if let ensureKbn = orgInfo["kbn"]?.asString {
                    self.orgEnsureKbn = ensureKbn
                } else {
                    self.orgEnsureKbn = ""
                }
            } else {
                self.userOrgID = "other"
                self.orgEnsureKbn = ""
            }
            completionHandler()
        })
    }
    
    //
    func torokuOrgUser(_ orgId: String, nickName: String) {
        HttpAPIManager.sharedInstance.userOrgToroku(orgId, nickName: nickName, completionHandler: {
                (result) -> Void in
            
                print(result)
            })
    }
    
    // フォローリスト取得
    func getFollowedList(_ getPicFlg: Bool = false) {
        
        HttpAPIManager.sharedInstance.groupGetFollowedList({
            json in
            
            if let arr = json["data"].asArray {
//                procDataManager.localData!.orgListData = arr
                localData!.followedListData = []
                localData!.followedTable = [:]
                for data in arr {
                    
                    var msgStr: String?
                    var dateStr: String?
                    if let o = data[GroupManCollectionViewCell.CellMessageText].asString {
                        msgStr = String(data:o.data(using: .utf8)!, encoding: .utf8)    // shiftJIS
                    } else {
                        msgStr = ""
                    }
                    if let o = data[GroupManCollectionViewCell.CellDateText].asString {
                        if o == "" {
                            dateStr = ""
                        } else {
                            let dataDay = (o as NSString).substring(to: 8)
                            let time = (o as NSString).substring(with: NSRange(location: 8, length: 4))
                            if dataDay == CommUtil.date2string(Date(), format: "yyyyMMdd") {
                                dateStr = (time as NSString).substring(to: 2) + ":" + (time as NSString).substring(with: NSRange(location: 2, length: 2))
                            } else {
                                let date = CommUtil.string2date(o, format: "yyyyMMddHHmm")
                                dateStr = CommUtil.date2string(date, format: "yyyy-MM-dd")
                            }
                        }
                    } else {
                        dateStr = ""
                    }
                    
//                    let item = FollowedStaff(
//                            id: data[GroupManCollectionViewCell.CellImageName].asString!,
//                            userName: data[GroupManCollectionViewCell.CellUserName].asString!,
//                            organization: orgStr,
//                            messageText: msgStr!,
//                            dateText: dateStr!
//                        )
                    let item = FollowedStaff();
                    item.user_id = serviceOpenID!
                    item.messageText = msgStr!
                    item.dateText = dateStr!
                    
                    item.orgStaff.id = data["id"].asString!
                    item.orgStaff.img_id = data["imgID"].asString!
                    item.orgStaff.org_id = data["org_id"].asString!
                    item.orgStaff.organization = data["organization"].asString!
                    item.orgStaff.department = data["department"].asString == nil ? "" : data["department"].asString!
                    item.orgStaff.position = data["position"].asString == nil ? "" : data["position"].asString!
                    item.orgStaff.name = data["name"].asString!
                    item.orgStaff.gender = data["gender"].asString == nil ? "" : data["gender"].asString!
                    item.orgStaff.info1 = data["info1"].asString == nil ? "" : data["info1"].asString!
                    item.orgStaff.info2 = data["info2"].asString == nil ? "" : data["info2"].asString!
                    
                    localData!.addFollowData(item)
                }
            } else {
                localData!.followedListData = []
            }
            
            if getPicFlg {
                for data in localData!.followedListData! {
                    CommUtil.getGroupPNG(2, filename: data.orgStaff.img_id, reGetFlg: true)
                }
            }
        })
    }
    
    // FreeStyleLibreデータ取得
    func getFSLData() {
        var updateDate = ""
        if self.localData!.fslUpdateDateTime != nil && self.localData!.fslUpdateDateTime != "" {
            updateDate = self.localData!.fslUpdateDateTime!
        }
        AwsIoTAPIManager.sharedInstance.getGlucoseData("", toDay: "", updDay: updateDate, completionHandler: {
            [weak self] json in
            
            self!.localData!.saveFSLData(fslDataStr: json.toString())
            self!.makeFSLViewData()
        })
    }
    
    // フィットネスプログラムリスト取得
    func getFitPgList() {
        
        HttpAPIManager.sharedInstance.fitGetPgList({
            json in
            
            if let arr = json["data"].asArray {
//                procDataManager.localData!.orgListData = arr
                localData!.fitProgramListData = []
                for data0 in arr {
                    let data = data0.asDictionary!
                    let info = data["info"]!.asString == nil ? "" : data["info"]!.asString!
                    let picName = data["pic_name"]!.asString == nil ? "" : data["pic_name"]!.asString!
                    // 画像ダウンロード
                    if picName != "" {
                        CommUtil.getFitPGPNG(data["id"]!.asString!, forceDlFlg: true)
                    } else {
                        CommUtil.getFitPGPNG(data["id"]!.asString!)
                    }
                    
                    let unit = data["unit"]!.asString == nil ? "" : data["unit"]!.asString!
                    let item = FitnessProgram(id: data["id"]!.asString!, name: data["name"]!.asString!,
                                info: info, picName: picName, unit: unit)
                    
                    localData!.fitProgramListData.append(item)
                }
            } else {
                localData!.fitProgramListData = []
            }
        })
    }
    
    func saveDayNoteDataUpdated(_ dayNoteDataUpdated :[String : String]){
        var returnJSON : JSON? = nil
        
        if dayNoteDataUpdated.count > 0 {
            let noteDataUpdated = NSMutableDictionary()
            for (key, val) in dayNoteDataUpdated {
                noteDataUpdated[key as String] = val as String
            }
            
            returnJSON = JSON(noteDataUpdated)
        }

//        let noteDataUpdated = NSMutableDictionary()
//        returnJSON = JSON(noteDataUpdated)
        if returnJSON == nil {
            DB.store[AppConstants.dayNoteDataUpdated] = "{}"
//            Defaults[.dayNoteDataUpdated] = "{}"
        } else {
            DB.store[AppConstants.dayNoteDataUpdated] = (returnJSON?.toString())!
//            Defaults[.dayNoteDataUpdated] = (returnJSON?.toString())!
        }
    }
    
    func getDayNoteDataUpdated() -> [String : String]? {
        var dayNoteDataUpdatedString = Defaults.string(forKey: "dayNoteDataUpdated")
        if  dayNoteDataUpdatedString != nil && dayNoteDataUpdatedString != "" {
//        if let dayNoteDataUpdatedString = DB.store[AppConstants.dayNoteDataUpdated] {
            DB.store[AppConstants.dayNoteDataUpdated] = dayNoteDataUpdatedString
            Defaults.remove("dayNoteDataUpdated")
        } else {
            dayNoteDataUpdatedString = DB.store[AppConstants.dayNoteDataUpdated]
        
            let jsonDic = JSON.parse(dayNoteDataUpdatedString!)
            if jsonDic.isNull {return nil}
            if jsonDic.asDictionary == nil {return nil}

            var result: [String : String] = [:]
            
            for (day, val) in jsonDic {
                result[day as! String] = val.asString!
            }
            
            return result
        }
        
        return [:];
    }
    
//    func saveDayNoteData(_ dayNoteData :[String : String]){
//        var returnJSON : JSON?
//
//        if dayNoteData.count > 0 {
//            let noteData = NSMutableDictionary()
//            for (key, val) in dayNoteData {
//                noteData[key as String] = val as String
//            }
//
//            returnJSON = JSON(noteData)
//        }
//
//        let noteData = NSMutableDictionary()
//        returnJSON = JSON(noteData)
//        Defaults[.dayNoteData] = (returnJSON?.toString())!
//    }
//
//    func getDayNoteData() -> [String : DayNoteData]? {
//        if let dayNoteDataString = Defaults.string(forKey: "dayNoteData"){
//            let jsonDic = JSON(dayNoteDataString)
////            if jsonDic.isNull {return nil}
////            if jsonDic.asDictionary == nil {return nil}
////
////            var result: [String : String] = [:]
////
////            for (day, val) in jsonDic {
////                result[day as! String] = val.asString!
////            }
//
//            return result
//        }
//
//        return [:];
//    }

    func progressStart() {
        if iotTimerProgress != nil {
            iotTimerProgress?.invalidate()
            iotProgress = 0
        }
        OperationQueue.main.addOperation { [weak self] in
//            if let viewCtl = window?.rootViewController?.presentedViewController {
            if let viewCtl = self?.currentViewCtl {
                self?.iotTimerProgress = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ProcessDataManager.progressUp), userInfo: viewCtl, repeats: true)
            }
        }
    }
    
    func progressFinish() {
        OperationQueue.main.addOperation { [weak self] in
            sleep(2)
            if self?.iotTimerProgress != nil {
                self?.iotTimerProgress!.invalidate()
                self?.iotTimerProgress = nil
            }
            
            self?.iotProgress = 0
            if let viewCtl = self?.currentViewCtl {
                viewCtl.navigationController?.finishProgress()
            }
        }
    }

    func progressUp() {
        if iotProgress >= 1.0 {
            if iotTimerProgress != nil {
                iotTimerProgress?.invalidate()
                iotTimerProgress = nil
            }
            return
        }
        
        if let viewCtl = currentViewCtl {
            if let naviCtl = viewCtl.navigationController {
                naviCtl.progressTintColor = UIColor.hexStr("F16046", alpha: 1.0)
                naviCtl.progressHeight = 3
                iotProgress = iotProgress + 0.2
                naviCtl.setProgress(iotProgress, animated: true)
            }
        }
    }
    
    func progressCancel() {
        if let viewCtl = currentViewCtl {
            if let naviCtl = viewCtl.navigationController {
                naviCtl.cancelProgress()
            }
        }
    }
    
    // 以下は初期起動のProgressBar処理
    var ini_progress = 0.0
    func delay(seconds: Double, completion: @escaping () -> ()) {
        let popTime = DispatchTime.now() + Double(Int64( Double(NSEC_PER_SEC) * seconds )) / Double(NSEC_PER_SEC)
        
        DispatchQueue.main.asyncAfter(deadline: popTime) {
            completion()
        }
    }
    // progress: 0.0〜1.0
    func updateInitProgress(progress: Double, title: String, totalcnt: Int = 0) {
        // Clean install以外は表示しない
        if self.installStartFlg == false {
            return
        }
        
        self.ini_progress = self.ini_progress + progress
        if self.ini_progress > 1 {
            self.ini_progress = 1.0
        }
        let titalTxt = (totalcnt == 0) ? "最初の起動はすこし時間が掛かります。しばらくお待ちください。"
                                       : "該当データ：　\(totalcnt) 件\n最初の起動はすこし時間が掛かります。しばらくお待ちください。"
        self.delay(seconds: 0.5, completion: { [weak self] in
            SwiftSpinner.show(progress: self!.ini_progress, title: title + "\n\(Int(self!.ini_progress * 100))% completed").addTapHandler({
                print("tapped")
//                    SwiftSpinner.hide()
            }, subtitle: titalTxt)

        })
    }
    
}

extension DefaultsKeys {
    static let realm = DefaultsKey<String>("Realm")
    static let orgEnsureKbn = DefaultsKey<String>("OrgEnsureKbn")
    static let curtDevice = DefaultsKey<String>("curtDevice")
    static let autoModeFlg = DefaultsKey<Bool>("autoModeFlg")
    static let dayNoteDataUpdated = DefaultsKey<String>("dayNoteDataUpdated")
    
    // LevelDBに変わるキー（廃棄する）
//    static let localData = DefaultsKey<Data?>(ProcessDataManager.LOCAL_STORAGE_KEY)
    static let localData = DefaultsKey<String?>(ProcessDataManager.LOCAL_STORAGE_KEY)
    static let dayNoteData = DefaultsKey<String>("dayNoteData")
    static let serviceOpenID = DefaultsKey<String>("serviceKOpenID")
//    static let openAmOpenID = DefaultsKey<String>("serviceOpenID")
    static let accessToken = DefaultsKey<String>("accessKToken")
    static let expiresAt = DefaultsKey<String>("expiresKAt")
    static let refreshToken = DefaultsKey<String>("refreshKToken")
    
    static let accessTokenFitBit = DefaultsKey<String>("accessTokenFitBit")
    static let expiresAtFitBit = DefaultsKey<String>("expiresAtFitBit")
    static let refreshTokenFitBit = DefaultsKey<String>("refreshTokenFitBit")
}

extension UserDefaults {
    subscript(key: DefaultsKey<[String:ActivityItem]?>) -> [String:ActivityItem]? {
        get {
            return unarchive(key)
        }
        set {
            archive(key, newValue)
        }
    }
}
