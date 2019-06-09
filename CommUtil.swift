//
//  CommUtil.swift
//  IotProject
//
//  Created by インタセクト  on 2016/07/01.
//  Copyright © 2016年 黄海. All rights reserved.
//

import Foundation
import UIKit
import Photos
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

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func <= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l <= r
  default:
    return !(rhs < lhs)
  }
}


class CommUtil {
    static let dateFormatterYMD:DateFormatter = {
            let df = DateFormatter()
            df.locale     = Locale(identifier: "ja_JP")
            df.dateFormat = "yyyy-MM-dd"
            return df
        }()
    static let dateFormatterYMDhms:DateFormatter = {
            let df = DateFormatter()
            df.locale     = Locale(identifier: "ja_JP")
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return df
        }()
    static let dateFormatterhms:DateFormatter = {
            let df = DateFormatter()
            df.locale     = Locale(identifier: "ja_JP")
            df.dateFormat = "HHmmss"
            return df
        }()
    static let dateFormatterYMDhms2:DateFormatter = {
            let df = DateFormatter()
            df.locale     = Locale(identifier: "ja_JP") // ロケールの設定
            df.dateFormat = "yyyyMMddHHmmss"
            return df
        }()
    
    // 配列の中に０以外の一番小さい数字を抽出
    static func getMinExcept0(_ datas: [Double]) -> Double {
        var ret: Double = 0
        for data in datas {
            if data != 0 && ret == 0 {
                ret = data
                continue
            }
            if data != 0 && data < ret {
                ret = data
            }
        }
        return ret
    }
    
    // 文字列 -> 日付型
    static func string2date(_ date_string: String?, format: String = "yyyy-MM-dd HH:mm:ss") -> Date? {
        if date_string == nil || date_string == "" {return nil}
        
        let date_formatter: DateFormatter?
        if format == "yyyy-MM-dd" {
            date_formatter = CommUtil.dateFormatterYMD
        } else if format == "HHmmss" {
            date_formatter = CommUtil.dateFormatterhms
        } else if format == "yyyy-MM-dd HH:mm:ss" {
            date_formatter = CommUtil.dateFormatterYMDhms
        } else if format == "yyyyMMddHHmmss" {
            date_formatter = CommUtil.dateFormatterYMDhms2
        } else {
            date_formatter = DateFormatter()
            date_formatter!.locale = Locale(identifier: "ja_JP")
            date_formatter!.dateFormat = format
        }
        
        return date_formatter!.date(from: date_string!)
    }
    // 日付型 -> 文字列
    static func date2string(_ date: Date?, format: String = "yyyy-MM-dd HH:mm:ss") -> String? {
        if date == nil {return nil}
        
        let date_formatter: DateFormatter?
        if format == "yyyy-MM-dd" {
            date_formatter = CommUtil.dateFormatterYMD
        } else if format == "HHmmss" {
            date_formatter = CommUtil.dateFormatterhms
        } else if format == "yyyy-MM-dd HH:mm:ss" {
            date_formatter = CommUtil.dateFormatterYMDhms
        } else if format == "yyyyMMddHHmmss" {
            date_formatter = CommUtil.dateFormatterYMDhms2
        } else {
            date_formatter = DateFormatter()
            date_formatter!.locale = Locale(identifier: "ja_JP")
            date_formatter!.dateFormat = format
        }
        
        return date_formatter!.string(from: date!)
    }
    // 日付間の差(kbn(区分)：d(日)、h(時間)、m(分)、M(月)、4m(4分)、s(秒))
    static func getDateInterVal(_ fromDate: Date, toDate: Date, kbn: String = "d") -> Int {
        var ret: Int = 0
        var inter: Int = 0
        let timeOf1Day = 86400  // 60 * 60 * 24
        let timeOf1Hour = 3600  // 60 * 60
        let timeOf1Min = 60
        let timeOf4Min = 240
        let timeOf1Month = timeOf1Day * 30
        
        if kbn == "m" {
            inter = timeOf1Min
        } else if kbn == "4m" {
            inter = timeOf4Min
        } else if kbn == "h" {
            inter = timeOf1Hour
        } else if kbn == "M" {
            inter = timeOf1Month
        } else if kbn == "s" {
            inter = 1
        } else {
            inter = timeOf1Day
        }
        
        let time = toDate.timeIntervalSince(fromDate)
        ret = Int(time) / inter
        if kbn == "s" {
            ret += 1
        }
        return ret
    }
    // 指定日のn日後の日付取得　
    static func getDayFromBaseDay(_ baseDay: String, interVal: Int) -> String {
        let baseDate = string2date(baseDay, format: "yyyy-MM-dd")
        let newDate = Date(timeInterval: Double(86400 * interVal), since: baseDate!)
        
        return date2string(newDate, format: "yyyy-MM-dd")!
    }
    // 文字列０埋め（長さ510超え対応）
    static func get0String(_ cnt: Int) -> String {
        var ret = ""
        if cnt <= 510 {
            ret = String(format: "%0" + String(cnt) + "d", 0)
        } else if cnt > 510 {
            let max = cnt / 510
            for i in 1...max {
                ret += String(format: "%0" + String(510) + "d", 0)
            }
            ret += String(format: "%0" + String(cnt - max * 510) + "d", 0)
        }
        
        return ret
    }
    
    static func initDayReloadFlg(curtDate: String) {
        if ProcessDataManager.sharedInstance.hasDeviceFb! {
            ProcessDataManager.sharedInstance.localData?.updateStorageDate("Fitbit", kind2: HealthType.ActivitySteps["path"] as! String, procDate: curtDate, value: "0")
            ProcessDataManager.sharedInstance.localData?.updateStorageDate("Fitbit", kind2: HealthType.ActivityCalories["path"] as! String, procDate: curtDate, value: "0")
            ProcessDataManager.sharedInstance.localData?.updateStorageDate("Fitbit", kind2: HealthType.ActivityDistance["path"] as! String, procDate: curtDate, value: "0")
            ProcessDataManager.sharedInstance.localData?.updateStorageDate("Fitbit", kind2: HealthType.Speed["path"] as! String, procDate: curtDate, value: "0")
            ProcessDataManager.sharedInstance.localData?.updateStorageDate("Fitbit", kind2: HealthType.Heart["path"] as! String, procDate: curtDate, value: "0")
            ProcessDataManager.sharedInstance.localData?.updateStorageDate("Fitbit", kind2: HealthType.Sleep["path"] as! String, procDate: curtDate, value: "0")
        }

        ProcessDataManager.sharedInstance.localData?.updateStorageDate("HealthKit", kind2: HealthType.ActivitySteps["path"] as! String, procDate: curtDate, value: "0")
        ProcessDataManager.sharedInstance.localData?.updateStorageDate("HealthKit", kind2: HealthType.ActivityCalories["path"] as! String, procDate: curtDate, value: "0")
        ProcessDataManager.sharedInstance.localData?.updateStorageDate("HealthKit", kind2: HealthType.ActivityDistance["path"] as! String, procDate: curtDate, value: "0")
        ProcessDataManager.sharedInstance.localData?.updateStorageDate("HealthKit", kind2: HealthType.Speed["path"] as! String, procDate: curtDate, value: "0")
        ProcessDataManager.sharedInstance.localData?.updateStorageDate("HealthKit", kind2: HealthType.Heart["path"] as! String, procDate: curtDate, value: "0")
        ProcessDataManager.sharedInstance.localData?.updateStorageDate("HealthKit", kind2: HealthType.Sleep["path"] as! String, procDate: curtDate, value: "0")
    }
    
    static func createAlertWithOnlyClose(_ title: String, message: String) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "閉じる", style: UIAlertActionStyle.default, handler: nil))
        return alert
    }
    
    static func createAlertWithOnlyClose(_ title: String, message: String, handler: ((UIAlertAction) -> Void)?) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "閉じる", style: UIAlertActionStyle.default, handler: handler))
        return alert
    }
    
    static func createNavigatorBarButton(_ title: String, frame : CGRect) -> ZFRippleButton {
        var button: ZFRippleButton?
        button = ZFRippleButton(frame: frame)
        button!.setTitle(title, for: UIControlState())
        button!.rippleColor = UIColor.hexStr("DDDDDD", alpha: 1.0)
        button!.rippleOverBounds = true
        button!.trackTouchLocation = true
        button!.buttonCornerRadius = 20
        button!.setTitleColor(UIColor.hexStr("F16046", alpha: 1.0), for: UIControlState())
        
        return button!;
    }
    
    static func createRedButton(_ title: String, frame : CGRect) -> ZFRippleButton {
        var button: ZFRippleButton?
        button = ZFRippleButton(frame: frame)
        button!.setTitle(title, for: UIControlState())
        setButtonRedZFRipple(button!);
        
        return button!;
    }
    
    static func setButtonRedZFRipple(_ button: ZFRippleButton){
        button.rippleColor = UIColor( red: 0.94509803920000002, green: 0.37647058820000001, blue:0.27450980390000002, alpha: 1.0 )
        button.rippleBackgroundColor = UIColor( red: 0.94509803921568625, green: 0.63921568627450975, blue:0.57647058823529407, alpha: 1.0 )
        button.trackTouchLocation = true
        button.buttonCornerRadius = 4
        button.backgroundColor = UIColor( red: 0.94509803920000002, green: 0.37647058820000001, blue:0.27450980390000002, alpha: 1.0 )
        button.setTitleColor(UIColor(white: 1, alpha: 1), for: UIControlState())
        button.setTitleShadowColor(UIColor( red: 0.49803921568627452, green: 0.49803921568627452, blue:0.49803921568627452, alpha: 1.0 ), for: UIControlState())
    }
    
    static func getDocumentsDirectory() ->NSString {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        return documentsDirectory as NSString
    }
    
    static func wait_atleast(_ time : TimeInterval, _ block: () -> Void) {
        let start = CFAbsoluteTimeGetCurrent()
        block()
        let end = CFAbsoluteTimeGetCurrent()
        let wait = max(0.0, time - (end - start))
        if wait > 0.0 {
            Thread.sleep(forTimeInterval: wait)
        }
    }
    
    static func downloadPicFromS3(openId: String, procDay: String, dlFileList: [String:String], cb:((String) -> Void)!) {
        let awsIoTManagerGetPicFromS3 : AwsIoTAPIManagerGetPicFromS3 = MQTTClientFactory.sharedInstance.getInstance(.notePicGet) as! AwsIoTAPIManagerGetPicFromS3
        awsIoTManagerGetPicFromS3.onReciveDataCallback = { returnData in
            print("download pic end returnData:"+returnData);
            CommUtil.wait_atleast(0.1) {
                    awsIoTManagerGetPicFromS3.close()
            }
            if cb != nil {
                cb(returnData)
            }
        }
        
        awsIoTManagerGetPicFromS3.loginAsyc( openId , callback: { returnCode in
            //SwiftSpinner.showWithDelay(0.5, title: "データ同期中", animated: true)
            awsIoTManagerGetPicFromS3.getPic( procDay, getFile: dlFileList)
        })

    }
    
    // 作成日時でPhotoAlbumから写真を取得
    static func getPicFromPhotoAlbum(_ createDateStr: String) -> UIImage? {
        let df = DateFormatter()
//        df.locale = NSLocale(localeIdentifier: "ja_JP") // ロケールの設定
        df.timeZone = TimeZone(identifier: "UTC")
        df.dateFormat = "yyyyMMddHHmmss"
        
        var picDate = df.date(from: createDateStr)
        let previousDay = picDate!.addingTimeInterval(TimeInterval(-1))   // 2秒内
        picDate = picDate!.addingTimeInterval(TimeInterval(1))
        
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "(creationDate > %@) and (creationDate) <= %@", previousDay as CVarArg, picDate! as CVarArg)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchResult = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: options)
//        var result: UIImage? = nil
//        if fetchResult.count != 0 {
//            fetchResult.enumerateObjectsUsingBlock { (photo, idx, stop) -> Void in
//                result = photo as? UIImage
//            }
//        }
//        var fetchResult = PHAssetCollection.fetchAssetCollectionsWithType(
//            .SmartAlbum,
//            subtype: .SmartAlbumUserLibrary,
//            options: nil
//        )
//        
//        guard let assetCollection = fetchResult.firstObject as? PHAssetCollection else {
//            return nil
//        }
//
//        fetchResult = PHAsset.fetchAssetsInAssetCollection(assetCollection, options: options)
        
        var result: UIImage? = nil
        guard let asset = fetchResult.firstObject as? PHAsset else {
            return nil
        }
        print("creationDate:\(asset.creationDate)");
        let phimgr:PHImageManager = PHImageManager();
        
        let option = PHImageRequestOptions()
        option.isSynchronous = true
        phimgr.requestImage(for: asset,
                                    targetSize: CGSize(width: 3024, height: 4032),
                                    contentMode: .aspectFit, options: option) {
                                        image, info in                                        //ここでUIImageを取得します。
                                        result = image
        
        }
        
        return result
    }
    
    static func imageResize(_ image : UIImage, maxLongSide : CGFloat, recFlg : Bool = false) -> CGSize {
        let size = image.size

        if maxLongSide == 0 || ( size.width <= maxLongSide && size.height <= maxLongSide ) {
            return size
        }
        
        let ax = size.width / maxLongSide
        let ay = size.height / maxLongSide
        let ar = ax > ay ? ax : ay
        var rs: CGSize? = nil
        if recFlg {
            rs = CGSize(width: maxLongSide, height: maxLongSide)
        } else {
            rs = CGSize(width: size.width / ar, height: size.height / ar)
        }
        
        return rs!
    }
    
    static func iconResize(_ image : UIImage, recFlg : Bool = false) -> CGSize {
        let size = image.size
        let maxLongSide : CGFloat = CGFloat(SystemConstants.ICON_MAX_LONGSIDE)
        
        if maxLongSide == 0 || ( size.width <= maxLongSide && size.height <= maxLongSide ) {
            return size
        }
        
        let ax = size.width / maxLongSide
        let ay = size.height / maxLongSide
        let ar = ax > ay ? ax : ay
        var rs: CGSize? = nil
        if recFlg {
            rs = CGSize(width: SystemConstants.ICON_MAX_LONGSIDE, height: SystemConstants.ICON_MAX_LONGSIDE)
        } else {
            rs = CGSize(width: size.width / ar, height: size.height / ar)
        }
        
        return rs!
    }
    
    static func imageShrink(_ image : UIImage, targetSize : CGSize, targetFileSize : Int) -> Data? {
        var size = CGSize(width: targetSize.width, height: targetSize.height)
        var data : Data?
        var resizeImage : UIImage! = image
        while true {
            while true {
                UIGraphicsBeginImageContext(size)
                image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
                resizeImage = UIGraphicsGetImageFromCurrentImageContext()
                
                UIGraphicsEndImageContext()
                
                data = UIImageJPEGRepresentation(resizeImage, 1)
                
                if (data?.count > 3100000) {
                    print("data?.length0:"+String(describing: data?.count))
                    var maxLength = size.width > size.height ? size.width : size.height
                    maxLength = maxLength - 100
                    size = imageResize(resizeImage, maxLongSide: maxLength)
                } else {
                    break
                }
            }
            print("data?.length1:"+String(describing: data?.count))
            
            let qualityMax = 1.0
            let qualityDif = 0.2
            let qualityMin = 0.1
            var qualityUse : Double

//            for (qualityUse = qualityMax; qualityUse >= qualityMin ; qualityUse = qualityUse - qualityDif) {
            qualityUse = qualityMax
            while qualityUse >= qualityMin {
                qualityUse = qualityUse - qualityDif
                
                data = UIImageJPEGRepresentation(resizeImage, CGFloat(qualityUse))
                print("data?.length:"+String(describing: data?.count))
                if (data?.count <= targetFileSize) {
                    return data!
                }
            }
            
            var maxLength = size.width > size.height ? size.width : size.height
            maxLength = maxLength - 100
            size = imageResize(resizeImage, maxLongSide: maxLength)
        }
    }
    
    static func indexOfUIViewArray(array:[AnyObject], searchObject: AnyObject)-> Int? {
        var index = 0
        for value in array {
           if value as! UIViewController == searchObject as! UIViewController {
               return index
           }
           index += 1
        }
        return nil
    }
    
    static func getSyokujiTypeName(_ syokujiType : SystemConstants.SyokujiType) -> String{
        switch syokujiType {
        case .asa:
            return "朝食"
        case .hiru:
            return "昼食"
        case .ban:
            return "夕食"
        case .kan:
            return "その他"
        }
    }
    
    static func createPath(_ path : String){
        do {
            var isDir : ObjCBool = false
            let checkValidation = FileManager.default
            if checkValidation.fileExists(atPath: path, isDirectory:&isDir) {
//                if isDir {
//                    // file exists and is a directory
//                } else {
//                    // file exists and is not a directory
//                }
//                print("path(" + path + ") exists");
            } else {
                // file does not exist
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
            }
        } catch let error as NSError {
            print(error.localizedDescription);
        }
    }
    
    static func _downloadFile(_ fileUrl: String, filePathNm: String, completionHandler: @escaping (String) -> Void) {
        let url = URL(string: fileUrl)
        URLSession.shared.dataTask(with: url!, completionHandler: { (data, response, error) in
            
            if error != nil {
                print("画像のダウンロード中にエラーが発生しました: \(error)")
                completionHandler("err")
                return
            }
            
            try? data!.write(to: URL(fileURLWithPath: filePathNm), options: [.atomic])
            completionHandler("ok")
            
        }).resume()
    }
    
    static func downloadFile(_ fileUrl: String, filePathNm: String, overwriteFlg: Bool, cb: @escaping (String) -> Void) {
        let realFileName = filePathNm
        let tempFileName = filePathNm + ".dl"
        
        CommUtil._downloadFile(fileUrl, filePathNm: tempFileName) { ret in
                if ret == "err" {
                    cb(ret)
                    return
                }
                do {
                    let fileMg = FileManager.default
                    let checkValidation = FileManager.default
                    var isDir : ObjCBool = false
                    if checkValidation.fileExists(atPath: realFileName, isDirectory:&isDir) {
                        if overwriteFlg == true {
                            try fileMg.removeItem(atPath: realFileName)
                            try fileMg.moveItem(atPath: tempFileName, toPath: realFileName)
                        } else {
                            cb("exist")
                            return
                        }
                    } else {
                        try fileMg.moveItem(atPath: tempFileName, toPath: realFileName)
                    }
                } catch let error as NSError {
                    print(error)
                }
                cb(ret)
            }
    }
    
    static func getFitPGPNG(_ fitid: String, forceDlFlg: Bool = false) -> UIImage? {
        var result: UIImage? = nil
        let imgNm = AppConstants.FitPGPicPrevNM + fitid + ".png"
        
        var path = CommUtil.getDocumentsDirectory().appendingPathComponent(
            "/" + AppConstants.FitPGPicPath + "/" )
        CommUtil.createPath(path)
        
        let realFileName = path + "/" + imgNm
        var isDir : ObjCBool = false
        let checkValidation = FileManager.default
        let localExistFileFlg: Bool = checkValidation.fileExists(atPath: realFileName, isDirectory:&isDir)
        
        if forceDlFlg || !localExistFileFlg {
            let tempFileName = realFileName + ".dl"
            let imgUrl = AppConstants.FitPGPicUrl + imgNm
            CommUtil._downloadFile(imgUrl, filePathNm: tempFileName) { ret in
                if ret == "err" {
                    return
                }
                do {
                    let fileMg = FileManager.default
                    if checkValidation.fileExists(atPath: realFileName, isDirectory:&isDir) {
                        try fileMg.removeItem(atPath: realFileName)
                    }
                    try fileMg.moveItem(atPath: tempFileName, toPath: realFileName)
                } catch let error as NSError {
                    print(error)
                }
            }
        }
        
        // ローカルダウンロードファイルから取得
        if localExistFileFlg {
            if let pic = try? Data(contentsOf: URL(fileURLWithPath: realFileName)) {
                result = UIImage(data: pic)
            }
        }
        
        // インストールされたリソースから取得
        if result == nil {
            if let img = UIImage(named: imgNm) {
                result = img
            }
        }
        return result
    }
    
    // kind -> 1:機構、2:人
    static func getGroupPNG(_ kind: Int, filename: String, reGetFlg: Bool = false, orgKind: String = "1") -> UIImage? {
        var nm = filename //+ ".png"
        var result: UIImage? = nil
        
        result = UIImage(named: nm + ".png")
        
        if result == nil && kind == 2 {
            nm = nm + ".jpg"

            let imgKey = DefaultsKey<Data?>(nm)
            
            if let imgData = Defaults[imgKey] {
                result = UIImage(data: imgData)
            }
            if result == nil || reGetFlg {
                let url = URL(string: "https://s3-ap-northeast-1.amazonaws.com/intasect-iot/icon/" + nm)
                let data = try? Data(contentsOf: url!)
                if data != nil {
                    result = UIImage(data: data!)
                    Defaults[imgKey] = data
                }
            }
        }
        
        if result == nil {
            if kind == 1 {
                var orgname = "organization"
                if orgKind == "2" {
                    orgname = "organization2"
                } else if orgKind == "3" {
                    orgname = "organization3"
                }
                result = UIImage(named: orgname + ".png")
            } else {
                result = UIImage(named: "staff.png")
            }
        }
        return result
    }
    
//    static var progress = 0.0
//    static func spinnerTimerFire(_ val: Double, showStr: String) {
//            let endVal = progress + val
//            if endVal > 1 {
//                SwiftSpinner.show(duration: 1.0, title: "Complete!", animated: false)
//                progress = 0.0
//            }
//
//            while CommUtil.progress < endVal {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                    CommUtil.progress += 0.05
//                    SwiftSpinner.show(progress: CommUtil.progress, title: "\(showStr): \(Int(CommUtil.progress * 100))% completed")
//                    if CommUtil.progress >= 1 {
//                        SwiftSpinner.show(duration: 1.0, title: "Complete!", animated: false)
//                        CommUtil.progress = 0.0
//                    }
//                }
//            }
//
//    }
    
    // 現在表示中の画面を取得
    static func getTopMostViewController() -> UIViewController?{
        var tc = UIApplication.shared.keyWindow?.rootViewController;
        while ((tc!.presentedViewController) != nil) {
            
            print("ClassName:" + NSStringFromClass((tc?.classForCoder)!).components(separatedBy: ".").last!)
            tc = tc!.presentedViewController;
        }
        return tc;
    }
    
    // MARK: - システムログイン
    static func appLogin(_ view:UIViewController, completionHandler:@escaping ( _ flg: Bool ) -> Void) {
        let oauth2AccessToken = ProcessDataManager.sharedInstance.getOAuth2AccessToken()
        if !oauth2AccessToken.isEmpty {
            print("access token is not empty!")
            ProcessDataManager.sharedInstance.serviceOpenID = ProcessDataManager.sharedInstance.getServiceOpenID()
            ProcessDataManager.sharedInstance.serviceToken = oauth2AccessToken
            completionHandler(true)
            return ;
        }

        let oauthswift = OAuth2Swift(
            consumerKey:    AppConstants.ClientID,
            consumerSecret: AppConstants.ClientSecret,
            authorizeUrl:   AppConstants.AuthorizationUrl,
            accessTokenUrl: AppConstants.TokenUrl,
            responseType:   "code"
        )
        
        let oauth2RefreshToken = ProcessDataManager.sharedInstance.getOAuth2RefreshToken()
        if !oauth2RefreshToken.isEmpty {
            print("refresh token is not empty!")
            var paramters: OAuthSwift.Parameters = [:]
            if !AppConstants.Realm.isEmpty {
                paramters["realm"] = AppConstants.Realm
            }
            oauthswift.renewAccessToken(withRefreshToken: oauth2RefreshToken, parameters: paramters, headers: nil, success: { (credential, response, refreshParameters) in
                print("access token refresh successed!")
                
                // ユーザー一致性と利用権限をチェック
                if CommUtil.intahealthAuth(parameters: refreshParameters) == false {
                    completionHandler(false)
                    return
                }
//                ProcessDataManager.sharedInstance.serviceOpenID = refreshParameters["service_openid"] as? String
//                let idToken = refreshParameters["id_token"] as? String
//                let idTokenArr = idToken?.split(separator: ".")
//                if idTokenArr != nil && idTokenArr?.count > 2 {
//                    ProcessDataManager.sharedInstance.serviceOpenID = String(idTokenArr![1])
//                } else {
//                    ProcessDataManager.sharedInstance.serviceOpenID = ""
//                }
//
//                // ユーザー一致性チェック
//                if let localuser = DB.store[AppConstants.ServiceOpenID] {
//                    if localuser != "" && localuser != ProcessDataManager.sharedInstance.serviceOpenID! {
//                        if let curtCtl = ProcessDataManager.sharedInstance.currentViewCtl {
//                            let alert = CommUtil.createAlertWithOnlyClose("システムログイン失敗", message: "ログインユーザーはローカルデータのユーザーと一致していません。")
//                            curtCtl.present(alert, animated: true, completion: nil)
//                        } else {
//                            print("システムログイン失敗: ログインユーザーはローカルデータのユーザーと一致していません。")
//                        }
//                        completionHandler(false)
//                        return
//                    }
//                }
                
                ProcessDataManager.sharedInstance.serviceToken = refreshParameters["access_token"] as? String
                let refresh_token = refreshParameters["refresh_token"] as? String
                
                var expiresAt : Date = Date()
                if let expiresIn = refreshParameters["expires_in"] as? String, let offset = Double(expiresIn)  {
                    expiresAt = Date(timeInterval: offset, since: Date())
                } else if let expiresIn = refreshParameters["expires_in"] as? Double {
                    expiresAt = Date(timeInterval: expiresIn, since: Date())
                }

                ProcessDataManager.sharedInstance.saveOAuth2Credential(
                                        ProcessDataManager.sharedInstance.serviceOpenID!,
                                        accessToken: ProcessDataManager.sharedInstance.serviceToken!,
                                        expiresAt: expiresAt,
                                        refreshToken: refresh_token!);
                
                completionHandler(true)
                
            },
            failure: { error in
                    print(error.localizedDescription)
                    print("refresh token invalide!")
                
                    if ProcessDataManager.sharedInstance.serviceOpenID != nil
                        && !(ProcessDataManager.sharedInstance.serviceOpenID?.isEmpty)!
                    {
                        ProcessDataManager.sharedInstance.serviceOpenID = "";
                        CommUtil.resetTokenAndRestartApplication(view);
                    } else {
                        CommUtil.gotoLoginPage(view, oauthswift: oauthswift, completionHandler: completionHandler);
                    }
            })
            return;
        }
        
        print("refresh token is empty!")
        if ProcessDataManager.sharedInstance.serviceOpenID != nil
            && !(ProcessDataManager.sharedInstance.serviceOpenID?.isEmpty)!
        {
            ProcessDataManager.sharedInstance.serviceOpenID = "";
            CommUtil.resetTokenAndRestartApplication(view);
        } else {
            CommUtil.gotoLoginPage(view, oauthswift: oauthswift, completionHandler: completionHandler);
        }
    }
    
    static func resetTokenAndRestartApplication(_ view:UIViewController) {
        let alert = CommUtil.createAlertWithOnlyClose("アプリ", message: "再ログインが必要です！", handler: doResetAndRestart)
        view.present(alert, animated: true, completion: nil)
    }
    
    static func doResetAndRestart(_ action : UIAlertAction){
        ProcessDataManager.sharedInstance.saveOAuth2Credential(
                                        "",
                                        accessToken: "",
                                        expiresAt: Date(),
                                        refreshToken: "");
    
        let storyboard = UIStoryboard(name: "Startup", bundle: nil)
        UIApplication.shared.keyWindow?.rootViewController = storyboard.instantiateInitialViewController()
    }
    
    static func gotoLoginPage(_ view:UIViewController, oauthswift : OAuth2Swift, completionHandler: @escaping (Bool) -> Void) {
        oauthswift.accessTokenBasicAuthentification = true
        let state: String = generateState(withLength: 20) as String
        oauthswift.authorizeURLHandler = SafariURLHandler(viewController: view, oauthSwift: oauthswift)
        
        //isWaitOpenAMCallBack = true
        var paramters: OAuthSwift.Parameters = [:]
        var scope = "openid profile"
        if !AppConstants.Realm.isEmpty {
            paramters["realm"] = AppConstants.Realm
            scope = AppConstants.Realm
        }
        oauthswift.authorize(withCallbackURL: URL(string: AppConstants.RedirectURI)!, scope: scope, state: state, parameters: paramters, headers: nil, success: {
            credential, response, parameters in
                print("openam login successed!")
                //isWaitOpenAMCallBack = false
            
                var message = "oauth_token:\(credential.oauthToken)"
                if !credential.oauthTokenSecret.isEmpty {
                    message += "\n\noauth_toke_secret:\(credential.oauthTokenSecret)"
                }
            
//                print("取得されたトークン：" + message)
//                ProcessDataManager.sharedInstance.serviceOpenID = parameters["service_openid"] as? String //"aXBob25lLHRlc3Q%3D"
                if CommUtil.intahealthAuth(parameters: parameters) == false {
                    completionHandler(false)
                    return
                }
            
                ProcessDataManager.sharedInstance.serviceToken = credential.oauthToken
            
                ProcessDataManager.sharedInstance.saveOAuth2Credential(
                                        ProcessDataManager.sharedInstance.serviceOpenID!,
                                        accessToken: credential.oauthToken,
                                        expiresAt: credential.oauthTokenExpiresAt!,
                                        refreshToken: credential.oauthRefreshToken);
            
//                print("User login OK!")
                completionHandler(true)
            
            }, failure: { error in
                CommUtil.showOAuthError(swferror: error)
                print("User login failed!")
                completionHandler(false)
        })
        return
    }
    
    static func showOAuthError(swferror: OAuthSwiftError) -> Int {
        var desp = ""
        var errcode = 0
        
        print(swferror)
        if let error = swferror.errorUserInfo["error"] as? NSError  {
            desp = error.localizedDescription
            errcode = error.code
        } else {
            return errcode
        }
        
        if let cvl = ProcessDataManager.sharedInstance.currentViewCtl {
            let alert = CommUtil.createAlertWithOnlyClose("OAuth認証エラー", message: "Error Code: \(errcode)\nDescription: \(desp)")
            cvl.present(alert, animated: true, completion: nil)
        }
    
        return errcode
    }
    
    // 業務チェック
    // roleがnormal-user、ログインuserがlocaldataが属するユーザーと一致
    static func intahealthAuth(parameters: [String: Any]) -> Bool {
        var ret = true
        
        let idToken = parameters["id_token"] as? String
        let idTokenArr = idToken?.split(separator: ".")
        if idTokenArr != nil && idTokenArr?.count > 2 {
            ProcessDataManager.sharedInstance.serviceOpenID = String(idTokenArr![1])
        } else {
            ProcessDataManager.sharedInstance.serviceOpenID = ""
        }
        if let localuser = DB.store[AppConstants.ServiceOpenID] {
            var localusername = ""
            var decodeStr = CommUtil.base64urlDeCode(base64url: localuser)
            var arry = JSON.parse(decodeStr).asDictionary
            if arry != nil && arry!["preferred_username"] != nil && arry!["preferred_username"]!.asString != nil {
                localusername = arry!["preferred_username"]!.asString!
            }
            var returnusername = ""
            decodeStr = CommUtil.base64urlDeCode(base64url: ProcessDataManager.sharedInstance.serviceOpenID!)
            arry = JSON.parse(decodeStr).asDictionary
            if arry != nil && arry!["preferred_username"] != nil && arry!["preferred_username"]!.asString != nil {
                returnusername = arry!["preferred_username"]!.asString!
            }
            if localusername != "" && localusername != returnusername {
                if let curtCtl = ProcessDataManager.sharedInstance.currentViewCtl {
                    let alert = CommUtil.createAlertWithOnlyClose("システムログイン失敗", message: "ログインユーザーはローカルデータのユーザーと一致していません。")
                    curtCtl.present(alert, animated: true, completion: nil)
                } else {
                    print("システムログイン失敗: ログインユーザーはローカルデータのユーザーと一致していません。")
                }
                ret = false
            }
        }
        
        if let retToken = parameters["access_token"] {
            let accessTokenArr:[String] = (retToken as! String).components(separatedBy: ".")
            var encodeStr = ""
            if accessTokenArr.count > 2 {
                encodeStr = accessTokenArr[1]
            }
            let decodeStr = CommUtil.base64urlDeCode(base64url: encodeStr)
            if let arry = JSON.parse(decodeStr).asDictionary {
                if arry["resource_access"] != nil {
                    let roles = arry["resource_access"]![AppConstants.ClientID]
                    let role = roles["roles"].asArray
                    if role == nil || role!.count == 0 || role![0].asString != AppConstants.UserRole {
                        if let curtCtl = ProcessDataManager.sharedInstance.currentViewCtl {
                            let alert = CommUtil.createAlertWithOnlyClose("システムログイン失敗", message: "ログインユーザーはIntaHealthの利用権限が持っていません。")
                            curtCtl.present(alert, animated: true, completion: nil)
                        } else {
                            print("システムログイン失敗: ログインユーザーはIntaHealthの利用権限が持っていません。")
                        }
                        ret = false
                    }
                } else {
                    print("access_token内容不正")
                    ret = false
                }
            } else {
                print("access_token内容不正")
                ret = false
            }
        }
        
        return ret
    }

    static func base64urlToBase64(base64url: String) -> String {
        var base64 = base64url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        if base64.characters.count % 4 != 0 {
            base64.append(String(repeating: "=", count: 4 - base64.characters.count % 4))
        }
        return base64
    }
    
    static func base64urlDeCode(base64url: String) -> String {
        let base64str = CommUtil.base64urlToBase64(base64url: base64url)
        let result = String(data: Data(base64Encoded: base64str)!, encoding: .utf8)!
        return result
    }
}

extension UIColor {
    class func hexStr (_ hexStr : NSString, alpha : CGFloat) -> UIColor {
        var hexStr = hexStr
        hexStr = hexStr.replacingOccurrences(of: "#", with: "") as NSString
        let scanner = Scanner(string: hexStr as String)
        var color: UInt32 = 0
        if scanner.scanHexInt32(&color) {
            let r = CGFloat((color & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((color & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(color & 0x0000FF) / 255.0
            return UIColor(red:r,green:g,blue:b,alpha:alpha)
        } else {
            print("invalid hex string")
            return UIColor.white;
        }
    }
}

extension Data {
    func MD5() -> NSString {
        let digestLength = Int(CC_MD5_DIGEST_LENGTH)
        let md5Buffer = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLength)
        
        CC_MD5(bytes, CC_LONG(count), md5Buffer)
        let output = NSMutableString(capacity: Int(CC_MD5_DIGEST_LENGTH * 2))
        for i in 0..<digestLength {
            output.appendFormat("%02x", md5Buffer[i])
        }
        
        return NSString(format: output)
    }
}

extension NSString {
    func MD5() -> NSString {
        let digestLength = Int(CC_MD5_DIGEST_LENGTH)
        let md5Buffer = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLength)
        CC_MD5(utf8String, CC_LONG(strlen(utf8String)), md5Buffer)
        
        let output = NSMutableString(capacity: Int(CC_MD5_DIGEST_LENGTH * 2))
        for i in 0..<digestLength {
            output.appendFormat("%02x", md5Buffer[i])
        }
        
        return NSString(format: output)
    }
}

enum FadeType: TimeInterval {
    case
    normal = 0.2,
    slow = 2.0
}

extension UIBarButtonItem {
    func setButton(_ button : UIButton){
        let rightView:UIView = UIView()
        rightView.frame = button.frame
        rightView.addSubview(button)
    
        customView = rightView
    }
}

extension UIImageView {
   func fadeIn(_ type: FadeType = .normal, completed: (() -> ())? = nil) {
        fadeIn(type.rawValue, completed: completed)
    }

    /** For typical purpose, use "public func fadeIn(type: FadeType = .Normal, completed: (() -> ())? = nil)" instead of this */
   func fadeIn(_ duration: TimeInterval = FadeType.slow.rawValue, completed: (() -> ())? = nil) {
        alpha = 0
        isHidden = false
        UIView.animate(withDuration: duration,
            animations: { [weak self] in
                self!.alpha = 1
            }, completion: { finished in
                completed?()
        }) 
    }
   func fadeOut(_ type: FadeType = .normal, completed: (() -> ())? = nil) {
        fadeOut(type.rawValue, completed: completed)
    }
    /** For typical purpose, use "public func fadeOut(type: FadeType = .Normal, completed: (() -> ())? = nil)" instead of this */
   func fadeOut(_ duration: TimeInterval = FadeType.slow.rawValue, completed: (() -> ())? = nil) {
        UIView.animate(withDuration: duration
            , animations: { [weak self] in
                self!.alpha = 0
            }, completion: { [weak self] finished in
                self?.isHidden = true
                self?.alpha = 1 
                completed?()
        }) 
    }
}

extension String {
    var doubleValue: Double? {
        return Double(self)
    }
    var floatValue: Float? {
        return Float(self)
    }
    var integerValue: Int? {
        return Int(self)
    }
//    
//    func indexOf(string: String) -> Range<String.Index>? {
//        guard let startIndex = index(character: string[string.startIndex]) else {
//            return nil
//        }
//        
//        guard let endIndex = index(startIndex, offsetBy: string.characters.count, limitedBy: endIndex) else {
//            return nil
//        }
//        
//        let range = startIndex..<endIndex
//        if self[range] != string {
//            return nil
//        }
//        
//        return range
//    }
}

extension Date {
    func getCalendar() -> Calendar {
        return Calendar(identifier: .japanese)//NSCalendarIdentifierISO8601
    }
    
    func startOfDay() -> Date? {
        let calender = getCalendar()
        var components = (calender as NSCalendar).components([.year, .month, .day, .hour, .minute, .second], from: self)
        components.to0H()
        let startOfDay = calender.date(from: components)!
        return startOfDay;
        
    }

    func endOfDay() -> Date? {
        let calender = getCalendar()
        var components = (calender as NSCalendar).components([.year, .month, .day, .hour, .minute, .second], from: self)
        components.to24H()
        let endOfDay = calender.date(from: components)!
        return endOfDay;
    }

    func startOfWeek() -> Date? {
        var calender = getCalendar()
        calender.firstWeekday = 2
        
        var components = (calender as NSCalendar).components([.yearForWeekOfYear, .weekOfYear], from: self)
        components.to0H()
        let startDay = calender.date(from: components)!
        
        return startDay
    }

    func endOfWeek() -> Date? {
        var endDay = startOfWeek();
        endDay = (Calendar.current as NSCalendar)
                .date(byAdding: .day, value: 6, to: endDay!, options: [])!
        
        let calender = getCalendar()
        var components = (calender as NSCalendar).components([.year, .month, .day, .hour, .minute, .second], from: endDay!)
        components.to24H()
        endDay = calender.date(from: components)!
        return endDay
    }
    func startOfMonth() -> Date? {
        let calender = getCalendar()
        var components = (calender as NSCalendar).components([.year, .month, .day, .hour, .minute, .second], from: self)
        components.day = 1;
        components.to0H()
        let startOfMonth = calender.date(from: components)!
        return startOfMonth;
        
    }

    func endOfMonth() -> Date? {
        let calender = getCalendar()
        var comps2 = DateComponents()
        comps2.month = 1
        comps2.day = -1
        var endOfMonth = (calender as NSCalendar).date(byAdding: comps2, to: startOfMonth()!, options: [])!
        
        var components = (calender as NSCalendar).components([.year, .month, .day, .hour, .minute, .second], from: endOfMonth)
        components.to24H()
        endOfMonth = calender.date(from: components)!
        return endOfMonth
    }
    
    func startOfYear() -> Date? {
        let calender = getCalendar()
        var components = (calender as NSCalendar).components([.year, .month, .day, .hour, .minute, .second], from: self)
        components.month = 1;
        components.day = 1;
        components.to0H()
        let startOfYear = calender.date(from: components)!
        return startOfYear;
    }
    
    func endOfYear() -> Date? {
        let calender = getCalendar()
        var comps2 = DateComponents()
        comps2.year = 1
        comps2.day = -1
        var endOfYear = (calender as NSCalendar).date(byAdding: comps2, to: startOfYear()!, options: [])!
        
        var components = (calender as NSCalendar).components([.year, .month, .day, .hour, .minute, .second], from: endOfYear)
        components.to24H()
        endOfYear = calender.date(from: components)!
        return endOfYear
    }
    
    func startOfHour() -> Date? {
        let calender = getCalendar()
        var components = (calender as NSCalendar).components([.year, .month, .day, .hour, .minute, .second], from: self)
        components.minute = 1;
        components.second = 1;
        let startOfYear = calender.date(from: components)!
        return startOfYear;
    }
    
    func endOfHour() -> Date? {
        let calender = getCalendar()
        var comps2 = DateComponents()
        comps2.hour = 1
        comps2.second = -1
        let endOfYear = (calender as NSCalendar).date(byAdding: comps2, to: startOfHour()!, options: [])!

        return endOfYear
    }
    
    func getYear() -> Int {
        let calender = getCalendar()
        let components = (calender as NSCalendar).components([.year], from: self)
        return components.year!;
    }
    
    func getMonth() -> Int {
        let calender = getCalendar()
        let components = (calender as NSCalendar).components([.month], from: self)
        return components.month!;
    }
    
    func getDay() -> Int {
        let calender = getCalendar()
        let components = (calender as NSCalendar).components([.day], from: self)
        return components.day!;
    }
    
    func getHour() -> Int {
        let calender = getCalendar()
        let components = (calender as NSCalendar).components([.hour], from: self)
        return components.hour!;
    }
    
    func getWeekDay() -> Int {
        var calender = getCalendar()
        calender.firstWeekday = 2
        let components = (calender as NSCalendar).components([.weekday], from: self)
        var weekday = components.weekday
        weekday = weekday! - calender.firstWeekday
        if weekday < 0 {
            weekday = weekday! + 7
        }
        return weekday!;
    }
}

internal extension DateComponents {
    mutating func to12pm() {
        hour = 12
        minute = 0
        second = 0
    }
    mutating func to0H() {
        hour = 0
        minute = 0
        second = 0
    }
    mutating func to24H() {
        hour = 23
        minute = 59
        second = 59
    }
}
