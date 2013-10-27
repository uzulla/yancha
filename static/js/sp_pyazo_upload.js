function android_upload_to_pyazo(e){
    e.stopPropagation();
    e.preventDefault();

    var target = e.srcElement || e.target;
    var form = $(target).parent();
    $(form).ajaxSubmit({
        resetForm: true,
        dataType: 'text',
        success: function(data){
            $('#message').val(data);
            $('#message').focus();
            hidemenu();
        },
        error: function(){
            alert('upload error');
        }
    });
}