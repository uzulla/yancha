var debug = 0;
var notify = false;

//user message受信時に呼ばれる
hook.addHook('onUserMessage', function(hash){
  if ( notify && hash.nickname != data.nick && !hash.is_message_log ) {
    $.jwNotify({
      image : hash.profile_image_url,
      title: hash.nickname,
      body: hash.text,
      timeout: 10000
    });
  }
  
  if(!hash.is_message_log){ //ログか、現在の投稿か
    soundMessage();
  }
  
});

hook.addHook('doScrollBottom', function(hash){
  var nowBottom = $('#lines').height()+$('#lines').scrollTop();
  var domHeight = $('#lines')[0].scrollHeight;
  var lastElmHeight = $('#lines *.messagecell:last').height();
  if( domHeight - lastElmHeight <= nowBottom + 10 ){ // 10は遊び
    $('#lines').get(0).scrollTop = 10000000;
  }  
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
      linenum = 2;
    }
  }
  if(linenum == 1){
    linenum=2;
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
    var height = $(window).height() - $('#send-message').height();
    $("#messages").css('height', height+'px');
    $("#lines").css('height', height+'px');
    $("#infomation").css('height', height+'px');

  });
  $(window).resize();
  resizeMessageTextarea();  

  var loader = new PreloadJS(false);
  loader.installPlugin(SoundJS);
  loader.onComplete = onSoundLoadComplete;
  loader.loadManifest([
    {src:"http://yairc.cfe.jp/yairc/1ekMA.mp3|http://yairc.cfe.jp/yairc/9E2Ny.ogg",id:"message"}
  ]);

  var timeagoTimer = setInterval(function(){
    $('abbr.timeago').timeago();
  },60000);

  initVirtualCheckbox('.virtualcheckbox');

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
  
  if(Tinycon){
    Tinycon.setOptions({ //オプション
      width: 7, //幅
      height: 9, //高さ
      font: '10px arial', //フォント
      colour: '#ffffff', //フォント色
      background: '#e7a411' //背景色
    });
  }
  
  $('a.popup').click(function(e) {
    e.preventDefault();
    ui.openPopup($(this).attr('href'), { position_top: $(this).scrollTop() });
  });
});


//着信サウンド再生
var soundMessage = function(){};//ロード前にエラーにならないように
function onSoundLoadComplete(){
  soundMessage = function(){
    if($('#sound').attr("checked")){
      SoundJS.play('message', SoundJS.INTERRUPT_EARLY, 0, 0, false);
    }
  }
}

//引用選択機能
function startOrEndSelectPost(e){
  var elm = $(e.target);
  
  if(elm.attr('checked')){
    endSelectPost();
    toggleVirtualCheckbox(e);
  }else{
    startSelectPost();
    toggleVirtualCheckbox(e);
  }
}


function startSelectPost(){
  $('.messagecell').on('click', function(){
    if($(this).hasClass('selectedMessageCell')){
      $(this).removeClass('selectedMessageCell')
    }else{
      $(this).addClass('selectedMessageCell')
    }
    
  });
}

function endSelectPost(){
  $('.messagecell').off('click');
  var post_id_list = [];
  $('.selectedMessageCell').each(function(){
    post_id_list.push($(this).attr('data-post-id'));
  });
  console.log (post_id_list);
  if(post_id_list.length < 1){
    alert('一つも選択されていません');
    return;
  }
  var url = '/quotation.html?id='+post_id_list.join(',');
  $('#popuper').attr('action', url).submit();
  $('.messagecell').removeClass('selectedMessageCell') 
}


function initVirtualCheckbox(query){
  $(query).each(function(){
    var elm = $(this);
    if(!elm.attr('data-onsrc') || !elm.attr('data-offsrc')){
      var src = elm.attr('src');
      elm.attr('data-offsrc', src);
      elm.attr('data-onsrc', src.replace(/.(gif|jpeg|jpg|png)$/i, "_on.$1") );
    }
    if( $(elm).attr('checked') ){
      $(elm).attr('src', $(elm).attr('data-onsrc'));
    }else{
      $(elm).attr('src', $(elm).attr('data-offsrc'));
    }    
  });
}

function toggleVirtualCheckbox(e){
  var elm = $(e.target);
  if( elm.attr('checked') ){
    elm.removeAttr('checked') 
    elm.attr('src', elm.attr('data-offsrc'));
  }else{
    elm.attr('checked', 'checked') 
    elm.attr('src', elm.attr('data-onsrc'));
  }
}

function setVirtualCheckbox(elm, state){
  var elm = $(elm);
  if( state ){
    elm.removeAttr('checked') 
    elm.attr('src', elm.attr('data-offsrc'));
  }else{
    elm.attr('checked', 'checked') 
    elm.attr('src', elm.attr('data-onsrc'));
  }
}

