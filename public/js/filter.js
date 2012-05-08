function user_message_filter(message){

  //auto inline display(pyazo)
  message = message.replace(/http(s)?:\/\/yairc.cfe.jp:5000(\/[\x21-\x7e]+)/gi, "<a href='//yairc.cfe.jp:5000$2' target='_blank'><img src='//yairc.cfe.jp:5000$2' style='max-width:300px;max-height:300px;'/></a>");

  // YT thumbnail
  message = message.replace(/http(s)?:\/\/www.youtube.com\/[\x21-\x7e]*v=([a-zA-Z0-9\-]+)/g, "<img src='//i1.ytimg.com/vi/$2/default.jpg'><br />http://www.youtube.com/watch?v=$2");

  //auto link
  message = message.replace(/(http(s)?:\/\/[\x21-\x7e]+)/gi, "<a href='$1' target='_blank'>$1</a>");

  message = message.replace(/&#62;\|javascript\|\n([\s\S]*)\n\|\|&#60;/g,
    function(whole,s1) {
　　　 return( '<pre class="sh_javascript">' + s1 + '</pre>' );
　　　}
  );
  
  var foundShHighlight = false;

  message = message.replace(/&#62;\|perl\|\n([\s\S]*)\n\|\|&#60;/g,
    function(whole,s1) {
　　　 return( '<pre class="sh_perl">' + s1 + '</pre>' );
　　　}
  );

  message = message.replace(/&#62;\|AA\|\n([\s\S]*)\n\|\|&#60;/gi,
    function(whole,s1) {
　　　 return( '<pre style=\'font-family: "MS Pゴシック","MS ゴシック","ＭＳ Ｐゴシック","ＭＳ ゴシック",sans-serif;\'>' + s1 + '</pre>' );
　　　}
  );

  message = message.replace(/&#62;\|\|\n([\s\S]*)\n\|\|&#60;/g,
    function(whole,s1) {
　　　 return( '<pre>' + s1 + '</pre>' );
　　　}
  );
  
  message = message.replace(/&#62;&#62;\n([\s\S]*)\n&#60;&#60;/g,
    function(whole,s1) {
　　　 return( '<pre>' + s1 + '</pre>' );
　　　}
  );  
  
  message = message.replace(/\n/g, "<br />");

  return message;

}