/*
 jquery.webkit-notification plugin v 0.1
 Developed by Arjun Raj
 email: arjun@athousandnodes.com
 site: http://www.athousandnodes.com

 Licences: MIT, GPL
 http://www.opensource.org/licenses/mit-license.php
 http://www.gnu.org/licenses/gpl.html
 */

//Globals
var jwNotify = {};
jwNotify.status = false;
//Check if the browser supports notifications
if (typeof( eval(window.webkitNotifications) ) != 'undefined'){
    jwNotify.status = true;
    jwNotify.notifications = window.webkitNotifications;
}
else {
    jwNotify.notifications = {
        requestPermission: function(){},
        checkPermission: function(){},
        createHTMLNotification: function(){},
        createNotification: function(){}
    };
}

//Function to request for permission
function requestingPopupPermission(callback){
    //Check if the feature is supported by browser and the variables have be saved
    if((jwNotify.status) && (jwNotify.options) && (jwNotify.type))
        jwNotify.notifications.requestPermission(callback);
    else
        console.log('Error');
}

//Function to show the actual Notification
function showNotification(){

    
    if(jwNotify.notifications.checkPermission() != 0){
        requestingPopupPermission(showNotification);
    }
    else{

        if(jwNotify.type == 'html'){
            if(jwNotify.options.url){
                var popup = jwNotify.notifications.createHTMLNotification(jwNotify.options.url);

                //Invoke the onclick function
                if(jwNotify.options.onclick)
                    popup.onclick = jwNotify.options.onclick;
                //Invoke the onshow function
                if(jwNotify.options.onshow)
                    popup.onshow = jwNotify.options.onshow;
                //Invoke the onclose function
                if(jwNotify.options.onclose)
                    popup.onclose = jwNotify.options.onclose;
                //Invoke the onshow function
                if(jwNotify.options.onerror)
                    popup.onerror = jwNotify.options.onerror;

                //replaceId for the notification
                if(jwNotify.options.id)
                    popup.replaceId = jwNotify.options.id;


                popup.show();
            }
        }
        else{
            if(jwNotify.options.image || jwNotify.options.title || jwNotify.options.body){
                var popup = jwNotify.notifications.createNotification(jwNotify.options.image, jwNotify.options.title, jwNotify.options.body);

                //Add Directionality for the shown text
                if(jwNotify.options.dir)
                    popup.dir = jwNotify.options.dir;

                //Invoke the onclick function
                if(jwNotify.options.onclick)
                    popup.onclick = jwNotify.options.onclick;
                //Invoke the onshow function
                if(jwNotify.options.onshow)
                    popup.onshow = jwNotify.options.onshow;
                //Invoke the onclose function
                if(jwNotify.options.onclose)
                    popup.onclose = jwNotify.options.onclose;
                //Invoke the onshow function
                if(jwNotify.options.onerror)
                    popup.onerror = jwNotify.options.onerror;

                //replaceId for the notification
                if(jwNotify.options.id)
                    popup.replaceId = jwNotify.options.id;


                popup.show();
            }
            else
                console.log('not enough parameters');
        }

        if(popup && (jwNotify.options.timeout > 0)){
            //Set Timeout for hiding the popup!
            setTimeout(function(){
                popup.cancel();
            }, jwNotify.options.timeout);

            //Reset once showing it!
            jwNotify.options = null;
            jwNotify.type = null;
        }
    }
}

jQuery.extend({

    jwNotify: function(options){


        //Defaults
        var settings = {
            image : null,           //Image to be shown in the notification area
            title: null,            //Title
            body: null,             //Body of the notification to be shown
            // persist : false,     // Not required
            timeout: 5000,          //In milli seconds, if timout is 0 then the message will persist till the user closes it
            dir : null,            //Direction of the text shown in the notification
            onclick: null,           //Callback for onclick event on the notification
            onshow: null,           //Callback for onshow event
            onerror: null,          //Callback for onerror event
            onclose: null,          //Callback for onclose event
            id: null                //Identifier for the notifiction. This is used to identify the notification message shown.
        };

        if(options)
            $.extend(settings, options);

        jwNotify.options = settings;
        jwNotify.type = 'normal';

        showNotification();

    },

    jwNotifyHTML : function(options){

        //Defaults
        var settings = {
            url: null,             //HTML mode only takes 2 options this is for the url of the html page
            timeout: 5000,          //Timeout for hiding it
            onclick: null,           //Callback for onclick event on the notification
            onshow: null,           //Callback for onshow event
            onerror: null,          //Callback for onerror event
            onclose: null,          //Callback for onclose event
            id: null                //Identifier for the notifiction. This is used to identify the notification message shown.
        };

        if(options)
            $.extend(settings, options);

        jwNotify.options = settings;
        jwNotify.type = 'html';

        showNotification();

    }
});  
