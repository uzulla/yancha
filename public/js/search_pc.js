function drawOne(hash){

  var cell = $('#template_messagecell').clone().removeAttr('id');
  
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
  
  $('#lines').append(
    cell
  );
  
  if( message.match(/sh_/) ){
    sh_highlightDocument();
  }

}

var myScroll = null;

//各種初期化
$(function () {
  $(window).resize(function(){
    var height = $(window).height();
    if (navigator.userAgent.match(/(iPod|iPhone|iPad|Android)/)) {
      height=415;
    }

    var blank = $('#controls').height();
    if($('#searchform').css('display')!='none'){
      blank = blank + $('#searchform').height();
    }
    height = height - blank;
    
    $("#messages").css('top', blank+'px');
    $("#messages").css('height',height+'px');
  });
  $(window).resize();

});

