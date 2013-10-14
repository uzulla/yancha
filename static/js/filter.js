function user_message_filter(message){

    //auto inline display(pyazo)
    message = message.replace(/http(s)?:\/\/yairc.cfe.jp(:5000)?(\/[\x21-\x7e]+)\.(png|gif|jpg|jpeg)/gi,
                              "<a href='//yairc.cfe.jp$3.$4' target='_blank'><img src='//yairc.cfe.jp$3.$4' style='max-width:300px;max-height:300px;'/></a>");

    message = message.replace(/http(s)?:\/\/yairc.cfe.jp(:5000)?(\/[\x21-\x7e]+)\.^(png|gif|jpg|jpeg)/gi,
                                                  "<a href='//yairc.cfe.jp$3.$4' target='_blank'>//yairc.cfe.jp$3.$4</a>");

    //gist inline
    message = message.replace(/https:\/\/gist.github.com\/[a-zA-Z0-9\-_]{1,10}\/([0-9]{1,10})/g, function(whole,s1) {
        return( 'https://gist.github.com/'+s1+'/ <br><iframe data-gist-id="'+s1+'" style="width:100%;"></iframe><script>load_gist('+s1+')</script><br>' );
    });

    //アサマシエイト （サーバー運営費に当てます！！！）
    message = message.replace(/\/\/www\.amazon\.co\.jp[\x21-\x7e]*\/dp\/([0-9A-Z]{10,13})[\x21-\x7e]*/ig, function(whole,s1) {
        return( whole+' <br><iframe src="//rcm-fe.amazon-adsystem.com/e/cm?lt1=_blank&t=uzulla-22&o=9&p=8&l=as4&m=amazon&f=ifr&ref=ss_til&asins='+s1+'" style="width:120px;height:240px;" scrolling="no" marginwidth="0" marginheight="0" frameborder="0"></iframe>' );
    });
    message = message.replace(/\/\/www\.amazon\.co\.jp[\x21-\x7e]*\/gp\/product\/([0-9A-Z]{10,13})[\x21-\x7e]*/ig, function(whole,s1) {
        return( whole+' <br><iframe src="//rcm-fe.amazon-adsystem.com/e/cm?lt1=_blank&t=uzulla-22&o=9&p=8&l=as4&m=amazon&f=ifr&ref=ss_til&asins='+s1+'" style="width:120px;height:240px;" scrolling="no" marginwidth="0" marginheight="0" frameborder="0"></iframe>' );
    });

    //twitter inline https://twitter.com/uzulla/status/389391040480051200
    message = message.replace(/http[s]*:(\/\/twitter.com\/[a-zA-Z0-9\-_]{1,40}\/status[e|s]*\/[0-9]{1,40})/g, function(whole,s1) {
        return( 'https:'+s1+' <br><blockquote class="twitter-tweet"><a href="'+s1+'"></blockquote><script>twttr.widgets.load();</script>' );
    });

    // YT thumbnail
    message = message.replace(/http(s)?:\/\/www.youtube.com\/[\x21-\x7e]*v=([a-zA-Z0-9\-]+)/g,
                              "<img src='//i1.ytimg.com/vi/$2/default.jpg'><br />http://www.youtube.com/watch?v=$2");

    //auto link
    message = message.replace(/(http(s)?:\/\/[\x21-\x7e]+)/gi, "<a href='$1' target='_blank'>$1</a>");

    message = message.replace(/&#62;\|javascript\|\n([\s\S]*?)\n\|\|&#60;/g, function(whole,s1) {
        return( '<pre class="sh_javascript">' + s1 + '</pre>' );
    });
    
    var foundShHighlight = false;

    message = message.replace(/&#62;\|perl\|\n([\s\S]*?)\n\|\|&#60;/g, function(whole,s1) {
        return( '<pre class="sh_perl">' + s1 + '</pre>' );
    });

    message = message.replace(/&#62;\|ruby\|\n([\s\S]*?)\n\|\|&#60;/g, function(whole,s1) {
        return( '<pre class="sh_ruby">' + s1 + '</pre>' );
    });

    message = message.replace(/&#62;\|python\|\n([\s\S]*?)\n\|\|&#60;/g, function(whole,s1) {
        return( '<pre class="sh_python">' + s1 + '</pre>' );
    });

    message = message.replace(/&#62;\|c\|\n([\s\S]*?)\n\|\|&#60;/g, function(whole,s1) {
        return( '<pre class="sh_c">' + s1 + '</pre>' );
    });

    message = message.replace(/&#62;\|php\|\n([\s\S]*?)\n\|\|&#60;/g, function(whole,s1) {
        return( '<pre class="sh_php">' + s1 + '</pre>' );
    });

    message = message.replace(/&#62;\|AA\|\n([\s\S]*?)\n\|\|&#60;/gi, function(whole,s1) {
        return( '<pre style=\'font-family: "Mona","IPA MONAPGOTHIC","MS PGothic","ＭＳ Ｐゴシック","MS Pｺﾞｼｯｸ","MS Pゴシック",sans-serif; \'>'
                + s1
                + '</pre>'
              );
    });

    message = message.replace(/&#62;\|\|\n([\s\S]*?)\n\|\|&#60;/g, function(whole,s1) {
        return( '<pre>' + s1 + '</pre>' );
    });

    message = message.replace(/&#62#62;\n([\s\S]*?)\n&#60;&#60;/g, function(whole,s1) {
        return( '<blockquote>' + s1 + '</blockquote>' );
    });  
    
    message = message.replace(/\n/g, "<br />");


    message = message.replace(/#([a-zA-Z0-9]+)($| )/g, function(whole,s1) {
        return( ' <span style="color:orange;font-weight:bold" onclick="addTag(\''+s1+'\')">#' + s1 + '</span> ' );
    });

    return message;

}

function load_gist(gistid){
    var gistFrame = $('iframe[data-gist-id='+gistid+']').last().get(0);

    if (gistFrame.contentDocument) {
        var gistFrameDoc = gistFrame.contentDocument;
    } else if (gistFrame.contentWindow) {
        var gistFrameDoc = gistFrame.contentWindow.document;
    }

    var gistFrameHTML = '<html><body onload="parent.adjustIframeSize('+gistid+', document.body.scrollHeight)"><scr' + 'ipt type="text/javascript" src="https://gist.github.com/' + gistid + '.js"></sc'+'ript></body></html>';

    gistFrameDoc.open();
    gistFrameDoc.writeln(gistFrameHTML);
    gistFrameDoc.close();
}

function adjustIframeSize(gistid, newHeight) {
    var i = $('iframe[data-gist-id='+gistid+']');
    i.css('height',parseInt(newHeight) + "px");
}
