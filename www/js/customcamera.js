var customCamera = {
    getPicture: function(filename, success, failure, options) {
        options = options || {};
        var quality = options.quality || 100;
        var targetWidth = options.targetWidth || -1;
        var targetHeight = options.targetHeight || -1;
        var topMessage = options.topMessage || "";
        cordova.exec(success, failure, "CustomCamera", "takePicture", [filename, quality, targetWidth, targetHeight, topMessage]);
    }
};

module.exports = customCamera;
