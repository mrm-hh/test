var express = require("express");
var sys = require("../models/sys.js");
var util = require("../util.js");
var awsData = require("../models/dynamoData.js");
var router = express.Router();
const childProcess = require('child_process');

function onRejectted(error, res) {
    res.send(JSON.stringify(error));
    console.log("error = " + error);
}

// APPバージョンチェック
function doCheckVersion(req, res, next) {
    var arr = req.params.ver_no.split(".");

    if(arr.length > 3) {
        console.log("invalid ver_no: " + req.params.ver_no);
        // res.send("invalid ver_no: " + req.params.ver_no);
        res.send({"result":false});
        return false;
    }
    if(arr.length == 1){
        arr.push("0");
        arr.push("0");
    } if (arr.length == 2) {
        arr.push("0");
    } 

    var verNoMain = arr[0] + "." + arr[1];
    var verNoSub = arr[2];
    // バージョン区分: 1(正式版)、2(テスト用)
    var verKbn = req.params.ver_kbn;

    console.log("CheckVersion: " + verNoMain + ", " + verNoSub + ", " + verKbn);
    sys.getVerInfo("iotproject", verNoMain, verNoSub, verKbn)
        .then(function(rows) {
            if (rows.length == 0) {
                res.send({"result":false});
            } else {
                res.send({"result":true});
            }
        })
        .catch(function(error) {
            console.log("error = " + error);
            res.send({"result":false});
        });
            // res.send({"result":false});
}

// 所属取得（by userID）
function doGetOrgInfo(req, res, next) {
    var userOpenID = req.params.user_id;
    var userID = util.getDecodeUserID(userOpenID);

    sys.getUserOrg(userID)
        .then(function(rows) {
            var rtnData = {}
            
            if (rows.length > 0) {
                var retData = {};
                var row = rows[0];
                
                retData.org_id = row["org_id"];
                retData.kbn = row["kbn"];

                // console.log("org staff data: " + JSON.stringify(row));
                rtnData.data = retData;
            } else {
                rtnData.data = {};
            }

            // 成功(jsonを返すなど)
            res.send(JSON.stringify(rtnData));
        })
        .catch(function(error) {
            onRejectted(error, res);
        });
}

// ユーザー所属登録
function doTorokuUser(req, res, next) {
    var userOpenID = req.params.user_id;
    var userID = util.getDecodeUserID(userOpenID);
    var userKeycloakID = "";
    if (userID) {
        userKeycloakID = util.getDecodeUserID(userOpenID, "sub");
    } else {
        res.send("ERR:ユーザーID未設定");
        return;
    }

    var org_id = req.params.org_id;
    var nick_name = req.params.nick_name;
    var flg = "i";

    sys.getUserOrg(userID)
        .then(function(rows) {
            // console.log("getUserOrg result: " + JSON.stringify(rows));
            if (rows.length > 0) {
                flg = "u";
            }

            return sys.insertUserOrg(userID, userKeycloakID, org_id, nick_name, flg)
                .then(function(rows) {
                    // 成功(jsonを返すなど)
                    res.send("OK");
                })
                .catch(function(error) {
                    onRejectted(error, res);
                });
        })
        .catch(function(error) {
            onRejectted(error, res);
        });
}

// Get data from gitlap post
function doExecEventByToken(req, res, next) {
    
    console.log("received data: " + JSON.stringify(req.body));
    // var cmdToken = req.body.cmd_token;
    if (req.body.event_name == "push") {
        childProcess.exec('/home/intahealth/IoT_Server_New/do_event.sh', (error, stdout, stderr) => {
            if(error) {
              // エラー時は標準エラー出力を表示して終了
              console.log(stderr);
              return;
            }
            else {
              // 成功時は標準出力を表示して終了
              console.log(stdout);
            }
          });
          
        res.send("OK");
        return;
    } else {
        res.send("ERR");
        return;
    }
}

function getAWSUserInfo(req, res, next) {
    var userOpenID = req.params.user_id;    // client,userID
    var userID = util.getDecodeArr(userOpenID)[1];
    var clientID = util.getDecodeArr(userOpenID)[0];

    awsData.getUserProfile(userID)
            .then(function(profile) {
                // console.log("aws user profile: " + JSON.stringify(profile));
                // result.followerName = profile.displayName;
                // result.followerId = null;
                // console.log("result: " + JSON.stringify(profile));
                
                // 成功(jsonを返すなど)
                res.send(JSON.stringify(profile));
            })
            .catch(function(error) {
                onRejectted(error, res);
            });
}

router.get("/getUserInfo/:user_id", getAWSUserInfo);
router.get("/checkVersion/:ver_no,:ver_kbn", doCheckVersion);
router.get("/getOrgInfo/:user_id", doGetOrgInfo);
router.get("/torokuUser/:user_id,:org_id,:nick_name", doTorokuUser);
router.post("/execEventByToken", doExecEventByToken);
module.exports = router;
