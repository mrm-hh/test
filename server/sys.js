var db = require("../db.js");

// const csv = require('csv');
const fs = require('graceful-fs');

module.exports = {
    checkFlgFile: function(fnm,org_id) {
        return new Promise(function(resolve, reject) {
            try {
                fs.statSync(fnm + ".flg");
                reject("Processing");
                
            } catch(err) {
                // 制御ファイルを生成
                fs.appendFileSync(fnm + ".flg", "");
                resolve(org_id);
            }
        });
    },

    removeFlgFile: function(fnm) {
        return new Promise(function(resolve, reject) {
            try {
                // 制御ファイルを削除
                fs.unlinkSync(fnm + ".flg");
            } catch(err) {
                console.log(fnm+".flg is delete error.");
                // reject(err);
            }
            resolve("OK");
        });
    },

    initCsvFile: function(fnm) {
        return new Promise(function(resolve, reject) {

            try {
                fs.statSync(fnm);
                fs.unlinkSync(fnm);
                // const writableStream = fs.createWriteStream('output.csv', {encoding: 'utf-8'});
                // resolve(writableStream);
                resolve("OK");
            } catch(err) {
                resolve("Not exist");
            }
        });
    },

    outputCsv: function(fnm, data) {
        return new Promise(function(resolve, reject) {
            try {
                data += "\n";
                // fs.appendFile(fnm, data, function(err){
                //     if (err) {
                //         reject(err);
                //     }
                //     resolve(1);
                // })
                fs.appendFileSync(fnm, data);
                resolve(1);
            } catch(err) {
                reject(err);
            }
        });
    },

    csv2mysql: function(fnm) {
        return new Promise(function(resolve, reject) {
            db.connect();
            var fields = " (user_kid,date,path,dev,value,upd_date) "
            var sqlStr =
                'LOAD DATA LOCAL INFILE ? IGNORE INTO TABLE ?? CHARACTER SET utf8 ' +
                'FIELDS TERMINATED BY ? IGNORE 1 LINES ' + fields


            db.query(sqlStr, [fnm, "IotDevDaySum", '\t'], function(err, result, fields) {
                        // if (err) {
                        //     console.log("err: " + JSON.stringify(err));
                        //     // reject(err);
                        // } else {
                            console.log("csv2mysql is success.");
                            // resolve("OK");
                        // }
                        resolve("OK");
                    });
            
            db.disconnect(function(){
                console.log("Import完了！");
                // resolve("OK");
            });
        });
    },


    // IotSystemテーブルを検索する
    getVerInfo: function(appID, ver, subVer, kbn = '1') {
        return new Promise(function(resolve, reject) {
            // console.log('test2');
            db.connect();
            var query = "select * from IotSystem "
                        + "where appID = ? "
                        // + "  and (version > ? or (version = ? and subversion > ?)) "
                        + "  and concat(version,'.',subversion) > ? "
                        + "  and releaseDay < DATE_FORMAT(NOW(), '%Y-%m-%d') "
                        + "  and kbn = ? ";
            db.getData(query, [appID, ver+"."+subVer, kbn], function(row) {
                console.log("バージョン情報: " + JSON.stringify(row));
                resolve(row);
            });
            
            db.disconnect();
        });
    },

    // IotUserOrgテーブルを検索する
    getUserOrg: function(user_id) {
        return new Promise(function(resolve, reject) {
            console.log('get IotUserOrg data.');
            db.connect();
            var query = "select * from IotUserOrg "
                        + "where user_id  = ? ";
            db.getData(query, [user_id], function(row) {
                // console.log('test3');
                resolve(row);
            });
            
            db.disconnect();
        });
    },

    // IotUserOrgテーブルを検索する
    getOrgUserList: function(org_id) {
        return new Promise(function(resolve, reject) {
            console.log('get IotUserOrg datas.');
            db.connect();
            var query = "select user_id, org_id, kid from IotUserOrg "
            query += "where user_id not like '%test' and user_id != 'img_01' ";
            query += " and user_id != 'nnuser' and user_id != 'kkuser' and user_id != 'oskuuser' and user_id != 'snnuser' "
            if (org_id != "*") {
                query += " and org_id = '" + org_id + "'";
            }
            console.log("getOrgUserList sql: " + query);
            db.getData(query, [], function(row) {
                // console.log('getOrgUserList result: ' + JSON.stringify(row));
                resolve(row);
            });
            
            db.disconnect();
        });
    },

    // ユーザーtoken取得
    getAllUserToken: function() {
        return new Promise(function(resolve, reject) {
            console.log('select device token of all useres.');
            db.connect();
            
            var query = "select user_id, dev_token, app_ver from IotUserOrg "
                        + "where dev_token is not null ";
            db.getData(query, [], function(row) {
                // console.log('test3');
                resolve(row);
            });
            
            db.disconnect();
        });
    },

    // IotUserOrgテーブルのtokenを更新する
    updateUserToken: function(user_id, dev_token, app_ver) {
        return new Promise(function(resolve, reject) {
            console.log('update user device token. app_ver:' + app_ver);
            db.connect();
            
            var sqlStr = "update IotUserOrg set dev_token = ?, app_ver = ?, upd_date = DATE_FORMAT(NOW(), '%Y-%m-%d %T') "
                    + "where user_id = ? ";
            db.query(sqlStr, [dev_token, app_ver, user_id], function(row) {
                // console.log('deleted ' + result.affectedRows + ' rows');
                resolve(row);
            });
            
            db.disconnect();
        });
    },

    // IotUserOrgテーブルへinsertする
    insertUserOrg: function(user_id, keycloak_id, org_id, nick_name, flg = 'i') {
        return new Promise(function(resolve, reject) {
            console.log('toroku user org. flg:' + flg);
            db.connect();
            var data = {};
            data.user_id = user_id;
            data.org_id = org_id;
            data.nick_name = nick_name;
            data.kbn = "";
            data.kid = keycloak_id;
            if (flg == 'i') {
                db.insert("IotUserOrg", data, function(row) {
                    resolve(row);
                });
            } else {
                var sqlStr = "update IotUserOrg set org_id = ?, nick_name = ?, upd_date = DATE_FORMAT(NOW(), '%Y-%m-%d %T') "
                      + "where user_id = ? ";
                db.query(sqlStr, [org_id, nick_name, user_id], function(row) {
                    // console.log('deleted ' + result.affectedRows + ' rows');
                    resolve(row);
                });
            }
            db.disconnect();
        });
    },

    // アプリバージョンが低いユーザーtoken取得
    getLowVerUserToken: function(now_ver) {
        return new Promise(function(resolve, reject) {
            console.log('select device token of these users that app version is low.');
            db.connect();
            
            var query = "select dev_token from IotUserOrg "
                        + "where dev_token is not null "
                        + "  and (app_ver is null or app_ver < ?)";
            db.getData(query, [now_ver], function(row) {
                // console.log('success.');
                resolve(row);
            });
            
            db.disconnect();
        });
    },

}
