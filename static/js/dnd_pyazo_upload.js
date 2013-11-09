$(function(){

var PYAZO_URL = "http://pyazo.hachiojipm.org/";

function handleFileSelect(e) {
    e.stopPropagation();
    e.preventDefault();
    $(e.target).removeClass('on');
    $(e.target).addClass('send');

    var files = e.dataTransfer.files; // FileList object.

    if(files.length!=1){
        alert('allow only one file in upload.');
        return;
    }

    var data = new FormData();
    data.append('imagedata', files[0]);

    $.ajax({
        url: PYAZO_URL,
        type: "POST",
        data: data,
        processData: false,
        contentType: false,
        dataType: "text",
        success: function(data){
            $("#file_dnd_box").removeClass('send');
            $('#message').val($('#message').val()+data);
            $('#message').focus();
        },
        error: function(){
            alert('Fail upload');
            $("#file_dnd_box").removeClass('send').removeClass('on');
        }
    });

}

function handleDragOver(e) {
    e.stopPropagation();
    e.preventDefault();
    e.dataTransfer.dropEffect = 'copy'; // Explicitly show this is a copy.
    $(e.target).addClass('on');
}

function handleDragLeave(e) {
    e.stopPropagation();
    e.preventDefault();
    $(e.target).removeClass('on');
}

// Setup the dnd listeners.
var dropZone = document.getElementById('file_dnd_box');
dropZone.addEventListener('dragover', handleDragOver, false);
dropZone.addEventListener('drop', handleFileSelect, false);
dropZone.addEventListener('dragleave', handleDragLeave, false);

});
