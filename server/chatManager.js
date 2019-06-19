var express = require("express");
var group = require("../models/group.js");
var awsData = require("../models/dynamoData.js");
var pushNotify = require("../models/pushNotify2.js");
var sys = require("../models/sys.js");
var util = require("../util.js");
var router = express.Router();
var webclient = require('request');

var ioServer = null;
var server = null;
var readyFlg = false;

var userSockets = {};
var userDevToken = {};
var userAppVer = {};
var userNewCnt = {};

// // サービス立ち上げ
function doReady(req, res, next) {
    if (req.params.user_id) {
        // var arr = getDecodeArr(req.params.user_id)
        // if(arr.length != 2){
        //     console.log("invalid user_id: " + req.params.user_id);
        //     res.send({rtn:'chat service is stated.'});
        // } else {
        //     var clientID = arr[0];
        //     var userID = arr[1];
            
        //     checkAuth(userID, function(result) {
        //         res.send({rtn:result});
        //     });
        // }
        var userID = util.getDecodeUserID(req.params.user_id);
        if (userID != null) {
            // var clientID = util.getDecodeUserID(req.params.user_id, "aud");
            
            checkAuth(userID, function(result) {
                res.send({rtn:result});
            });
        }
    } else {
        res.send({rtn:'chat service is ok.'});
    }
    if (readyFlg == true) {
        return;
    }

    // // ユーザーのトークンを初期ロードする
    // sys.getAllUserToken().then(function(rows) {
    //     // console.log("User deviceTokens: " + JSON.stringify(rows));
    //     for (var i = 0; i < rows.length; i++) {
    //         var row = rows[i]; 
    //         userDevToken[row["user_id"]] = row["dev_token"];
    //     }
    //     console.log("User deviceTokens: " + JSON.stringify(rows));
    // })
    // .catch(function(error) {
    //     console.log("getAllUserToken error_f=" + JSON.stringify(error)); //エラー時
    // });

    // ソケットメソッド
    ioServer.sockets.on('connection', function(socket) {
        console.log(Date.now() + ' conection is created.');
        
        var newMsgCnt = 0;
        socket.on('disconnect', function(){
            // console.log(Date.now() + ' conection is disconnected.');
            if (socket.name) {
                console.log(socket.name + 'が切断しました。');
                // if (socket.disconnected == true) {
                //     console.log("OnDisconnect: " + socket.name + " is disconnected.");
                // }
                if (socket.connected == true) {
                    console.log("OnDisconnect: " + socket.name + " is connected.");
                }
                // userSockets[socket.name] = null;
                // delete userSockets[socket.name];
            }
        });

        socket.on('enter', function(data){
            console.log(socket.name + ' is enter Chat Room.');

            getInitNewMsgInfo(socket, data.user_id);
        });

        // Javaサーバ廃棄後、チャット用（doTestの代わりに）
        socket.on('chat', function(data){
            // console.log('Chat data: ' + JSON.stringify(data));
            chatSub(data);
        })

        socket.on('online', function (data) {
            // var arr = getDecodeArr(data.user_id);
            // if (arr.length == 0) {
            //     console.log("CurrentUser is unknown. " + JSON.stringify(data));
            //     // getInitNewMsgInfo(null, null);
            //     return;
            // }
            // var clientID = arr[0];
            // var userID = arr[1].toLowerCase();
            var userID = util.getDecodeUserID(data.user_id);
            // var userID = data.user_id;
            console.log("User is online. CurrentUser: " + userID);
            // console.log(userID + " device token: " + data.dev_token);
            // // Test code
            // var decodeUID = new Buffer("u-tokyo,img_01").toString('base64');
            // console.log("東大先生OpenId: " + decodeUID);

            // user_idを保存する
            socket.name = userID;

            // if (!userSockets[userID]) {
                userSockets[userID] = socket;
            // }
            if (data.dev_token) {
                updateUserToken(userID, data.dev_token, data.app_ver);
            }
            // console.log("受信されたToken: " + JSON.stringify(userDevToken));
            // for (key in userSockets) {
            //     console.log("接続中：userSockets[" + key + "]");
            // }

            // ユーザーの未読メッセージ情報を返す
            getInitNewMsgInfo(socket, data.user_id);

            // newMsgCnt = 3;
            // var newMsg = [{titelID: "topic-1", newCnt: 2}, {titelID: "topic-2", newCnt: 1}];
            // socket.emit('newMsgInfo', {user: "img_01", cnt: newMsgCnt, detail: newMsg},
            //         function (data) {console.log('newMsgInfo: ' + data);});
        });

    });
    readyFlg = true;
}

function getInitNewMsgInfo(userSocket, userOID) {
    if (userSocket == null) {
        // userSocket.emit('newMsgInfo', "{}");
        return;
    }
    var userID = util.getDecodeUserID(userOID);
    var clientID = util.getDecodeUserID(userOID, "aud");
    var userOpenID = new Buffer(clientID + "," + userID).toString('base64');
    console.log("GetInitNewMsgInfo userOpenID: " + userOpenID);

    webclient.get({
        url: "https://health.intasect.com/IoTManagement/getchatalertcountbyuser.do",
        qs: {
            openid: userOpenID
        }
    }, function(error, response, body) {
        if (error == null) {
            console.log("getInitNewMsgInfo success:");
            var res = {};
            try {
                res = eval(JSON.parse(body));
                console.log("未読件数：" + JSON.stringify(res));
            } catch(e) {
                console.log(e);
                return;
            }

            // 自分の未読件数初期化
            for (op in userNewCnt) {
                userNewCnt[op][userSocket.name] = 0;
            }
            // 全未読件数を設定
            var sendData = {};
            var tasks = [];
            for (var i = 0; i < res.length; i++) {
                var item = res[i];
                // console.log("item: " + JSON.stringify(item));
                var staffOpenID = item["openid"];
                console.log("staffOpenID: " + staffOpenID);

                // sendData[staffOpenID] = {}
                // sendData[staffOpenID].cnt = item["cnt"];

                var staff = util.getDecodeArr(staffOpenID)[1]; 
                if (!userNewCnt[staff]) {
                    userNewCnt[staff] = {}
                    userNewCnt[staff][userSocket.name] = 0;
                }
                userNewCnt[staff][userSocket.name] = userNewCnt[staff][userSocket.name] + parseInt(item["cnt"]);

                var task = function(user_id, staff_id, cnt) {
                    return (group.getFollowedMsg(user_id, staff_id)
                        .then(function(rows) {
                            // console.log("keys:[" + user_id + "," + staff_id + "], getMessage: " + JSON.stringify(rows));
                            if (rows.length > 0) {
                                sendData[staffOpenID] = rows[0];
                                sendData[staffOpenID].cnt = parseInt(cnt);
                            }
                        })
                        .catch(function(error) {
                            console.log("error_f=" + JSON.stringify(error)); //エラー時
                        }));
                };
                tasks.push(task(userSocket.name, staff, item["cnt"]));
            }

          //  console.log('User Cnts: ' + JSON.stringify(userNewCnt));
            Promise.all(tasks).then(function () {
                console.log("newMsgInfo Init SendData : " + JSON.stringify(sendData));
                if (userSocket.disconnected == true) {
                    console.log(userSocket.name + " is disconnected.");
                }
                if (userSocket.connected == true) {
                    console.log(userSocket.name + " is connected.");
                }
                userSocket.emit('newMsgInfo', sendData);
                // userSocket.emit('newMsgInfo', sendData,
                //     function (data) {console.log('newMsgInfo: ' + data);}
                //);
            });
        } else {
            console.log("getInitNewMsgInfo error:");
            console.log(error);
        }
        console.log("----------------------------------------");
    });
}

function updateUserToken(user_id, dev_token, app_ver) {
    if (userDevToken[user_id]) {
        if (userDevToken[user_id] != dev_token || userAppVer[user_id] != app_ver ) {
            userDevToken[user_id] = dev_token;
            userAppVer[user_id] = app_ver;
            console.log("table userToken is updated. appVer:" + app_ver);
            sys.updateUserToken(user_id, dev_token, app_ver);
        }
    } else {
        userDevToken[user_id] = dev_token;
        userAppVer[user_id] = app_ver
        sys.updateUserToken(user_id, dev_token, app_ver);
    }
}

function getMessage(user_id, staff_id, callback) {
    var result = {};
    group.getFollowedMsg(user_id, staff_id)
        .then(function(rows) {
            console.log("keys:[" + user_id + "," + staff_id + "], getMessage: " + JSON.stringify(rows));
            if (rows.length > 0) {
                result.newestMsg = rows[0].newestMsg;
                result.dateText = rows[0].dateText;
                result.staffName = rows[0].staffName;
                result.followerId = rows[0].followerId;
            }
            if (result.followerId) {
                console.log("result.followerId: " + result.followerId);
                awsData.getUserProfile(result.followerId)
                .then(function(profile) {
                    // console.log("aws user profile: " + JSON.stringify(profile));
                    result.followerName = profile.displayName;
                    result.followerId = null;
                    console.log("result: " + JSON.stringify(result));
                    
                    callback(result);
                })
                .catch(function(error) {
                    console.log("error_aws=" + JSON.stringify(error)); //エラー時
                });
            } else {
                callback(result);
            }
        })
        .catch(function(error) {
            console.log("error_fgm=" + JSON.stringify(error)); //エラー時
        });
}

// 権限チェック
function checkAuth(userID, callback) {
    // res.send("param1:" + req.params.org_id + ", param2:" + req.params.user_id);

    group.getOrgStaffInfo(userID)
        .then(function(rows) {
            if (rows.length > 0) {
                callback("manager");
            } else {
                callback("user");
            }
        })
        .catch(function(error) {
            console.log("error_f=" + JSON.stringify(error)); //エラー時
        });
}

// toID: chat先、oppOpenID: chat元(from)
function getNewMsgInfo(toID, oppOpenID, pushFlg) {
    var arr = util.getDecodeArr(oppOpenID);
    var userSocket = userSockets[toID];
    var clientID = arr[0];
    var opponent = arr[1];
    if (!userNewCnt[opponent]) {
        userNewCnt[opponent] = {};
        userNewCnt[opponent][toID] = 0;
    }
    if (!userNewCnt[opponent][toID]) {
        userNewCnt[opponent][toID] = 0;
    }

    // ユーザーの未読メッセージ情報を返す
    var newMsgCnt = userNewCnt[opponent][toID];
    var sendData = {};

    getMessage(toID, opponent, function(rowdata) {
        // console.log("callback: " + JSON.stringify(rowdata));
        // if (!rowdata["newestMsg"]) {
        //     sendData[oppOpenID].msg = "";
        //     sendData[oppOpenID].date = "";
        // } else {
        //     sendData[oppOpenID].msg = rowdata.newestMsg;
        //     sendData[oppOpenID].date = rowdata.dateText;
        // }
        sendData[oppOpenID] = rowdata;
        sendData[oppOpenID].cnt = newMsgCnt;

        console.log("Emit SendData : " + JSON.stringify(sendData));
        if (userSocket != null) {
            userSocket.emit('newMsgInfo', sendData);
        }
        if (pushFlg == true) {
            var deviceToken = userDevToken[toID];
            
            // // test code
            // deviceToken = 'a0d7c999063fad5e2066bb77e910769228e88d29c6783e8d14867f0eb4d9cde1';

            console.log("Notify target: " + toID + ", deviceToken: " + deviceToken);
            if (deviceToken) {
                var msg = "";
                if (rowdata.staffName) {
                    msg = rowdata.staffName + "：" + rowdata.newestMsg;
                    
                } else if (rowdata.followerName) {
                    // フォロー者からの新メッセージ
                    msg = "[フォロー者]" + rowdata.followerName + "：" + rowdata.newestMsg;
                }
                var pushData = '{"aps":{"alert":{"body":"'+ msg + '"}'
                            + ',"sound": "default"'
                            + ',"badge": ' + newMsgCnt
                            + '}}';
                console.log("Push通知データ：" + pushData);
                pushNotify.sendMessage(deviceToken, pushData);
            }
        }
        // userSocket.emit('newMsgInfo', sendData,
            // function (data) {console.log('newMsgInfo: ' + data);});
    });
}

// function chat(userSocket, from, to, req, res, next) {

//     userSocket.emit('chat', {from: from, to: to, topic: req.params.topic, msg: "test"});
// }

function chatSub(chatData) {
    var fromOpenID = chatData.from;
    // var to = 'test';
    var toOpenID = chatData.to;
    var from = util.getDecodeArr(fromOpenID)[1];
    // var from = util.getDecodeUserID(fromOpenID);
    var to = util.getDecodeArr(toOpenID)[1];

    var client = userSockets[to];
    // console.log("clients: " + clients);
    var data = {from: fromOpenID, to: toOpenID, topic: chatData.topic, msg: chatData.msg}
    //.emit('chat', data);

    if (!userNewCnt[from]) {
        userNewCnt[from] = {};
        userNewCnt[from][to] = 0;
    }
    if (!userNewCnt[from][to]) {
        userNewCnt[from][to] = 0;
    }
    if (!client || client.disconnected == true) {
        console.log("user[" + to + "] is offline.");
        // システム通知
        userNewCnt[from][to] = userNewCnt[from][to] + 1;
        getNewMsgInfo(to, fromOpenID, true);
    } else {
        client.emit('chat', data, 
            function (resdata) {
                // console.log('Chat 返事: ' + resdata);
                // console.log('User New Cnt: ' + JSON.stringify(userNewCnt));

                if (resdata == "leave") {
                    userNewCnt[from][to] = userNewCnt[from][to] + 1;
                    console.log('User New Cnt 更新後: ' + JSON.stringify(userNewCnt));
                    getNewMsgInfo(to, fromOpenID);
                } else if (resdata != "OK") {
                    userNewCnt[from][to] = userNewCnt[from][to] + 1;
                    console.log('User New Cnt 更新後: ' + JSON.stringify(userNewCnt));
                    getNewMsgInfo(to, fromOpenID, true);
                }
            });
    }
}

function doTest(req, res, next) {
    // var ioClient = ioServer

    // console.log("IoServer: " + ioServer);

    //var socket = ioClient.connect();
    var chatData = {}
    chatData.from = req.params.from;    // clientID + , + userID のエンコード
    chatData.to = req.params.to;        // clientID + , + userID のエンコード
    chatData.topic = req.params.topic;
    chatData.msg = "test";

    chatSub(chatData);

    res.send('process test');
}

router.get("/listenService", doReady);
router.get("/listenService/:user_id", doReady);
router.get("/test/:from,:to,:topic", doTest);
module.exports = router;
module.exports.init = function( http_server ) {
	server = http_server;
    ioServer = require('socket.io').listen(server);
    ioServer.set('heartbeat interval', 5000);
    ioServer.set('heartbeat timeout', 15000);
    // ioServer.set('polling duration', 10)
    readyFlg = false;
    
    // ユーザーのトークンを初期ロードする
    sys.getAllUserToken().then(function(rows) {
        // console.log("User deviceTokens: " + JSON.stringify(rows));
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i]; 
            userDevToken[row["user_id"]] = row["dev_token"];
            userAppVer[row["user_id"]] = row["app_ver"];
        }
        // console.log("User deviceTokens: " + JSON.stringify(userDevToken));
    })
    .catch(function(error) {
        console.log("getAllUserToken error_f=" + JSON.stringify(error)); //エラー時
    });
    
};

