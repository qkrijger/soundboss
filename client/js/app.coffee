class App
  constructor: ->
    @controller = new Controller()
    @socket = new WebSocket("ws://#{window.location.hostname}:8080")
    @socket.onmessage = (data) => @onSocketMessage (data)

    @initSounds()

  initSounds: ->
    $('ul li').click => @handleSoundClick(event)

  handleSoundClick: (event) ->
    @socket.send("{ \"action\": \"playAudio\", \"args\": { \"sound\": \"#{$(event.currentTarget).attr('rel')}\" }}")

  onSocketMessage: (data) ->
    message = $.parseJSON(data.data)
    method  = message.action.substr(0, 1).toUpperCase() + message.action.substr(1)

    @controller["on#{method}"](message.args)


class Controller
  onPlayAudio: (args) ->
    console.log "playing #{args.sound}"
    $('#status').html("PLAYING SOUND <span>#{args.sound}</span>")


$ ->
  new App()
