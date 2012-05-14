var debug = 0;
var notify = false;

var messagesScroll = null;
var infomationScroll = null;

//user message受信時に呼ばれる
hook.addHook('onUserMessage', function(hash){
  refreshAllScroll();
  messagesScroll.scrollToElement('#lines div:last-child', 100);
});

function refreshAllScroll(){
  if(messagesScroll != null){ messagesScroll.refresh(); }
  if(infomationScroll != null){ infomationScroll.refresh(); }

}


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
  
      $("#messages").css('height','384px');
      $("#infomation").css('height','384px');
      $("#infomation").hide('slow');
      
      $("#send-message").css('bottom', '0px');

  });
  $(window).resize();


  var timeagoTimer = setInterval(function(){
    $('abbr.timeago').timeago();
  },60000);
  var timeagoTimer = setInterval(function(){
    refreshAllScroll();
  },2000);

  //Cookieがあれば、オートログインさせる
  autologin();
  
  messagesScroll = new iScroll('messages');
  infomationScroll = new iScroll('infomation');   
   
});

