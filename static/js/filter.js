function user_message_filter(message){

    //auto inline display(pyazo)
    message = message.replace(/http(s)?:\/\/yairc.cfe.jp(:5000)?(\/[\x21-\x7e]+)\.(png|gif|jpg|jpeg)/gi,
                              "<a href='//yairc.cfe.jp$3.$4' target='_blank'><img src='//yairc.cfe.jp$3.$4' style='max-width:300px;max-height:300px;'/></a>");

    message = message.replace(/http(s)?:\/\/yairc.cfe.jp(:5000)?(\/[\x21-\x7e]+)\.^(png|gif|jpg|jpeg)/gi,
                                                  "<a href='//yairc.cfe.jp$3.$4' target='_blank'>//yairc.cfe.jp$3.$4</a>");

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
    
    message = message.replace(/&#62;&#62;\n([\s\S]*?)\n&#60;&#60;/g, function(whole,s1) {
        return( '<blockquote>' + s1 + '</blockquote>' );
    });  
    
    message = message.replace(/\n/g, "<br />");


    message = message.replace(/#([a-zA-Z0-9]+)($| )/g, function(whole,s1) {
        return( ' <span style="color:orange;font-weight:bold" onclick="addTag(\''+s1+'\')">#' + s1 + '</span> ' );
    });  

    return message;

}
