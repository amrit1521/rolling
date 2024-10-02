(function ($) {
  window.onerror = function(msg, url, line) {
    $.ajax({
      url: "https://test.gotmytag.com/error",
      type: "POST",
      dataType: "JSON",
      data: {
        url: url,
        line: line,
        message: msg
      }
    });
    console.log("ERROR in ", url, " (line #", line, "): ", msg);
    return false; //suppress Error Alert;
  };
})(jQuery);
