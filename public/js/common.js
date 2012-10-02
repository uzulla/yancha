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


// popop window
var ui = {
  isPopup : false,

  // selector object
  overlay : null,
  popup   : null,

  openPopup : function(url, param)
  {
    if (ui.isPopup) return ui.popup;

    ui.isPopup = true;

    var position_top = param.position_top || 0;
    var width  = param.width || innerWidth - 80;

    var height = param.height || innerHeight - 80;
    if (innerHeight < height - 60) height = innerHeight - 60;
    
    var canvas = $('#canvas_view');
    canvas.append('<div id="popup"></div>');
    canvas.append('<div id="overlay"></div>');

    var popup   = $('#popup');
    var overlay = $('#overlay');

    overlay.css({
      "position"        : "absolute",
      "top"             : position_top + "px",
      "left"            : "0px",
      "z-index"         : "99999",
      "width"           : "100%",
      "height"          : "100%",
      "background-color": "#FFFFFF",
      "filter"          : "alpha(opacity=0)",
      "-moz-opacity"    : "0.0",
      "opacity "        : "0.0"
    });

    popup.empty();
    popup.append('<a class="popupClose" href="/">[X]閉じる</a><br />');
    $.ajax({
      url : url,
      method : "get",
      dataType : "html",
      success: function(data, dataType){
        popup.append( data );
      }
    });

    popup.css({
      "position"        : "absolute",
      "border"          : "4px solid #ccc",
      "top"             : (40 + position_top) + "px",
      "left"            : left + "px",
      "z-index"         : "100000",
      "width"           : popup.height() < height ? height + "px" : "auto",
      "height"          : popup.width()  < width  ? width  + "px" : "auto",
      "background-color": "#FFFFFF",
      "padding"         : "2px 2px 2px 2px",
      "filter"          : "alpha(opacity=0)",
      "-moz-opacity"    : "0.0",
      "opacity "        : "0.0"
    }); 

    // centering
    var left = (innerWidth - popup.width()) / 2;
    popup.css({ "left" : left + "px" });


    if (/WebKit/i.test(navigator.userAgent)) {
      popup.fadeTo(0, "0", function(){ popup.fadeTo("500", "1.0") });
      overlay.fadeTo(0, "0", function(){ overlay.fadeTo("500", "0.6") });
    } else {
      popup.fadeTo(500, "1.0");
      overlay.fadeTo(500, "0.6");
    }

    // add event
    $('a.popupClose').click(function(e) {
      e.preventDefault();
      ui.closePopup();
    });

    ui.popup = popup;
    ui.overlay = overlay;
    return popup;
  },

  closePopup : function()
  {
    if (!ui.isPopup) return false;

    ui.popup.fadeTo(500, "0", function(){ ui.popup.remove() });
    ui.overlay.fadeTo(500, "0", function(){ ui.overlay.remove() });

    ui.isPopup = false;
  }
};


