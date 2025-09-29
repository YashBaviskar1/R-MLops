#* @get /echo 
function(msg = "") {
    list(msg = paste0("The message is: '", msg, "'"))
}


#* @get /hello
function(){
    list("Hello, world!")
}

#* @post /send-message 
function(msg = ""){
    message = msg
}