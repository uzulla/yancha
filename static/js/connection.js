/* vim: set sw=2 ts=2 : */

var socket = io.connect();
var data = {
  token:false,
  nick:false,
  user_key:false,
  profile_image_url:false,
  profile_url:false,
  tags:{PUBLIC:0,FROMLINGR:0}
};

//各種接続、切断、エラーイベント
socket.on('connect', function () {
  console.log('Connected to the server');
  if( is_input_disable() ){
    clear ();
  }
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


//サーバから、参加ニックネームリストの更新
socket.on('nicknames', function (nicknames) {
  $('#nicknames').empty();
  var join_num = 0;
  for (var i in nicknames) {
    $('#nicknames').append($('<b>').text(nicknames[i].nickname)).append('</b>');
    join_num += 1;
  }
  $('#join_num').text(join_num);
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

//delete
socket.on('delete user message', function(hash){
  var post_id = hash.id;
  if(debug){console.log('delete message'.post_id)};
  $('div[data-post-id='+post_id+']').hide('slow',function(){
    $('div[data-post-id='+post_id+']').remove();
    updateTitle();
  });

});

function getTimezonStr(){
  var date = new Date();
  var drift_min_num = date.getTimezoneOffset();
  var zone_time_str = '';
  if(drift_min_num < 0){
      zone_time_str += '+';
  }else{
      zone_time_str += '-';

  }

  drift_min_num = Math.abs(drift_min_num);
  var drift_hour = drift_min_num / 60;
  var drift_min = drift_min_num % 60;
  zone_time_str+=sprintf("%02d:%02d", drift_hour, drift_min);
  return zone_time_str;
}
var TIMEZONE_STR = getTimezonStr();

function announcement(msg){
  if($('#disp_announcement').attr('checked')){
    var cell = $('#template_announcementcell').clone().removeAttr('id');
    $('.announcementcell_text', cell).text(msg);
    $('.announcementcell_text', cell).html( $('.announcementcell_text', cell).html().replace(/(\r|\n)/g, '<br />') );
    $('.announcementcell_time', cell)
      .attr('title', moment().format("YYYY-MM-DDTHH:mm:ss")+TIMEZONE_STR)
      .text("("+moment().format('YYYY-MM-DD HH:mm')+")")
      .timeago();
    $('#lines').append(cell);
    hook.doHook('doScrollBottom', undefined);
  }
}

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

  //表示させるべきかフラグを持つ（タグをMuteしていないか）
  var enable_tag_list = getEnableTagList();
  hash.is_mute = true;
  for(var i=0; enable_tag_list.length>i;i++){
    var re = new RegExp(enable_tag_list[i], "i");
    if(hash.tags.join(',').match(re)){ //tagを含んでいるので、表示させる
      hash.is_mute = false;
    }
  }

  if(hash.profile_image_url.length>0){
    var avatar_img = $('.messagecell_img', cell).attr('src', hash.profile_image_url);
    if(hash.profile_url.length>0){
      avatar_img.wrap("<a href='"+hash.profile_url+"'></a>");
    }
  }

  $('.messagecell_nickname', cell).text(hash.nickname);

  var message = user_message_filter(h(hash.text));
  $('.messagecell_text', cell).html(message);

  //plusplus
  if (cell.attr('data-post-id') > 0) {
    var ppnum = (parseInt(hash.plusplus)||0);
    console.log( ppnum );
    var ppstar_elm = $("<span class='messagecell_plusplus_stars'>");
    //var starIcon = '★<span style="font-size:0.01em"> </span>';
    var starIcon = "<i class='star' />";

    if(ppnum<100){
      for(var i=0; ppnum>i; i++){
        ppstar_elm.append(starIcon);
      }
    }else{
      //ppstar_elm.append('★x'+ppnum);
      ppstar_elm.append(starIcon).appned('x' + ppnum);
    }

    $('.messagecell_plusplus', cell).append(
      $("<button onclick='addPlusPlus("+hash.id+");'>++</button>")
        .bind('touchstart', (function(hash) {
          return function(){
            event.preventDefault(); // onclickが反応しないように
            addPlusPlus(hash.id);
          }
        })(hash)),
      ' ',
      ppstar_elm
    );
  }

  $('.messagecell_time', cell)
    .attr('title', moment(hash.created_at_ms/100).format("YYYY-MM-DDTHH:mm:ss")+TIMEZONE_STR)
    .text("("+moment(hash.created_at_ms/100).format('YYYY-MM-DD HH:mm')+")")
    .timeago();

  if(hash.user_key == data.user_key){
    $('.messagecell_delete', cell).append(
      $("<button onclick='deleteMessage("+hash.id+");'>delete</button>")
    );
  }else{
    //自分の発言以外に未読フラグをつける
    cell
      .on('mouseover', function(){
        $(this).removeClass('unread');
        $(this).off('mouseover');
        updateTitle();
      })
      .ift(!hash.is_message_log, function(){ //ログか、現在の投稿か//もういらない
        $(this).addClass('unread');
      });
  }

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
    //メッセージ入力欄をクリアし、再利用可能にする
    if(hash.user_key == data.user_key){ // 2つのウインドウを同じアカウントで開いていると、もう片方も消えてしまう（仕様）
      input_enable();
      clear();
    }

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
  tagRefresh();
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

  if(typeof(Tinycon) !== 'undefined'){
    Tinycon.setBubble(unreadnum);
  }

}

//トークンを使ってログインした後、レスポンスされる自分情報を保存
socket.on('token login', function(res){
  if(res.status == 'ok'){
    var ud = res.user_data;

    data.nick = ud.nickname;
    data.user_key = ud.user_key;
    data.profile_image_url = ud.profile_image_url;
    data.profile_url = ud.profile_url;

    //Cookieに保持されたTagsリストがあれば、それをデフォルトタグにする
    if($.cookie('chat_tag_list')){
      var list = $.cookie('chat_tag_list').split(',');
      if(list.length>0){
        data.tags = {};//初期値設定されているなら、tagsを消す
        for( i in list ){
          data.tags[list[i]] = 0;
        }
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

  var disabledTags = new Array();
  var tagcell = $('.tagcell');
  for (var i=0; i<tagcell.length; i++) {
    var cell = $(tagcell[i]);
    var tag = cell.attr('data-tag-name');
    disabledTags[tag] = cell.hasClass('disable_tag');
  }

  $('#tags').empty();
  for (var i in tags) {
    var tagDisabled = disabledTags[i] ? ' disable_tag' : '' ;
    $('#tags').append(
      $('<b class="tagcell'+tagDisabled+'">')
        .attr('data-tag-name', i)
        .append(
          i,
          "&nbsp;",
          $('<span style="text-decoration:none; cursor: pointer; color:#CCCCCC">X</span>')
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
  tagRefresh();
});

function tagRefresh(){
  var enable_tag_list = getEnableTagList();

  //まずすべてPostを隠して、その後で必要なものだけ復活させる。
  $('#lines div.messagecell').hide();
  for(var i=0; enable_tag_list.length>i;i++){
    var re = new RegExp(enable_tag_list[i], "i");
    $('#lines div.messagecell').each(function(){
      var elm = $(this);
      if(elm.attr('data-tags').match(re)){ //tagを含んでいるので、表示させる
        elm.show();
      }
    });
  }
}

function getEnableTagList(){
  var enable_tag_list = [];
  $('b.tagcell').each(function(){
    var t = $(this).attr('data-tag-name');
    ($(this).hasClass('disable_tag')) ? 0 : enable_tag_list.push(t) ;
  });
  return enable_tag_list;
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
    console.log(newtag);
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
  if( is_input_disable() ){
    alert("sending...");
    return false;
  }
  var message = $('#message').val();

  var unfamiliar_tags = getUnfamiliarTagsInMessage(message);
  if ( unfamiliar_tags ) {
    var taglist = unfamiliar_tags.join(', ');
    if(!confirm("タグ「"+ taglist +"」は購読されていません。\n本当にメッセージを送信しますか？\n\n発言をすると発言タグは購読タグに自動追加されます。")){
      return false;
    }

    for (var i=0; i<=unfamiliar_tags.length; i++) {
      var tag = unfamiliar_tags[i];
      if (tag === undefined) {
        continue;
      }
      addTag(tag.replace(/^#/, ''));
    }
    socket.emit('join tag', unfamiliar_tags);
    sendTags();
  }

  message = message.replace(/(?:^| |　)#[a-zA-Z0-9]+/mg, '');
  message = message.replace(/\s/g, '');
  if(message.length>0){
    if (message.match(/^fukumotosan$/)) { // `fukumotosan` command
      socket.emit('fukumotosan');
    } else {
      input_disable();
      socket.emit('user message', $('#message').val());
    }
  }
  return false;
}

//PlusPlusをつける
function addPlusPlus(post_id) {
  socket.emit('plusplus', post_id);
}

//Deleteする
function deleteMessage(post_id) {
  if(confirm('本当に削除しますか？')){
    socket.emit('delete user message', post_id);
  }
}

//オートログインクッキーを消して、接続を切って、リロード
function logout(){
  $.cookie('yancha_auto_login_token', null);
  $.cookie('chat_tag_list', null);
  data.nick = '';
  data.tags = {'PUBLIC':0,'FROMLINGR':0};
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

// input 入力欄を一時的につかえなくする
function input_disable(){
  $('#message').attr("disabled", "disabled");
}
function input_enable(){
  $('#message').removeAttr("disabled");
}
function is_input_disable(){
  if( $('#message').attr("disabled") ){
    return true;
  }else{
    return false;
  }
}

//テキスト入力欄をクリア、ただし、タグは残しておく
function clear () {
  input_enable();
  var tag_list = getTagsInMessage($('#message').val());
  var str = tag_list.join(' ');
  if(str.length>0){ str = ' '+str}
  $('#message').val(str).focus();
  $('#message')[0].selectionStart = 0;
  $('#message')[0].selectionEnd = 0;
  resizeMessageTextarea(1);
};

//メッセージのタグを取得
function getTagsInMessage (message) {
  var message_copy = message.replace(/>\|[^\|]*\|\n[\s\S]*?\n\|\|</g, "");
  var message_copy = message_copy.replace(/>>\n[\s\S]*?\n<</g, "");
  var re = /(^| |　)#[a-zA-Z0-9]+/g;
  var list = message_copy.match(re) || [];
  var list2 = $.map(list, function(tag){
    return tag.replace(/^( |　)/, '');
  });
  return list2;
}

//現在購読しているタグの一覧
function getTags () {
  var tags = [];
  $('#tags > b.tagcell').each(function(){
    tags.push( '#' + $(this).attr('data-tag-name').toUpperCase() );
  });
  return tags;
}

//メッセージ中に購読されていないタグがある場合、該当タグを返す
function getUnfamiliarTagsInMessage (message) {
  var subscribed = getTags();
  var tags = getTagsInMessage(message);
  var unfamiliar = [];
  $.each(tags,function(){
    var tag = this.toUpperCase();
    if( $.inArray(tag, subscribed) == -1 ) {
      unfamiliar.push(tag);
    }
  });
  return unfamiliar.length>0 ? unfamiliar : null;
}

//unreadを全消去する
function reset_unread(){
  $(".unread").removeClass('unread');
  updateTitle();
}
