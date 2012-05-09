function submitSearch(e){
  var f = $("#searchform");
  
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
  
  var data = {
  tag:tag,
  limit:limit,
  time:time,
  };
  
  $.ajax({
    type: 'POST',
    url: location.href.split('/search')[0]+"/api/", // todo
    data: data,
    success: function(data){
      drawJson(data);
    },
    dataType: 'json'
  });
}

function drawJson(list){
  $('#lines').empty();

  if(!$('#check_new_is_first').prop('checked')){
    list = list.reverse();
  }
  var listlen = list.length;
  for(var i=0; listlen>i; i++){
    //console.log(list[i]);
    drawOne(list[i]);
  }
}