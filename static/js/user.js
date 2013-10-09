
function joinMembers () {

  $.ajax({
    type: 'POST',
    url: getHostRootURL()+"/api/user",
    error: function(XMLHttpRequest, textStatus, errorThrown){
      console.log(textStatus);
    },
    success: (function(data){
      var join_users = $('#join-users');
      for (var i in data) {
        var profile_image_url = (data[i].profile_image_url !== '') ? data[i].profile_image_url : '/static/img/nobody.png';
        var profile_url = getSnsProfileUrl(data[i]);

        //todo: マルチバイト文字列の場合の文字数計算
        var block_width = (data[i].nickname.length/2) * 16;
        if (block_width < 16*4) {
            block_width = 16*5;
        }
        else {
            block_width += 16;
        }

        if (profile_url !== '') {
          join_users.append(
            '<div class="join_member" style="width:' + block_width + 'px;">' +
            '<a href="' + profile_url + '"><img class="profile_url" src="' + profile_image_url + '">' +
            '<br style="clear:both;">' + 
            '<img src="' + getSnsIconPath(data[i].user_key.split(':')[0]) + '">' + 
            data[i].nickname + 
            '</a></div>'
          );
        }
        else {
          join_users.append(
            '<div class="join_member" style="width:' + block_width + 'px;">' +
            '<img class="profile_url" src="' + profile_image_url + '">' +
            '<br>' +
            data[i].nickname +
            '</div>'
          );
        }
      }
    }),
    dataType: 'json'
  });
}

function getSnsProfileUrl(user_data) {
  var sns = user_data.user_key.split(':')[0];
  switch (sns) {
    case 'twitter':
      return 'http://twitter.com/' + user_data.nickname;

    default:
      return '';
  }
}

function getSnsIconPath(sns) {
  var path = '/static/img/sns/';
  var image_name = '';

  switch (sns) {
    case 'twitter':
      image_name = 'twitter.png';
  }

  return path + image_name;
}
