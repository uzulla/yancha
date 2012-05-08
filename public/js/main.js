var socket = io.connect();
var data = {
  token:false,
  nick:false,
  profile_image_url:false,
  tags:{PUBLIC:0}
};
var debug = 0;
var notify = false;

//各種接続、切断、エラーイベント
socket.on('connect', function () {
  $('#chat').addClass('connected');
});
socket.on('reconnect', function () {
  if(debug){message('System', 'Reconnected to the server');}
  if(data.token){
    console.log('try create session');
    socket.emit('token_login', data.token);
  }
});
socket.on('reconnecting', function () {
  if(debug){message('System', 'Attempting to re-connect to the server');}
});
socket.on('error', function (e) {
  if(debug){
    console.log("disconnected");
    message('System', e ? e : 'A unknown error occurred');
  }
});

//サーバからのアナウンス
socket.on('announcement', function (msg) {
  if(debug){
    $('#lines').append($('<p>').append($('<em>').text(msg)));
    $('#lines').get(0).scrollTop = 10000000;  
  }
});

//サーバから、参加ニックネームリストの更新
socket.on('nicknames', function (nicknames) {
  $('#nicknames').empty();
  for (var i in nicknames) {
    $('#nicknames').append($('<b>').text(nicknames[i]));
  }
  $(window).resize();
});

//サーバー側にニックネーム登録がない場合に本処理
//messageは再送する為にサーバーから戻されたテキスト、分かりづらく、設計の筋がよくない。
socket.on('no session', function (message) {
  if(data.token){
    console.log('try register');
    socket.emit('token_login', data.token, function (status) {
      if(status && message){ //メッセージを再送する
        socket.emit('user message', message);
      }
    });
  }else{
    alert('ログインしていません、リロードしてログインをやり直してください。');
  }
});


//メッセージイベント
socket.on('user message', function(hash){
  if ( notify && hash.nickname != data.nick && !hash.is_message_log ) {
    $.jwNotify({
      image : hash.profile_image_url,
      title: hash.nickname,
      body: hash.text,
      timeout: 10000
    });
  }
  
  for(var i=0; hash.tags.length > i; i++){
    if(typeof(data.tags[hash.tags[i]]) != 'undefined' ){
      data.tags[hash.tags[i]] = hash.created_at_ms ;
    }
  }
  
  if(hash.profile_image_url.length>0){
    var img = $('<img style="float:left;margin:3px;">').attr('src', hash.profile_image_url);
  }else{
    var img = $('<img style="float:left;margin:3px;width:48px;height:48px;" src="/img/nobody.png">');
  }
  var from = $('<span style="font-weight:bold;">').text(hash.nickname);
  
  var message = h(hash.text);
  //auto inline display(pyazo)
  message = message.replace(/http(s)?:\/\/yairc.cfe.jp:5000(\/[\x21-\x7e]+)/gi, "<a href='//yairc.cfe.jp:5000$2' target='_blank'><img src='//yairc.cfe.jp:5000$2' style='max-width:300px;max-height:300px;'/></a>");

  // YT thumbnail
  message = message.replace(/http(s)?:\/\/www.youtube.com\/[\x21-\x7e]*v=([a-zA-Z0-9\-]+)/g, "<img src='//i1.ytimg.com/vi/$2/default.jpg'><br />http://www.youtube.com/watch?v=$2");

  //auto link
  message = message.replace(/(http(s)?:\/\/[\x21-\x7e]+)/gi, "<a href='$1' target='_blank'>$1</a>");

  message = message.replace(/&#62;\|javascript\|\n([\s\S]*)\n\|\|&#60;/g,
    function(whole,s1) {
      foundShHighlight = true;
　　　 return( '<pre class="sh_javascript">' + s1 + '</pre>' );
　　　}
  );
  
  var foundShHighlight = false;

  message = message.replace(/&#62;\|perl\|\n([\s\S]*)\n\|\|&#60;/g,
    function(whole,s1) {
      foundShHighlight = true;
　　　 return( '<pre class="sh_perl">' + s1 + '</pre>' );
　　　}
  );

  message = message.replace(/&#62;\|AA\|\n([\s\S]*)\n\|\|&#60;/gi,
    function(whole,s1) {
　　　 return( '<pre style=\'font-family: "MS Pゴシック","MS ゴシック",sans-serif;\'>' + s1 + '</pre>' );
　　　}
  );

  message = message.replace(/&#62;\|\|\n([\s\S]*)\n\|\|&#60;/g,
    function(whole,s1) {
　　　 return( '<pre>' + s1 + '</pre>' );
　　　}
  );
  
  message = message.replace(/&#62;&#62;\n([\s\S]*)\n&#60;&#60;/g,
    function(whole,s1) {
　　　 return( '<pre>' + s1 + '</pre>' );
　　　}
  );  
  
  message = message.replace(/\n/g, "<br />");
  
  var text = $('<div style="overflow: hidden;">').html(message);
  
  var time = $('<span style="float:right">').append(
    $('<abbr class="timeago">')
      .attr('title', moment(hash.created_at_ms/100).format("YYYY-MM-DDTHH:mm:ss")+"Z+09:00")
      .text("("+moment(hash.created_at_ms/100).format('YYYY-MM-DD HH:mm')+")")
      .timeago()
  );
  
  
  $('#lines').append(
    $('<p>')
      .append(img, from, $('<br>'),text, $('<br>'), time, $('<br style="clear:both">'))
      .on('mouseover', function(){
        $(this).removeClass('unread');
        $(this).off('mouseover');
        updateTitle();
      })
      .ift(!hash.is_message_log, function(){ //ログか、現在の投稿か
        $(this).addClass('unread');
      })
  );
  
  if($('#lines p').length>100){
    $('#lines p:first').remove();
  }
  
  $('#lines').get(0).scrollTop = 10000000;  
  if(foundShHighlight){
    sh_highlightDocument();
  }
  
  if(!hash.is_message_log){ //ログか、現在の投稿か
    soundMessage();
  }
  
  updateTitle();

});

function updateTitle(){
  var unreadnum = $('#lines p.unread').length;
  var prefix = '';
  if(unreadnum>0){
    prefix = "("+unreadnum+")";
  }
  document.title = prefix+"yairc";
}

//テキスト入力欄をクリア、ただし、タグは残しておく
function clear () {
  var tag_list = ($('#message').val().match(/#[a-zA-Z0-9]+/g, '#')!=null)? $('#message').val().match(/#[a-zA-Z0-9]+/g, '#'): [];
  var str  = tag_list.join(' ');
  $('#message').val(' '+str).focus();
  $('#message')[0].selectionStart = 0;
  $('#message')[0].selectionEnd = 0;
  resizeMessageTextarea(1);
};


//オートログインクッキーを消して、接続を切って、リロード
function logout(){
  $.cookie('yairc_auto_login_token', null);
  $.cookie('chat_tag_list', null);
  data.nick = '';
  data.tags = {'PUBLIC':0};
  socket.emit('disconnect');
  location.href="/";
}

//クッキーがあれば、オートログインさせる
function autologin(){
  if($.cookie('yairc_auto_login_token')){
    data.token = $.cookie('yairc_auto_login_token');
    if(data.token){
      console.log('try autologin');
      socket.emit('token_login', data.token, function (set) {
        clear();
        $('#chat').addClass('nickname-set');
      });
    }
  }
}

//トークンを使ってログインした後、レスポンスされる自分情報を保存
socket.on('token_login', function(res){
  if(res.status == 'ok'){
    var ud = res.user_data;
  
    data.nick = ud.nickname;
    data.profile_image_url = ud.profile_image_url;
  
    if( $.cookie('chat_tag_list')){
      var str = $.cookie('chat_tag_list');
      var list = str.split(',');
      for( i in list ){
        data.tags[list[i]] = 0;
      }
    }
    socket.emit('join_tag', data.tags);
  }else{
    alert('自動ログインセッションが不正です、ログインをやり直してください');
    logout();
  }

});

//タグ登録処理完了イベント
socket.on('join_tag', function(tags){
  $('#tags').empty();
  for (var i in tags) {
    $('#tags').append($('<b>').append( i, "&nbsp;", $('<a href="javascript:return void();">x</a>').on('click', 
    (function(i){ 
      return function(){removeTag(i)}
    })(i)
    ) ) , $("<br />") );
  }
  $(window).resize();

});

//tag削除
function removeTag(tag){
  delete (data.tags[tag]);
  sendTags();
}

//tag追加
function addTag(newtag){
  newtag = newtag.toUpperCase();
  if(newtag.length==0 || newtag.match(/[^A-Z0-9]/)){
    alert('タグは /^A-Z0-9/ の必要が有ります。');
    return;
  }

  //console.log(newtag);
  if(!data.tags[newtag]){
    data.tags[newtag] = 0;
  }  
  sendTags();
}

//send tag
function sendTags(){
  //オートログイン用に保存しておく
  $.cookie('chat_tag_list', $.keys(data.tags).join(','), { expires: 1 });
  //送信
  socket.emit('join_tag', data.tags);
}


//メッセージ送信
function sendMessage(){
  var message = $('#message').val();
  message = message.replace(/#[a-zA-Z0-9]+/g, '');
  message = message.replace(/\s/g, '');
  if(message.length>0){
    socket.emit('user message', $('#message').val());
    clear();
  }
  return false;
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
		if ((ev.which && ev.which === 13) || (ev.keyCode && ev.keyCode === 13)) {
		  if(ev.shiftKey){
  		  
		    return true;
		  }else{
		    $('#send-message').submit();
		    return false;
		  }
		} else {
			return true;
		}
	}); 
	
	$('#message').bind("click mouseup blur keyup input", function() {   
    resizeMessageTextarea();
  });

  //Cookieがあれば、オートログインさせる
  autologin();
  
  $(window).resize(function(){
    $("#nickname").css('height', $(window).height()+'px');
    $("#connecting").css('height', $(window).height()+'px');
    var height = $(window).height() - $('#send-message').height();
    $("#messages").css('height', height+'px');
    $("#lines").css('height', height+'px');
    $("#infomation").css('height', height+'px');

    if (navigator.userAgent.match(/(iPod|iPhone|iPad|Android)/)) {
      $("#messages").css('height','384px');
      $("#lines").css('height','384px');
      $("#infomation").css('height','384px');
      $("#infomation").hide('slow');
    }

  });
  
  $(window).resize();


  var loader = new PreloadJS(false);
  loader.installPlugin(SoundJS);
  loader.onComplete = onSoundLoadComplete;
  loader.loadManifest([
    {src:"http://yairc.cfe.jp/yairc/1ekMA.mp3|http://yairc.cfe.jp/yairc/9E2Ny.ogg",id:"message"}
  ]);


  var timeagoTimer = setInterval(function(){
    $('abbr.timeago').timeago();
  },60000);


  //デスクトップ通知許可
  if (jwNotify.status) {
    if ( jwNotify.notifications.checkPermission() == 0 ) {
      notify = true; // TODO cookieに保存？
      $('button.toggleNotify').text('Disable Notify');
    }else{
      $('button.toggleNotify').text('Enable Notify');
    }

    $('button.toggleNotify').click(function(e){
      e.preventDefault();
      if(jwNotify.notifications.checkPermission() != 0){ // Chromeが許可していない
        $.jwNotify({
          image: '/img/nobody.png',
          title: 'デスクトップ通知の許可',
          body: 'デスクトップ通知が許可されました',
          onshow: function(){notify = true; $('button.toggleNotify').text('Disable Notify');}
        });
      }else{
        if (notify) {
          $.jwNotify({
            image: '/img/nobody.png',
            title: 'デスクトップ通知の停止',
            body: 'デスクトップ通知を停止します'
          });
          notify = false;
          $('button.toggleNotify').text('Enable Notify');
        } else {
          $.jwNotify({
            image: '/img/nobody.png',
            title: 'デスクトップ通知の許可',
            body: 'デスクトップ通知が許可されました'
          });
          notify = true;
          $('button.toggleNotify').text('Disable Notify');
        }
      }
    });
  }else{
    $('button.toggleNotify').remove();
  }

});

var soundMessage = function(){};

function onSoundLoadComplete(){
  console.log('SoundLoadComplete');
  soundMessage = function(){
    if($('#sound').prop("checked")){
      SoundJS.play('message', SoundJS.INTERRUPT_EARLY, 0, 0, false);
    }
  }
}
