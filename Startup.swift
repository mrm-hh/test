//
//  Startup.swift
//  IotProject
//
//  Created by 黄海 on 2016/08/10.
//  Copyright © 2016年 黄海. All rights reserved.
//

import UIKit

class Startup: UIViewController, UISplitViewControllerDelegate {
    
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    
    var window: UIWindow?
    var tabbarController: UITabBarController?
//    var navigationController: UINavigationController?
    
    weak var AWSViewController: UINavigationController?
    weak var AnalyzeViewController: UINavigationController?
    weak var ProfileViewController: UINavigationController?
    weak var DayInfoViewController: UINavigationController?
    weak var GroupViewController: UINavigationController?
    
    var storyboard1: UIStoryboard?
    var storyboard2: UIStoryboard?
    var storyboard3: UIStoryboard?
    var storyboard4: UIStoryboard?
    var storyboard5: UIStoryboard?
    
    let procDataManager = ProcessDataManager.sharedInstance
    let healthkitManager = HealthKitAPIManager.sharedInstance
    let fitbitManager = FitbitAPIManager.sharedInstance
    let httpAPIManager = HttpAPIManager.sharedInstance
    weak var mqttManager = AwsIoTAPIManager.sharedInstance
    let configManager = ConfigManager.sharedInstance

    var iotSplitViewController : UISplitViewController?
    let spinnerScroll = UIActivityIndicatorView()
    
    // 画面起動の初回目処理
    var firstProcFlg: Bool = true
    var isProfileMQTTConnected = false
    var isWaitProfileCallBack = false
    var isRefreshProfileFinished = false
    var isWaitProfileInput = false
    var nextProcFlg:Bool = true
    var showMainWindowFlg: Bool = false
    var isSysAuthOK = false
    
    var isDebug_UserProfile_Sync = true
    var isDebug_DayNote_Sync = true
    var isDebug_OpenAM = true
    var isDebug_Fitbit = true
    
    var startAlert: UIAlertController? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        procDataManager.initProcFlg = true
        procDataManager.initSendMinCheckDate = CommUtil.date2string(Date(), format: "yyyy")! + "-01-01"
        showVersion()
        initMainEntry()
        mqttManager?.Initialize()
        
        /// TODO:
//        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Startup.refreshStatus(_:)), name: "StartProcess", object: nil)
        
        if let nv = navigationController {
            nv.setNavigationBarHidden(true, animated: false)
        }
        
        // ActivityIndicatorを作成＆中央に配置
        spinnerScroll.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        spinnerScroll.center = self.view.center
        spinnerScroll.center.y = spinnerScroll.center.y - 20
        
        // クルクルをストップした時に非表示する
        spinnerScroll.hidesWhenStopped = true
        // 色を設定
        spinnerScroll.activityIndicatorViewStyle = .whiteLarge
        spinnerScroll.color = UIColor.white
        //Viewに追加
        self.view.addSubview(spinnerScroll)
    }
    
//    func refreshStatus(notification: NSNotification) {
//        print("refreshStatus");
//        if let action = notification.userInfo?["action"] as? String {
//            print("start process:" + action);
//        }
//    }
    fileprivate func showVersion() {
        let infoDictionary = Bundle.main.infoDictionary!
        // アプリバージョン情報
        let version = infoDictionary["CFBundleShortVersionString"]! as! String
        procDataManager.appVersion = version
        
        // ビルドバージョン情報
        let build = infoDictionary["CFBundleVersion"]! as! String

        versionLabel.text = "ver." + version
        if AppConstants.VersionKbn == 2 {
            infoLabel.text = "テスト版"
        } else {
            infoLabel.text = ""
        }
        
        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " " + version)
        print(build)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        procDataManager.currentViewCtl = self
        showIndicator()
        
//        // GPS情報取得
//        Location.getLocation(accuracy: .room, frequency: .oneShot, timeout: nil, success: {
//            (request, location) in
//                print("現在地を取得しました \(location)")
//                request.cancel()
//            }){ (request, last, error) in
//                print("Location get failed due to an error \(error)")
//            }
        
        if firstProcFlg && !procDataManager.isWaitOpenAMCallBack{
        // システムログイン処理
//            print(CommUtil.date2string(NSDate(), format: "yyyy-MM-dd HH:mm:ss")! + " システムログイン処理")
            if Defaults[.localData] != nil {
                DB.store[ProcessDataManager.LOCAL_STORAGE_KEY] = Defaults[.localData]!
//                DB.store[LocalData.dayNoteDataKey] = Defaults[LocalData.dayNoteDataKey].string
                Defaults.remove(.localData)
                if let dnData = Defaults[LocalData.dayNoteDataKey].string {
                    DB.store[LocalData.dayNoteDataKey] = dnData
                    Defaults.remove(LocalData.dayNoteDataKey)
                }
            }
            if DB.store[ProcessDataManager.LOCAL_STORAGE_KEY] != nil && DB.store[ProcessDataManager.LOCAL_STORAGE_KEY] != "" {
                self.procDataManager.installStartFlg = false
            } else {
                self.procDataManager.installStartFlg = true
            }
            
            // 会社判別
//            if Defaults[.realm] != "" {
//                // TODO: realm 読込み
//                print("Realm is : " + Defaults[.realm])
//            } else {
//                // TODO: 会社選択画面をPOPUP
//                let selectedRealm = AppConstants.Realm
//
//                Defaults[.realm] = (selectedRealm == "") ? "isc" : selectedRealm
//                print("Realm is : " + Defaults[.realm])
//            }
            if Defaults[.realm] != "" {
                print("Realm is : " + Defaults[.realm])
                let userRealm = Defaults[.realm]
                procDataManager.userOrgID = (userRealm == "isc") ? "intasect" : userRealm
                procDataManager.orgEnsureKbn = Defaults[.orgEnsureKbn]
            } else {
                print("Realm is :  ")
            }
            
            if !isDebug_OpenAM {
                print("仮ログイン")
                procDataManager.serviceOpenID = "aXBob25lLHRlc3Q="
//                    dispatch_async(dispatch_get_main_queue()) {() -> Void in
//                        SwiftSpinner.showWithDelay(0.5, title: "ローカルデータ読込中...", animated: true)
//                    }
                self.httpAPIManager.login((self.procDataManager.serviceOpenID)!)
                procDataManager.localRead()
//                    showMainWindowFlg = true
                firstProcFlg = false
                isSysAuthOK = true
                
                if self.procDataManager.userOrgID == nil {
                    // 所属取得
                    self.procDataManager.getUserOrgInfo({
                        [weak self] in
                        
                        Defaults[.realm] = (self?.procDataManager.userOrgID)!
                        Defaults[.orgEnsureKbn] = (self?.procDataManager.orgEnsureKbn)!
                        
                        self?.procDataManager.getOrgList({
                            [weak self] in
                            // AWSのユーザーProfile情報取得
                            self?.profileDataSync()
                        })
                    })
                } else {
                    self.procDataManager.getOrgList({
                        [weak self] in
                        // AWSのユーザーProfile情報取得
                        self?.profileDataSync()
                    })
                }
                
            } else {
                // OpenID ログイン  navigationController!
                procDataManager.isWaitOpenAMCallBack = true;
                CommUtil.appLogin(UIApplication.shared.topViewController!, completionHandler: { [weak self]
                    loginFlg in
//                        SwiftSpinner.showWithDelay(0.5, title: "ローカルデータ読込中...", animated: true)
                    self?.procDataManager.isWaitOpenAMCallBack = false;
                    self?.isSysAuthOK = loginFlg
                    if loginFlg {
                        // ①Groupサーバーと繋げる
                        self!.httpAPIManager.login((self?.procDataManager.serviceOpenID)!)
                        
                        // ②ローカルデータ読込み
                        self?.procDataManager.localRead()
//                            showMainWindowFlg = true
//                        // ②フィットネス項目取得
//                        self?.procDataManager.getFitPgList()
                        
                        if self?.procDataManager.userOrgID == nil {
                            // 所属取得
                            self?.procDataManager.getUserOrgInfo({
                                [weak self] in
                                
                                Defaults[.realm] = (self?.procDataManager.userOrgID)!
                                Defaults[.orgEnsureKbn] = (self?.procDataManager.orgEnsureKbn)!
                                // ③機構リスト取得
                                self?.procDataManager.getOrgList({
                                    [weak self] in

                                    // ③AWSのユーザーProfile情報取得
                                    self?.profileDataSync()
                                })
                            })
                        } else {
                            // ③機構リスト取得
                            self?.procDataManager.getOrgList({
                                [weak self] in

                                // ③AWSのユーザーProfile情報取得
                                self?.profileDataSync()
                            })
                        }
                        
                    }
                    self?.firstProcFlg = false
                    
                })
            }
        }
        
        if isWaitProfileInput {
            isWaitProfileInput = false;
            loginAfterGetOpenID()
        } else if nextProcFlg == false && !procDataManager.isFitbitCallBackFlg {
            // Fitbitログインをキャンセル
            DispatchQueue.main.async { [weak self] in

                if self?.procDataManager.serviceOpenID != nil {
    //                            print(CommUtil.date2string(NSDate(), format: "yyyy-MM-dd HH:mm:ss")! + "データ取得")
                        SwiftSpinner.show(delay: 0.5, title:"データ取得中...", animated: true)
                    
                    
                    if self?.procDataManager.localData?.dailyGoal == nil {
                        self?.procDataManager.localData!.dailyGoal = ActivityGoal()
                        // デフォルト値
                        self?.procDataManager.localData!.dailyGoal!.steps = 10000
                        self?.procDataManager.localData!.dailyGoal!.caloriesOut = 2000
                        self?.procDataManager.localData!.dailyGoal!.distance = 8
                    }
                    
                    DispatchQueue.global(qos: .default).async { [weak self] () -> Void in
                        self?.procDataManager.getNewHealthcareData(AppConstants.GetDataKBN_ALL, getFBmeisai: false, completionHandler: {
                            flg in

                            if !flg {
                                print("初期処理のデータ取得に失敗しました")
                            }
                            DispatchQueue.main.async {
                                SwiftSpinner.hide()
                            }
                            print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " Myhome 画面が表示される")
                        })
    //                            SwiftSpinner.hide()
                    }
                    self?.stopIndicator()
                    
                    let screen: CGRect = UIScreen.main.bounds
                    self?.window = UIWindow(frame: screen)
                    self?.window!.backgroundColor = UIColor.black
                    self?.window!.rootViewController = self?.tabbarController
                    self?.window!.makeKeyAndVisible()
                }
            }
        }  else {
            
            if procDataManager.installStartFlg == true {
                // システムログイン画面から戻ると実行する
                if firstProcFlg == false {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
    //                    if self!.procDataManager.installStartFlg == false {
    //                        return
    //                    }
                        // 30秒内、MQTT返信がなければ、エラーを出す
                        if self!.isProfileMQTTConnected == false {
                            if self!.startAlert != nil {
                                return
                            }
                            self!.startAlert = CommUtil.createAlertWithOnlyClose("通信タイムアウト", message: "クラウドに繋げません。しばらくしてからもう一度お試しください。")
                            self!.present(self!.startAlert!, animated: true, completion: nil)
                        }
    //                    self!.procDataManager.installStartFlg = false
                    }
                }
            } else {
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                    if self!.procDataManager.installStartFlg == true {
                        return
                    }
                    
                    // 認証画面からキャンセルした場合、エラーを出す
                    if self!.procDataManager.isWaitOpenAMCallBack {
                        let alert = CommUtil.createAlertWithOnlyClose("ログイン失敗", message: "アプリを終了させて、再起動してから再度お試しください。")
                        self!.present(alert, animated: true, completion: nil)
                        return
                    }
                    
                    // 10秒内、MQTT返信がなければ、ロカールデータで起動する
                    if self!.isProfileMQTTConnected == false {
                        self!.isRefreshProfileFinished = true
                    } else {
                        return
                    }
                    if self!.procDataManager.profileData == nil {
                        self!.procDataManager.profileData = ProfileData()
                    }
                    if let ctl = self!.procDataManager.currentViewCtl as? Startup {
                        print("MQTT返信がない。ローカル情報で起動する。")
                        DispatchQueue.main.async {
                            self?.loginAfterGetOpenID()
                        }
                    }
                }
                
            }
        }

        
//            if !showMainWindowFlg {
//                //print("システムログインに失敗しました")
//                return
//            } else {
//                //loginAfterGetOpenID()
//                profileDataSync()
//            }
        
    }
    
    fileprivate func profileDataSync(){
        print("=====start 最新データ取得=====")
//        let n : Notification = Notification(name: Notification.Name(rawValue: "StartProcess"), object: self, userInfo: ["action":"profileDataSync"])
//                NotificationCenter.default.post(n)
        
        if isDebug_UserProfile_Sync && !isWaitProfileCallBack {
            isWaitProfileCallBack = true

            let awsIoTManagerRefreshUserProfile : AwsIoTAPIManagerCommon =
                    MQTTClientFactory.sharedInstance.getInstance(.commonClient) as! AwsIoTAPIManagerCommon
            
            let localData = ProcessDataManager.sharedInstance.localData!
            var localUserProfileTimeStamp: String? = localData.storageDate["UserProfile"] as? String
            if localUserProfileTimeStamp == nil || localUserProfileTimeStamp == "" {
                localUserProfileTimeStamp = "20160101010101"
            }
            print("localUserProfileTimeStamp:"+localUserProfileTimeStamp!)
            
            awsIoTManagerRefreshUserProfile.loginAsyc( procDataManager.serviceOpenID! , callback: { [weak self] returnCode in
                if !((self?.isProfileMQTTConnected)!) {
                    self?.isProfileMQTTConnected = true
                } else {
                    print("=======login error=======")
                    return
                }

                if self!.isRefreshProfileFinished == true {
                    print("=== Get UserInfo from AWS is canceled. ===")
                    return
                }

                    awsIoTManagerRefreshUserProfile.sendData(
                        [
                            "actionType": "getUserProfile" as Any,
                            "day" : localUserProfileTimeStamp! as Any
                        ],
                        listener: IOTEventListener<JSON>( callback: { [weak self] sender, args in
                            if let last_upd_date = args?["last_upd_date"].asString {

                                if self?.procDataManager.localData == nil || self?.procDataManager.localData!.profileDataJSON == nil {
//                                    let queue:DispatchQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.default)
//                                    queue.sync { () -> Void in
                                        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " ===get exam result begin===")
                                        self?.procDataManager.examResults = []
                                        let url = HttpAPIManager.sharedInstance.domainUrl + "examresult/getAllIotExamResult/" + (self?.procDataManager.serviceOpenID)!
                                        print("get exam result get json begin")
                                        print("get exam result url" + url)
                                        let json = JSON(url:url)
                                        print("get exam result get json end")
                                        if json.asArray != nil {
                                            for exam in json.asArray! {
                                                var examData: [String: String] = [:]
                                                for (k,v) in exam.asDictionary! {
                                                    examData[k] = v.asString
                                                }
                                                print("get exam result add one")
                                                self?.procDataManager.examResults?.append(examData)
                                            }
                                            self?.procDataManager.examResults = self?.procDataManager.examUnique((self?.procDataManager.examResults)!)
                                            self?.procDataManager.examResults!.sort(by: (self?.procDataManager.examSort)!)
                                            print("get exam result save to local storage")
                                            self?.procDataManager.localData!.examResultData = json
                                        }
                                        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " ===get exam result end===")
//                                    }
                                }
                                if !last_upd_date.isEmpty && self!.procDataManager.installStartFlg == true {
                                    ProcessDataManager.sharedInstance.localData!.storageDate["UserProfile"]! = last_upd_date as Any
                                    ProcessDataManager.sharedInstance.localData?.profileDataJSON = args?["data"]
                                    ProcessDataManager.sharedInstance.localData?.makeFitSelectedPgList()

                                    ProcessDataManager.sharedInstance.profileData = ProfileData()
                                    ProcessDataManager.sharedInstance.profileData!.setValue((args?["data"])!)

                                    if let cloudSetting = args?["data"]["cloudSetting"].asString {
                                        self?.configManager.setValue(json: JSON.parse(cloudSetting))
                                    }

                                    ProcessDataManager.sharedInstance.setDeviceStatus()
                                }
                                if ProcessDataManager.sharedInstance.profileData == nil {
                                    ProcessDataManager.sharedInstance.profileData = ProfileData()
                                }

                            }
                            if !((self?.isRefreshProfileFinished)!) {
                                self?.isRefreshProfileFinished = true
                                DispatchQueue.main.async {
                                    self?.loginAfterGetOpenID()
                                }
                            }
                        })
                    )

            })
            
            
        } else {
            print("=====start loginAfterGetOpenID=====")
            loginAfterGetOpenID()
        }

    }
    
    fileprivate func loginAfterGetOpenID(){
        isWaitProfileCallBack = false
        
        print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " システムログイン正常終了")
        
        // システム認証を通じた場合
        if self.isSysAuthOK {
            // 初期インストールの場合、Profile画面を出す
            if procDataManager.localData == nil || procDataManager.localData!.profileDataJSON == nil
                || (procDataManager.localData!.profileDataJSON?["displayName"].asString == nil || procDataManager.localData!.profileDataJSON?["displayName"].asString == ""){
                isWaitProfileInput = true
//                firstProcFlg = false
                procDataManager.startupViewController = self
                if procDataManager.userOrgID == "other" {
                    procDataManager.userOrgID = ""
                    procDataManager.orgEnsureKbn = ""
                }
                weak var profileVC: UINavigationController?
                profileVC = storyboard4!.instantiateInitialViewController() as? UINavigationController
                
                present(profileVC!, animated: true, completion: nil)
                return
            }
        } else {
            let alert = CommUtil.createAlertWithOnlyClose("ログイン失敗", message: "アプリを終了させて、再起動してから再度お試しください。")
            self.present(alert, animated: true, completion: nil)
            return
        }
//        if firstProcFlg || procDataManager.firstStartupFlg {
//            firstProcFlg = false
        if nextProcFlg {
            if procDataManager.firstStartupFlg {
//                procDataManager.firstStartupFlg = false
                procDataManager.localRead()
            }
            nextProcFlg = false
            
            // メイン画面を表示する
            processInit(self,completionHandler: { [weak self] in
                //                SwiftSpinner.hide()
                
                let screen: CGRect = UIScreen.main.bounds
                self?.window = UIWindow(frame: screen)
                self?.window!.backgroundColor = UIColor.black
                self?.window!.rootViewController = self?.tabbarController
                self?.window!.makeKeyAndVisible()
            })
        }
//        print("起動画面表示")
    }
    
    fileprivate func initMainEntry() {
        storyboard1 = UIStoryboard(name: "Sokute", bundle: Bundle.main)
        storyboard2 = UIStoryboard(name: "Cloud", bundle: Bundle.main)
        storyboard3 = UIStoryboard(name: "Analyze", bundle: Bundle.main)
        storyboard4 = UIStoryboard(name: "Profile", bundle: Bundle.main)
        storyboard5 = UIStoryboard(name: "Group", bundle: Bundle.main)
        
        iotSplitViewController = storyboard1!.instantiateViewController(withIdentifier: "sokute-svc") as? UISplitViewController
        iotSplitViewController!.delegate = self
        
        AWSViewController = storyboard2!.instantiateInitialViewController() as? UINavigationController
        AnalyzeViewController = storyboard3!.instantiateInitialViewController() as? UINavigationController
        ProfileViewController = storyboard4!.instantiateInitialViewController() as? UINavigationController
        GroupViewController = storyboard5!.instantiateInitialViewController() as? UINavigationController
        
        tabbarController = UITabBarController()
        tabbarController!.viewControllers = [AnalyzeViewController!, iotSplitViewController!, GroupViewController!, AWSViewController!, ProfileViewController!]
        
        let tabbarItem = UITabBarItem(title: "ホーム", image: UIImage(named: "home"), selectedImage: UIImage(named: "home-selected"))
        AnalyzeViewController?.tabBarItem = tabbarItem
        let tabbarItem1 = UITabBarItem(title: "状況測定", image: UIImage(named: "energyburn"), selectedImage: UIImage(named: "energyburn-selected"))
        iotSplitViewController!.tabBarItem = tabbarItem1
        
        let tabbarItem2 = UITabBarItem(title: "同期設定", image: UIImage(named: "journal"), selectedImage: UIImage(named: "journal-selected"))
        AWSViewController?.tabBarItem = tabbarItem2
        let tabbarItem3 = UITabBarItem(title: "私の状態", image: UIImage(named: "profile"), selectedImage: UIImage(named: "profile-selected"))
        ProfileViewController?.tabBarItem = tabbarItem3
        let tabbarItem4 = UITabBarItem(title: "グループ", image: UIImage(named: "group"), selectedImage: UIImage(named: "group-selected"))
        GroupViewController?.tabBarItem = tabbarItem4
        procDataManager.groupTabBarItem = tabbarItem4
        
        tabbarController?.tabBar.tintColor = UIColor.hexStr("F16046", alpha: 1.0)
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    // MARK: process init
    func processInit(_ viewController: UIViewController, completionHandler: @escaping () -> Void) {
//        let n : Notification = Notification(name: Notification.Name(rawValue: "StartProcess"), object: self, userInfo: ["action":"processInit"])
//                NotificationCenter.default.post(n)
        
        let queue:DispatchQueue = DispatchQueue.global(qos: .default)
        let group:DispatchGroup = DispatchGroup()
        
        let localData = procDataManager.localData!
        
//        var localUserProfileTimeStamp: String? = localData.storageDate["UserProfile"] as? String
//        if localUserProfileTimeStamp == nil || localUserProfileTimeStamp == "" {
//            localUserProfileTimeStamp = "20160101010101"
//        }
        
        var localDayNoteTimeStamp: String? = localData.storageDate["DayNote"] as? String
        if localDayNoteTimeStamp == nil || localDayNoteTimeStamp == "" {
            localDayNoteTimeStamp = "2016-01-01 01:01:01"
        }
        
        get_url_handler()
        
        if isDebug_UserProfile_Sync || isDebug_DayNote_Sync {
            if procDataManager.firstStartupFlg == false &&
                (localData.dayNoteData == nil || localData.dayNoteData!.count == 0) {
                // グループに 「+1」
                group.enter()
                queue.async(group: group) { [weak self] () -> Void in
                    
                    var endFlag : Int = 0;
                    
                    var targetEndFlag : Int = 0;
                    
                    if (self?.isDebug_DayNote_Sync)! {
                        targetEndFlag = targetEndFlag + 1
                        
                        let awsIoTManagerRefreshDayNote : AwsIoTAPIManagerRefreshDayNoteData =
                            MQTTClientFactory.sharedInstance.getInstance(.dayNoteRefresh) as! AwsIoTAPIManagerRefreshDayNoteData

                        
                        awsIoTManagerRefreshDayNote.onReciveDataCallback = { returnData in
                            
                            endFlag = endFlag + 1
                            if endFlag == targetEndFlag {
                                // グループに 「-1」
                                group.leave()
                            }
                        }
                        
                        awsIoTManagerRefreshDayNote.loginAsyc( (self?.procDataManager.serviceOpenID)! , callback: { returnCode in
                            awsIoTManagerRefreshDayNote.getLastDayNoteData(localDayNoteTimeStamp!)
                        })
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                            if endFlag == targetEndFlag {
                                return
                            }
                            
                            if self!.procDataManager.installStartFlg == true {
                                // 新規インストールの場合、MQTT返信がなければ、エラーを出す
                                let alert = CommUtil.createAlertWithOnlyClose("通信タイムアウト", message: "クラウドに繋げません。しばらくしてからもう一度お試しください。")
                                self?.present(alert, animated: true, completion: nil)
                            } else {
                                // 30秒内、MQTT返信がなければ、待たないで起動する
                                print("AwsIoTManagerRefreshDayNote is timeout. System is starting.")
                                group.leave()
                            }
                        }
                    }
                }
            }
        }
  
        // ②各デバイスログイン
        // グループに 「+1」
        group.enter()
        queue.async(group: group) { [weak self] () -> Void in
        
//            // 20170111 デモ用追加対応（データ合算しないため）
//            if procDataManager.hasDeviceXm! {
        
                // APIでHealthkitにログインする
                self?.healthkitManager.authorizeHealthKit { (success, error) -> Void in
                    if !success {
                        print("Error : HealthCare権限取得失敗。 error : \(error?.localizedDescription)")
                        //                hkFlg = false
                    } else {
                        print("HealthCare権限取得成功")
                    }
                    // グループに 「-1」
                    group.leave()
                }
//            } else {
//                // グループに 「-1」
//                dispatch_group_leave(group)
//            }
        }
        
        // ③最新データ取得
        group.notify(queue: queue) { [weak self] () -> Void in
//            ProcessDataManager.sharedInstance.localSave()
            
            print("=====start 最新データ取得=====")
        
            if (self?.isDebug_UserProfile_Sync)! {
                print("awsIoTManagerRefreshUserProfile.close")
                let awsIoTManagerRefreshUserProfile : AwsIoTAPIManagerCommon =
                    MQTTClientFactory.sharedInstance.getInstance(.commonClient) as! AwsIoTAPIManagerCommon
                awsIoTManagerRefreshUserProfile.close();
//                self?.isRefreshProfileFinished = false
            }
            
            if (self?.isDebug_DayNote_Sync)! {
                let awsIoTManagerRefreshDayNote : AwsIoTAPIManagerRefreshDayNoteData =
                    MQTTClientFactory.sharedInstance.getInstance(.dayNoteRefresh) as! AwsIoTAPIManagerRefreshDayNoteData
                awsIoTManagerRefreshDayNote.close()
            }
        
//            if procDataManager.hasDeviceFb! {
//                print("TEST: fitbit login")
            // APIでFitbitにログインする
            self?.fitbitManager.login(viewController, completionHandler: {
                loginFlg in
                
                DispatchQueue.main.async { [weak self] in
    //                    if loginFlg {
    //                        print("OK!")
                    // ユーザーログインOK(サービスOPENID取得済)の場合、デバイスデータを取得
                    if self?.procDataManager.serviceOpenID != nil {
    //                            print(CommUtil.date2string(NSDate(), format: "yyyy-MM-dd HH:mm:ss")! + "データ取得")
                        SwiftSpinner.show(delay: 0.5, title:"データ取得中...", animated: true)
                        
                        if self?.procDataManager.localData?.dailyGoal == nil {
                            self?.procDataManager.localData!.dailyGoal = ActivityGoal()
                            // デフォルト値
                            self?.procDataManager.localData!.dailyGoal!.steps = 10000
                            self?.procDataManager.localData!.dailyGoal!.caloriesOut = 2000
                            self?.procDataManager.localData!.dailyGoal!.distance = 8
                        }
                                
                        DispatchQueue.global(qos: .default).async { [weak self] in
                            self?.procDataManager.getNewHealthcareData(AppConstants.GetDataKBN_ALL, getFBmeisai: false, completionHandler: {
                                flg in

                                if !flg {
                                    print("初期処理のデータ取得に失敗しました")
                                }
                                if self!.procDataManager.firstStartupFlg {
                                    self!.procDataManager.firstStartupFlg = false
                                }
//                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                                    SwiftSpinner.hide()
//                                }
                                
    //                                procDataManager.addTimerGetFBMeisai(viewController)
                                print(CommUtil.date2string(Date(), format: "yyyy-MM-dd HH:mm:ss")! + " Myhome 画面が表示される")
                            })
    //                            SwiftSpinner.hide()
                        }

                    }
                    completionHandler()
                    
                }
            })
            
//            self!.httpAPIManager.login((self?.procDataManager.serviceOpenID)!)
            
            if self?.procDataManager.localData!.allOrgListData.count == 0 {
                // 機構一覧取得
                self?.procDataManager.getOrgList({ })
            }
            // フォロー済一覧取得
            self?.procDataManager.getFollowedList()
            // フィットネス項目取得
            self?.procDataManager.getFitPgList()
            
            if self?.procDataManager.hasDeviceFsl == true {
                if DB.store[LocalData.fslKey] != nil && DB.store[LocalData.fslKey] != "" {
                    // グルコースデータ
                    self?.procDataManager.makeFSLViewData()
                } else {
                    self?.procDataManager.getFSLData()
                }
            }
            
//            completionHandler()
            
        }

    }

    fileprivate func showIndicator() {
        
//        self.view.bringSubview(toFront: self.spinnerScroll)
        self.spinnerScroll.startAnimating()
    }
    
    fileprivate func stopIndicator() {
        self.spinnerScroll.stopAnimating()
    }
    
    // MARK: - Split view
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
        guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
        guard let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController else { return false }
        if topAsDetailController.dataTitle == nil {
            // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
            return true
        }
        return false
    }

    // MARK: create an optionnal internal web view to handle connection
    func createWebViewController() -> WebViewController {
        let controller = WebViewController()
        return controller
    }
    
    func get_url_handler() -> OAuthSwiftURLHandlerType {
        // Create a WebViewController with default behaviour from OAuthWebViewController
        let url_handler = createWebViewController()
        return url_handler
    }
    
    
}
