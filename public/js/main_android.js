var debug = 0;
var notify = false;

var messagesScroll = null;
var infomationScroll = null;

//user message受信時に呼ばれる
hook.addHook('onUserMessage', function(hash){
});

hook.addHook('doScrollBottom', function(hash){
  $(window).scrollTop(10000000); //TODO 
});


hook.addHook('onConnect', function(hash){
  //Cookieがあれば、オートログインさせる
  autologin();
});

//入力欄の高さ調整
function resizeMessageTextarea(linenum){
  if(!linenum){
    if($("#message").val().match(/\n/)){
      linenum = $("#message").val().match(/\n/g).length + 1;
    }else{
      linenum = 1;
    }
  }
  if(linenum>10){
    linenum=10; // hard limit
  }

  var em = (linenum * 1.2) + 'em';
  $("#message").css('height', em);
  $(window).resize();
}

//各種初期化
$(function () {

  //送信ボタン
  $('#send-message').submit(sendMessage);
  
  //インプット欄の改行制御
	$("#send-message").keypress(function(ev) {
		if ((ev.which && ev.which === 13) || (ev.keyCode && ev.keyCode === 13)) { // 13 is Enter
		  if(ev.shiftKey){
		    return true;//改行を通す
		  }else{
		    $('#send-message').submit();
		    return false;//改行を通さない
		  }
		} else {
			return true;
		}
	}); 
	
	//入力欄の高さ調整
	$('#message').bind("click mouseup blur keyup input", function() {
    resizeMessageTextarea();
  });

  //各エレメントのサイズ計算
  $(window).resize(function(){
  });
  $(window).resize();

  var timeagoTimer = setInterval(function(){
    $('abbr.timeago').timeago();
  },60000);
  
  $("#messages").touchwipe({
       wipeLeft: function() { showControlpad(); },
       wipeRight: function() { showmenu(); },
       //wipeUp: function() { alert("up"); },
       //wipeDown: function() { alert("down"); },
       min_move_x: 30,
       min_move_y: 30,
       preventDefaultEvents: false
  });  


  $("#infomation").touchwipe({
       wipeLeft: function() { hidemenu(); },
       min_move_x: 30,
       min_move_y: 30,
       preventDefaultEvents: false
  });  


  $("#controlpad").touchwipe({
       wipeRight: function() { hideControlpad(); },
       min_move_x: 30,
       min_move_y: 30,
       preventDefaultEvents: false
  });  

});


//--ui
function showControlpad(){
  $('#controlpad').css('width', '100%');

  var w = $('#controlpad').width();
  $('#controlpad').css('top', $(window).scrollTop() + ( $(window).height()-$('#controlpad').height()-150) +'px');
  $('#controlpad').css('right', '-'+w+'px');
  $('#controlpad').css('width', '0px');
  $('#controlpad').show();
  $('#controlpad').animate({right:"0px", width:w+"px"}, 'slow');
}

function hideControlpad(){
  $('#controlpad').animate({right:'-'+$('#infomation').width()+'px'}, 'slow', function(){
    $('#controlpad').hide();
    $('#controlpad').css('width', '0px');
  });
}
function togglemenu(){
  if($('#infomation').css('display')=='none'){
    showmenu();
  }else{
    hidemenu();
  }
}

function showmenu(){
  $('#infomation').css('top', $(window).scrollTop()+'px');
  $('#infomation').css('left', '-'+$('#infomation').width()+'px');
  $('#infomation').show();
  $('#infomation').animate({left:"0px"}, 'slow');
}

function hidemenu(){
  $('#infomation').animate({left:'-'+$('#infomation').width()+'px'}, 'slow', function(){
    $('#infomation').hide();
  });
}
