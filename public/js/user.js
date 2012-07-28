
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
        var profile_url = (data[i].profile_url !== '') ? data[i].profile_url : 'nobody.png';
        var snsUrl = getSnsProfileUrlByUserkey(data[i].user_key);

        //要素の横幅調整。画像の横幅より名前の横幅の方が長ければ名前の文字分の横幅にする
        //todo: マルチバイト文字列の場合の文字数計算
        var block_width = (data[i].nickname.length/2) * 16;
        if (block_width < 64) {
            block_width = 64;
        }

        if (snsUrl !== '') {
            joinUsers.append('<div class="join_member" style="width:' + block_width + 'px;"><a href="' + snsUrl + '"><img class="profile_url" src="/img/' + profile_url + '"><br>' + data[i].nickname + '</a></div>');
        }
        else {
            joinUsers.append('<div class="join_member" style="width:' + block_width + 'px;"><img class="profile_url" src="/img/' + profile_url + '"><br>' + data[i].nickname + '</div>');
        }
      }
    }),
    dataType: 'json'
  });
}

function getSnsProfileUrlByUserkey(user_key) {
    var tmp = user_key.split(':');
    var snsType  = tmp[0];
    var userName = tmp[1];
    switch (snsType) {
        case 'twitter':
            return 'http://twitter.com/' + userName;

        default:
            return '';
    }
}

