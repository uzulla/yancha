var hook = {};
hook.hooks={};

hook.addHook = function(name, func){
  if(typeof(hook.hooks[name])=='undefined'){
    hook.hooks[name] = [];
  }
  hook.hooks[name].push(func);
  
}

hook.doHook = function(name, params){
  if(typeof(hook.hooks[name])=='undefined'){return;}
  var list = hook.hooks[name];
  
  for(var i=0; list.length>i; i++){
    list[i](params);
  }
}

