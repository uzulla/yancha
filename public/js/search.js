function submitSearch(){
  $('#lines').empty();
  $('#loading_finish_text_bottom').hide();
  $('#loading_text_bottom').show();
  $('#loading_bottom').show();

  (!$('#check_new_is_first').prop('checked')) ? $('#loading_top').show() : $('#loading_bottom').show(); // loading indicator

  var f = $("#searchform");
  var keyword = $('input[name=keyword]', f).val();
  keyword = keyword.replace(/　/g, ' '); // 全角→半角

  var tag = $('input[name=tag]', f).val();
  var limit = parseInt($('select[name=limit]', f).val());
  var time ;
  var time_window = parseInt($('select[name=time_window]', f).val());

  if(time_window!=0){
    var end_epoch = moment().unix();
    var start_epoch = end_epoch - time_window;
    time = start_epoch+','+end_epoch;
  }else{
    time = $('input[name=time]', f).val();
  }
  
  $.ajax({
    type: 'POST',
    url: location.href.split('/search')[0]+"/api/search", // todo
    data: {
      keyword:keyword,
      tag:tag,
      limit:limit,
      time:time,
    },
    success: function(data){
      $('#lines').empty();
      drawItemByHashList(data);
      $(window).on('scroll', extendSearchOnScroll);
      $('#loading_top , #loading_bottom').hide();
      $('#loading_text_bottom').show();
    },
    dataType: 'json'
  });
}

function extendSearch(){
  $(window).off('scroll', extendSearchOnScroll);

  (!$('#check_new_is_first').prop('checked')) ? $('#loading_top').show() : $('#loading_bottom').show(); // loading indicator

  var f = $("#searchform");
  var tag = $('input[name=tag]', f).val();
  var limit = 50;
  var last_post_cell = $('#lines .messagecell:last-child').get(0);

  $.ajax({
    type: 'POST',
    url: location.href.split('/search')[0]+"/api/search", // todo
    data: {
      tag:tag,
      id:$(last_post_cell).attr('data-post-id'),
      older:limit,
    },
    success: function(data){
      if(data.length == 0){ // これより前がみつからないので。
        $('#loading_finish_text_bottom').show();
        $('#loading_text_bottom').hide();
        $('#loading_top , #loading_bottom').hide();
        $(window).off('scroll', extendSearchOnScroll);
      }else{
        drawItemByHashList(data);
        $('#loading_top , #loading_bottom').hide();
        $(window).on('scroll', extendSearchOnScroll);
      }
      pagerize = false;
    },
    dataType: 'json'
  });
}

function drawItemByHashList(list){
  for(var i=0; list.length>i; i++){
    var cell = buildMessageCell(list[i]);
    ($('#check_new_is_first').prop('checked')) ? $('#lines').append(cell) : $('#lines').prepend(cell);
    
    if( cell.html().match(/sh_/) ){
      sh_highlightDocument();
    }
  }
}

function buildMessageCell(hash){
  var cell = $('#template_messagecell').clone().removeAttr('id');
  var message = user_message_filter(h(hash.text));

  cell.attr('data-post-id', hash.id);
  cell.attr('data-tags', hash.tags);  

  if(hash.profile_image_url.length>0){
    $('.messagecell_img', cell).attr('src', hash.profile_image_url);
  }
  $('.messagecell_nickname', cell).text(hash.nickname);
  $('.messagecell_text', cell).html(message);
  $('.messagecell_time', cell)
    .attr('title', moment(hash.created_at_ms/100).format("YYYY-MM-DDTHH:mm:ss")+"Z+09:00") // TODO国際化対応
    .text("("+moment(hash.created_at_ms/100).format('YYYY-MM-DD HH:mm')+")")
    .timeago();
  return cell;
}

var pagerize = false;
//各種初期化
$(function () {
});

function extendSearchOnScroll(e){ //Auto pagerize
  if($('#check_new_is_first').prop('checked')){ //Auto Pagerは上>下の時だけ有効にする…しかないよね。
    var drift = $('body').height() - ( $(window).height()+$(window).scrollTop() ) ;
    if( $('body').height() > $(window).height() ){
      if( drift < 200  &&  drift >= 0 && !pagerize ){ // TODO誤差調整の数値はかなり場当たり的…iPhoneが変
        pagerize = true;
        extendSearch();
      }
    }
  }
}


