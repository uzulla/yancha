//JQuery add-on that add an If statement https://gist.github.com/1672273#file_jquery_if_then.js
$.fn.ift = function(){
    var flag = arguments[0];
    var func = arguments[1];
    var else_func = arguments[2];

    if(flag && $.isFunction(func)){
        func.call(this, this);
    }else if(!flag && $.isFunction(else_func)){
        else_func.call(this, this);
    }
    return this;
}

//html escape
function h(s){return s.replace(/[&<>"']/g,function(m){return "&#"+m.charCodeAt(0)+';'})}

//for InternetExplorer(don't have console.log())
if(typeof console != 'object'){ var console = {'log': function(){}}; } // hehe

//get keys
$.extend({
  keys: function(obj){
    var a = [];
    $.each(obj, function(k){ a.push(k) });
    return a;
  }
});

// get 'http://yancha-server.example:3000/' 
function getHostRootURL(){
  return location.href.match(/http(s)?:\/\/[a-zA-Z0-9\-\.]*(:[0-9]{1,5})?/)[0];
}


// popup window
$.fn.yanchaPopup = function (opt) {

  var param = $.extend({
    position_top: 0,
    width  : innerWidth - 80,
    height : innerHeight - 80
  }, opt);

  this.each(function(){
    var $target = $(this);
    var url = $target.attr('href');
    param.position_top = $target.scrollTop() || 0;
    
    $target.click(function(e){
      e.preventDefault();
      var $popup   = $('#popup');
      var $overlay = $('#overlay');

      $.ajax({
        url : url,
        method : "get",
        dataType : "html"
      }).done(function(data, dataType){
        $popup.html( data );
        $popup.css({
          "top"    : (40 + param.position_top) + "px",
          "left"   : "20px",
          "width"  : $popup.height() < param.height ? param.height + "px" : "auto",
          "height" : $popup.width()  > param.width  ? param.width  + "px" : "auto",
        }); 

        // centering
        var left = (innerWidth - $popup.width()) / 2;
        $popup.css({ "left" : left + "px" });
        $overlay.css({"top" : param.position_top + "px" });

        if (/WebKit/i.test(navigator.userAgent)) {
          $popup.fadeTo(0, "0", function(){ $popup.fadeTo("500", "1.0") });
          $overlay.fadeTo(0, "0", function(){ $overlay.fadeTo("500", "0.6") });
        } else {
          $popup.fadeTo(500, "1.0");
          $overlay.fadeTo(500, "0.6");
        }

        $('a.popupClose, #overlay').click(function(e) {
          e.preventDefault();
          function closePopup() {
            $popup.fadeTo  (500, "0", function(){ $popup.hide()   });
            $overlay.fadeTo(500, "0", function(){ $overlay.hide() });
          };
          closePopup();
        });

      }).error(function(res){
        console.log('network error');
      });
    });
    return this;
  });
}
