// 新方式「Apple Push Notification Authentication Key」利用
var apn = require('node-apn-http2');

// アプリのバンドルID
const bundleID = 'jp.co.intasect.IntaHealth';
// // 端末のデバイストークン
// const deviceTokenTest = 'a0d7c999063fad5e2066bb77e910769228e88d29c6783e8d14867f0eb4d9cde1';

var options = {
    token: {
      key: "/home/intahealth/IoT_Server_New/iot_apns_authkey.p8",
      keyId: "SG598P4ZR7",
      teamId: "669XTYQTN3"
    },
    production: true,
    hideExperimentalHttp2Warning: true // the http2 module in node is experimental and will log 
                                       // ExperimentalWarning: The http2 module is an experimental API. 
                                       // to the console unless this is set to true
  };
  
var apnProvider = new apn.Provider(options);

module.exports = {
    // プッシュメッセージ発送
    sendMessage: function(deviceToken, notifyData) {
        // console.log('http2 options: ' + JSON.stringify(options));
        try{
            var notifyObj = JSON.parse(notifyData) 
            var note = new apn.Notification();

            note.expiry = Math.floor(Date.now() / 1000) + 3600; // Expires 1 hour from now.
            note.badge = notifyObj.aps.badge;
            note.sound = notifyObj.aps.sound;
            note.alert = notifyObj.aps.alert.body;
            note.topic = bundleID;

            apnProvider.send(note, deviceToken).then( (result) => {
                // see documentation for an explanation of result
                console.log("apns push ok.");
              }).catch(function(error) {
                console.dir(error);
              });
        }
        catch(ex) {
            console.log("pushNotify has error:");
            console.log(ex);
        }
    }

}
