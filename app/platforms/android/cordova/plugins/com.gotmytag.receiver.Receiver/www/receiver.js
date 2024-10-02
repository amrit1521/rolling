var receiver = {

  onReceive : function(key, success, fail) {
    cordova.exec(success, fail, "Receiver", "onReceive", [ key ]);
  }

}
// receiver

module.exports = receiver;
