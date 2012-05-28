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


