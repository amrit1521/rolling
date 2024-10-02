if (typeof cordova != 'undefined') {
    cordova.define("cordova/plugin/checkkey", function (require, exports, module) {
        var exec = require("cordova/exec");
        module.exports = {
            get: function (win, fail) {
                exec(win, fail, "CheckKey", "get", []);
            }
        };
    });
}
