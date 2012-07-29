
function joinMembers () {

  $.ajax({
    type: 'POST',
    url: getHostRootURL()+"/api/user",
    error: function(XMLHttpRequest, textStatus, errorThrown){
      console.log(textStatus);
    },
    success: (function(data){
      var joinUsers = $('#join-users');
      for (var i in data) {
        var profile_image_url = (data[i].profile_image_url !== '') ? data[i].profile_image_url : 'nobody.png';
        var snsUrl = getSnsProfileUrlByUserkey(data[i]);

        //要素の横幅調整。画像の横幅より名前の横幅の方が長ければ名前の文字分の横幅にする
        //todo: マルチバイト文字列の場合の文字数計算
        var block_width = (data[i].nickname.length/2) * 16;
        if (block_width < 64) {
            block_width = 64;
        }

        if (snsUrl !== '') {
            joinUsers.append('<div class="join_member" style="width:' + block_width + 'px;"><a href="' + snsUrl + '"><img class="profile_url" src="' + profile_image_url + '"><br>' + data[i].nickname + '</a></div>');
        }
        else {
            joinUsers.append('<div class="join_member" style="width:' + block_width + 'px;"><img class="profile_url" src="/img/' + profile_image_url + '"><br>' + data[i].nickname + '</div>');
        }
      }
    }),
    dataType: 'json'
  });
}

function getSnsProfileUrlByUserkey(userData) {
    var snsType = userData.user_key.split(':')[0];
    switch (snsType) {
        case 'twitter':
            return 'http://twitter.com/' + userData.nickname;

        default:
            return '';
    }
}

