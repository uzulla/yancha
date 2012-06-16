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
  hook.doHook('onConnect', undefined);
});
socket.on('reconnect', function () {
  if(debug){console.log('Reconnected to the server');}
  if(data.token){
    if(debug){console.log('try create session');}
    socket.emit('token login', data.token);
  }
});
socket.on('reconnecting', function () {
  if(debug){console.log('Attempting to re-connect to the server');}
});
socket.on('error', function (e) {
  if(debug){
    console.log("disconnected");
  }
});

//サーバからのアナウンス
socket.on('announcement', function (msg) {
  announcement(msg)
});

function announcement(msg){
  if($('#disp_announcement').attr('checked')){
    var cell = $('#template_announcementcell').clone().removeAttr('id');
    $('.announcementcell_text', cell).text(msg);
    $('.announcementcell_text', cell).html( $('.announcementcell_text', cell).html().replace(/(\r|\n)/g, '<br />') );
    $('.announcementcell_time', cell)
      .attr('title', moment().format("YYYY-MM-DDTHH:mm:ss")+"Z+09:00")
      .text("("+moment().format('YYYY-MM-DD HH:mm')+")")
      .timeago();    
    $('#lines').append(cell);
    hook.doHook('doScrollBottom', undefined);
  }
}


//サーバから、参加ニックネームリストの更新
socket.on('nicknames', function (nicknames) {
  var i;
  $('#nicknames').empty();
  for (i in nicknames) {
    $('#nicknames').append($('<b>').text(nicknames[i]));
  }
  $(window).resize();
});

//サーバー側にニックネーム登録がない場合に本処理
//messageは再送する為にサーバーから戻されたテキスト、分かりづらく、設計の筋がよくない。
socket.on('no session', function (message) {
  if(data.token){
    if(debug){console.log('try register');}
    socket.emit('token login', data.token, function (status) {
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
  var i;
  //タグ毎新着時刻保存
  for(i=0; hash.tags.length > i; i++){
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

  //plusplus
  if (cell.attr('data-post-id') > 0) {
    var ppnum = (parseInt(hash.plusplus)||0);
    var ppstar_elm = $("<span class='messagecell_plusplus_stars'>");
    if(ppnum<100){
      for(i=0; ppnum>i; i++){
        ppstar_elm.append('★<span style="font-size:0.01em"> </span>');
      }
    }else{
      ppstar_elm.append('★x'+ppnum);
    }
    
    $('.messagecell_plusplus', cell).append(
      $("<button onclick='addPlusPlus("+hash.id+");'>++</button>"),
      ' ',
      ppstar_elm
    );
  }
  
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
  
  $('.messagecell_plusplus', cell)
    .on('mouseover', function(){
      $(this).removeClass('uncheck');
    });

  if(hash.is_message_log){ //ログなので、差し込む場所を調整する  
    var added_flg=false;
    $('#lines div.messagecell').each(function(){
      var _pid = parseInt($(this).attr('data-post-id'));
      if(_pid==hash.id){ // 自分と同じPostIDがある、上書きする。（現状plusplusのみ）
        $('.messagecell_plusplus', this).replaceWith($('.messagecell_plusplus', cell).addClass('uncheck'));
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
      hook.doHook('doScrollBottom', hash);
    }
  }else{
    $('#lines').append( cell );
    hook.doHook('doScrollBottom', hash);
  }
  
  if($('#lines .messagecell').length>100){ // 沢山表示すると重くなるので、古い物を消していく
    $('#lines .messagecell:first').remove();
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
  document.title = prefix+"yancha";
}

//トークンを使ってログインした後、レスポンスされる自分情報を保存
socket.on('token login', function(res){
  var i;
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
    socket.emit('join tag', data.tags);
  }else{
    alert('自動ログインセッションが不正です、ログインをやり直してください');
    logout();
  }

});

//タグ登録処理完了イベント
socket.on('join tag', function(tags){
  var i;
  $('#tags').empty();
  for ( i in tags) {
    $('#tags').append(
      $('<b class="tagcell">')
        .attr('data-tag-name', i)
        .append( 
          i, 
          "&nbsp;", 
          $('<a href="javascript:return void();" style="text-decoration:none;">X</a>')
            .on('click', function(e){
              e.stopPropagation();
              removeTag($(e.target).parent().attr('data-tag-name'));
            })
      ).on('click', function(e){
        var elm = $(e.target);
        var tag = elm.attr('data-tag-name');
        if(elm.hasClass('disable_tag')){
          elm.removeClass('disable_tag');
        }else{
          elm.addClass('disable_tag');
        }
        tagRefresh();
      })
    );
  }
  $(window).resize();

});

function tagRefresh(){
  var
    enable_tag_list = [],
    i;

  $('b.tagcell').each(function(){
    var t = $(this).attr('data-tag-name');
    ($(this).hasClass('disable_tag')) ? 0 : enable_tag_list.push(t) ;
  });

  //まずすべてPostを隠して、その後で必要なものだけ復活させる。
  $('#lines div.messagecell').hide();
  for( i=0; enable_tag_list.length>i;i++){
    var re = new RegExp(enable_tag_list[i], "i");
    $('#lines div.messagecell').each(function(){
      var elm = $(this);
      if(elm.attr('data-tags').match(re)){ //tagを含んでいるので、表示させる
        elm.show();
      }
    });  
  }
}

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
  
  var re = new RegExp('#'+newtag+'( |$)', "i");
  if(!$('#message').val().match(re)){
    $('#message').val($('#message').val()+' #'+newtag);
  }
}

//send tag
function sendTags(){
  //オートログイン用に保存しておく
  $.cookie('chat_tag_list', $.keys(data.tags).join(','), { expires: 1 });
  //送信
  socket.emit('join tag', data.tags);
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

//PlusPlusをつける
function addPlusPlus(post_id) {
  socket.emit('plusplus', post_id);
}

//オートログインクッキーを消して、接続を切って、リロード
function logout(){
  $.cookie('yancha_auto_login_token', null);
  $.cookie('chat_tag_list', null);
  data.nick = '';
  data.tags = {'PUBLIC':0};
  socket.emit('disconnect');
  location.reload();
}

//クッキーがあれば、オートログインさせる
function autologin(){
  if($.cookie('yancha_auto_login_token')){
    data.token = $.cookie('yancha_auto_login_token');
    if(data.token){
      $('#nickname').hide();
      if(debug){console.log('try autologin');}
      socket.emit('token login', data.token, function (set) {
        clear();
        $('#loading').hide();
      });
    }
  }
  $('#loading').hide();
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

