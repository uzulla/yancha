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

// get 'http://yairc.cfe.jp:3000/' 
function getHostRootURL(){
  return location.href.match(/http(s)?:\/\/[a-zA-Z0-9\-\.]*(:[0-9]{1,5})?/)[0];
}


//ポップアップウィンドウ
var ui = {
    isPopup : false,

    openPopup : function(target, param)
    {
        ui.isPopup = true;

        left = (innerWidth - param.width) / 2;
        left = left + "px";
        width  = param.width + "px";
        height = param.height + "px";
        position_top = param.position_top || 0;
        $("#canvas_view").append('<div id="popup"></div>');
        $("#canvas_view").append('<div id="overlay"></div>');

        $("#popup").css({
                "position"        : "absolute",
                "border"          : "4px solid #ccc",
                "top"             : (40 + position_top)+ "px",
                "left"            : left,
                "z-index"         : "100000",
                "width"           : width,
                "height"          : height,
                "background-color": "#FFFFFF",
                "padding"         : "2px 2px 2px 2px",
                "filter"          : "alpha(opacity=0)",
                "-moz-opacity"    : "0.0",
                "opacity "        : "0.0"
            }); 
        $("#overlay").css({
                "position"        : "absolute",
                "top"             : position_top + "px",
                "left"            : "0px",
                "z-index"         : "99999",
                "width"           : "100%", //$(document).width() + "px",
                "height"          : "100%", //$(document).height() + "px",
                "background-color": "#FFFFFF",
                "filter"          : "alpha(opacity=0)",
                "-moz-opacity"    : "0.0",
                "opacity "        : "0.0"
            });


        if (/WebKit/i.test(navigator.userAgent)) {
            $("#popup").fadeTo(0, "0", function(){$("#popup").fadeTo("500", "1.0")});
            $("#overlay").fadeTo(0, "0", function(){$("#overlay").fadeTo("500", "0.6")});
        } else {
            $("#popup").fadeTo(500, "1.0");
            $("#overlay").fadeTo(500, "0.6");
        }
        return $("#popup");
    },

    closePopup : function()
    {
        if (!ui.isPopup) return false;

        $("#popup").fadeTo(500, "0", function(){ $("#popup").remove() });
        $("#overlay").fadeTo(500, "0", function(){ $("#overlay").remove() });

        ui.isPopup = false;
    }
};

function openPopup( url, param ) {
    width  = param.width || innerWidth - 80;
    height = param.height || innerHeight - 80;

    //popup_window = window.open(url,  'windowname', 'width='+w_width+',height='+w_height);

    if (innerHeight < height - 60) height = innerHeight - 60;
    popup = ui.openPopup('#canvas_view', {
                position_top : $(this).scrollTop(),
                width  : width,
                height : height
            });

    popup.html('');
    popup.append('<a class="close" href="javascript:void(0);" onClick="closePopup();">[X]閉じる</a><br />');
    popup.append( getContents( url ) );

    if (popup.height() > height) {
        popup.css({"height" : height + "px", "overflow-y" : "scroll", "overflow-x" : "auto"});
    } else {
        popup.css({"height" : "auto", "overflow-y" : "auto", "overflow-x" : "auto"});
    }
}

function closePopup() {
    ui.closePopup();
}

function getContents( url ) {
    req = new XMLHttpRequest();
    req.open( 'get', url, false );
    req.onreadystatechange = function() {
        if ( req.readyState == 4 && req.status == 200 ) {
            var result = req.responseText;
        }
    }
    req.send('');
    return ( req.responseText );
}

