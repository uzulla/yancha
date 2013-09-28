
function submitSearch(){
  $('#lines').empty();
  $('#loading_finish_text_bottom').hide();
  $('#loading_text_bottom').show();
  $('#loading_bottom').show();
  cancelSelectPostEvent();

  (!$('#check_new_is_first').prop('checked')) ? $('#loading_top').show() : $('#loading_bottom').show(); // loading indicator

  var f = $("#searchform");
  var keyword = $('input[name=keyword]', f).val();
  var id = $('input[name=id]', f).val();
  var tag = $('input[name=tag]', f).val();
  var limit = $('input[name=limit]', f).val();
  if(!limit){
    limit = $('select[name=limit]', f).val();
  }
  var time ;
  var time_window = parseInt($('select[name=time_window]', f).val());
  var sort_key = $('select[name=sort_key]', f).val();
  var sort_seq = $('select[name=sort_seq]', f).val();
  var order = (sort_seq == 'desc') ? '-'+sort_key : sort_key;

  if(time_window && time_window != 0){
    var end_epoch = moment().unix();
    var start_epoch = end_epoch - time_window;
    time = start_epoch+','+end_epoch;
  }else{
    time = $('input[name=time]', f).val();
  }

  console.log('post'); 

  $.ajax({
    type: 'POST',
    url: getHostRootURL()+"/api/search", // todo
    data: {
      keyword:keyword,
      tag:tag,
      id:id,
      limit:limit,
      time:time,
      order:order
    },
    error: function(XMLHttpRequest, textStatus, errorThrown){
      console.log(textStatus);
    },
    success: (function(){return function(data){
      $('#lines').empty();
      drawItemByHashList(data);
      $(window).on('scroll', extendSearchOnScroll);
      $('#loading_top , #loading_bottom').hide();
      $('#loading_text_bottom').show();
      if(data.length == limit){ // これより前がみつからないので。
        if($(document).height() > $('body').height()){
          pagerize = true;
          extendSearch();
        }
      }
    }})(limit),
    dataType: 'json'
  });
}

function extendSearch(){
  $(window).off('scroll', extendSearchOnScroll);

  (!$('#check_new_is_first').prop('checked')) ? $('#loading_top').show() : $('#loading_bottom').show(); // loading indicator

  var f = $("#searchform");
  var keyword = $('input[name=keyword]', f).val();
  var tag = $('input[name=tag]', f).val();
  var limit = 50;
  var last_post_cell = $('#lines .messagecell:last-child').get(0);
  var oldest_post_id = $(last_post_cell).attr('data-post-id');

  var sort_key = $('select[name=sort_key]', f).val();
  var sort_seq = $('select[name=sort_seq]', f).val();
  var order = sort_seq == 'desc' ? '-'+sort_key : sort_key;

  var time;
  var time_window = parseInt($('select[name=time_window]', f).val());
  if(time_window && time_window != 0){
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
      older_than_id:oldest_post_id,
      time:time,
      order:order
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
        if($(document).height() > $('body').height()){
          pagerize = true;
          extendSearch();
        }
        
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
    $('.messagecell_img', cell).attr('src', hash.profile_image_url).wrap("<a href='"+hash.profile_url+"'></a>");
  }
  $('.messagecell_nickname', cell).text(hash.nickname);
  $('.messagecell_text', cell).html(message);
  $('.messagecell_time', cell)
    .attr('title', moment(hash.created_at_ms/100).format("YYYY-MM-DDTHH:mm:ss")+"Z+09:00") // TODO国際化対応
    .text("("+moment(hash.created_at_ms/100).format('YYYY-MM-DD HH:mm')+")")
    .timeago();
    
  //plusplus
  var ppnum = (parseInt(hash.plusplus)||0);
  var ppstar_elm = $("<span class='messagecell_plusplus_stars'>");
  if(ppnum<100){
    for(var i=0; ppnum>i; i++){
      ppstar_elm.append('★<span style="font-size:0.01em"> </span>');
    }
  }else{
    ppstar_elm.append('★x'+ppnum);
  }
  $('.messagecell_plusplus', cell).append( ppstar_elm );
    
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

//引用選択機能
function startSelectPost(){
  cancelSelectPostEvent();
  $('#lines').on('click', function(e){
    var $mess = $(e.target).closest('.messagecell');
    if ($mess && e.target.tagName!="A") {
      $mess.toggleClass('selectedMessageCell');
    }
  });
}

function cancelSelectPostEvent(){
  $('#lines').off('click');
}

function endSelectPost(){
  cancelSelectPostEvent();
  var post_id_list = [];
  $('.selectedMessageCell').each(function(){
    post_id_list.push($(this).attr('data-post-id'));
  });
  console.log (post_id_list);
  if(post_id_list.length < 1){
    alert('一つも選択されていません');
    return;
  }
  var url = '/quot?id='+post_id_list.join(',');
  $('#popuper').attr('action', url).submit();
  $('.messagecell').removeClass('selectedMessageCell');
}


