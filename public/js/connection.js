var socket = io.connect();
var data = {
  token:false,
  nick:false,
  profile_image_url:false,
  tags:{PUBLIC:0}
};

//各種接続、切断、エラーイベント
socket.on('connect', function () {
  $('#connecting').hide();
});
socket.on('reconnect', function () {
  if(debug){message('System', 'Reconnected to the server');}
  if(data.token){
    if(debug){console.log('try create session');}
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
    if(debug){console.log('try register');}
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

  //タグ毎新着時刻保存
  for(var i=0; hash.tags.length > i; i++){
    if(typeof(data.tags[hash.tags[i]]) != 'undefined' ){
      data.tags[hash.tags[i]] = hash.created_at_ms ;
    }
  }

  var cell = $('#template_messagecell').clone().removeAttr('id');
  cell.attr('data-post-id', hash.id);
  cell.attr('data-tags', hash.tags);  
  
  
  if(hash.profile_image_url.length>0){
    $('.messagecell_img', cell).attr('src', hash.profile_image_url);
  }

  $('.messagecell_nickname', cell).text(hash.nickname);

  var message = user_message_filter(h(hash.text));
  $('.messagecell_text', cell).html(message);
  
  $('.messagecell_time', cell)
    .attr('title', moment(hash.created_at_ms/100).format("YYYY-MM-DDTHH:mm:ss")+"Z+09:00")
    .text("("+moment(hash.created_at_ms/100).format('YYYY-MM-DD HH:mm')+")")
    .timeago();
  
  cell
    .on('mouseover', function(){
      $(this).removeClass('unread');
      $(this).off('mouseover');
      updateTitle();
    })
    .ift(!hash.is_message_log, function(){ //ログか、現在の投稿か//もういらない
      $(this).addClass('unread');
    });
  
  if(hash.is_message_log){ //ログなので、差し込む場所を調整する  
    var added_flg=false;
    $('#lines div.messagecell').each(function(){
      var _pid = parseInt($(this).attr('data-post-id'));
      if(_pid==hash.id){ // 自分と同じPostIDがある(出力済み)なので終了
        added_flg=true;
        return false; //break
      }else if(_pid<hash.id){ // 自分より古いので、一つ進める
        return; //continue 
      }else{ // 自分より新しい物が「初めて」でたので、その前に自分を差し込む
        $(this).before(cell);
        added_flg=true;
        return false; //break
      }
    });
    if(added_flg==false){ //自分より新しい物がなかったので、最後に挿入する
      $('#lines').append(cell);
    }
  }else{
    $('#lines').append( cell );
  }
  
  if($('#lines p').length>100){ // 沢山表示すると重くなるので、古い物を消していく
    $('#lines p:first').remove();
  }

  if( message.match(/sh_/) ){ //sh_highlightDocument() がかなり重いので、呼び出し回数を減らす為
    sh_highlightDocument();
  }

  updateTitle();

  hook.doHook('onUserMessage', hash);

});

//タイトルに未読件数を表示する
function updateTitle(){
  var unreadnum = $('#lines div.unread').length;
  var prefix = '';
  if(unreadnum>0){
    prefix = "("+unreadnum+")";
  }
  document.title = prefix+"yairc";
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
  message = message.replace(/(?:^| |　)#[a-zA-Z0-9]+/mg, '');
  message = message.replace(/\s/g, '');
  if(message.length>0){
    socket.emit('user message', $('#message').val());
    clear();
  }
  return false;
}


//オートログインクッキーを消して、接続を切って、リロード
function logout(){
  $.cookie('yairc_auto_login_token', null);
  $.cookie('chat_tag_list', null);
  data.nick = '';
  data.tags = {'PUBLIC':0};
  socket.emit('disconnect');
  location.reload();
}

//クッキーがあれば、オートログインさせる
function autologin(){
  if($.cookie('yairc_auto_login_token')){
    data.token = $.cookie('yairc_auto_login_token');
    if(data.token){
      if(debug){console.log('try autologin');}
      socket.emit('token_login', data.token, function (set) {
        clear();
        $('#nickname').hide();
      });
    }
  }
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

