L = -> console.log(arguments...)

class View

  messages =
    ok: -> "ALL SYSTEMS GO"
    disconnected: -> "<span>DISCONNECTED!</span>"
    playing: (sound) -> "PLAYING SOUND <span>#{sound}</span>"
    playingTo: (listeners) -> "PLAYING TO <span>#{listeners}</span> #{if listeners is 1 then "PERSON" else "PEOPLE"}"
    error: (message) -> "ERROR: <span>#{message}</span>"
    connections: (amount) -> "CONNECTIONS: <span>#{amount}</span>"

  setStatus: (key, params...) ->
    message = messages[key](params...)
    $('#status').html(message)

  sound: (event) ->
    $(event.currentTarget).attr('data-file')

  versions: (event) ->
    $(event.currentTarget).attr('data-versions')

  highlightSound: (sound) ->
    @findSound(sound).addClass('hover')

  dehighlightSound: (sound) ->
    @findSound(sound).removeClass('hover')

  findSound: (sound) ->
    $("li[data-file=#{sound}]")

  revertStatus: ->
    @setStatus "ok"
    @overlay().hide()

  setDisconnected: ->
    @setStatus "disconnected"
    @overlay().show()

  sounds: ->
    @__sounds ?= $('ul li')

  overlay: ->
    @__overlay ?= $('#overlay')

  preview: ->
    @__preview ?= $('#preview')

  previewCheckbox: ->
    @__previewCheckbox ?= @preview().find('.checkbox')

  enablePreview: ->
    @previewCheckbox().html('X')

  disablePreview: ->
    @previewCheckbox().html(' ')

  reverb: ->
    @__reverb ?= $('#reverb')

  reverbCheckbox: ->
    @__reverbCheckbox ?= @reverb().find('.checkbox')

  enableReverb: ->
    @reverbCheckbox().html('X')

  disableReverb: ->
    @reverbCheckbox().html(' ')

class App

  constructor: (@view) ->
    @controller = new Controller(@view)
    @connect()
    @initSounds()
    @initPreview()
    @initReverb()

  initSounds: ->
    @view.sounds().click => @handleSoundClick(event)

  initPreview: ->
    @view.preview().click => @handlePreviewClick(event)
    @preview = false
    @renderPreviewState()

  initReverb: ->
    @view.reverb().click => @handleReverbClick(event)
    @reverb = false
    @renderReverbState()

  connect: ->
    L 'starting connection'
    @socket = new WebSocket("ws://#{window.location.hostname}:8080")
    @socket.onopen    = (data) => @onSocketOpen (data)
    @socket.onclose   = (data) => @onSocketClose (data)
    @socket.onmessage = (data) => @onSocketMessage (data)
    @socket.onerror   = (data) => @onSocketError (data)

  handleSoundClick: (event) ->
    sound = @view.sound(event)
    versions = @view.versions(event) || "false"
    @socket.send("""{ "action": "playAudio", "args": { "sound": "#{sound}", "preview": #{@preview}, "reverb": #{@reverb}, "versions": #{versions} } }""")

  handlePreviewClick: (event) ->
    @preview = !@preview
    @renderPreviewState()

  renderPreviewState: ->
    if @preview
      @view.enablePreview()
    else
      @view.disablePreview()

  handleReverbClick: (event) ->
    @reverb = !@reverb
    @renderReverbState()

  renderReverbState: ->
    if @reverb
      @view.enableReverb()
    else
      @view.disableReverb()

  onSocketMessage: (data) ->
    L 'onSocketMessage'
    message = $.parseJSON(data.data)
    method  = message.action.substr(0, 1).toUpperCase() + message.action.substr(1)
    @controller["on#{method}"](message.args)

  onSocketError: (data) ->
    L 'onSocketError'
    @view.setStatus "error", data.data

  onSocketOpen: (data) ->
    L 'onSocketOpen'
    @view.revertStatus()

  onSocketClose: (data) ->
    L 'onSocketClose'
    @view.setDisconnected()
    setTimeout((=> @connect()), 1000)


class Controller

  constructor: (@view) ->
    @soundplayer = new SoundPlayer()

  onPlayAudio: (args) ->
    file_base = file = args.sound
    L "Playing '#{file_base}'"
    if args.versions
      sound_index = Math.ceil(Math.random() * parseInt(args.versions))
      L "Version: #{sound_index} / #{args.versions}"
      file = "#{file_base}#{sound_index}"

    @soundplayer.play(file, { reverb: args.reverb, file_base: file_base, callback: @handleSoundEnd} )

    @view.highlightSound(file_base)
    @view.setStatus "playing", file_base

  onConnectionChange: (args) ->
    @view.setStatus "connections", args.listeners
    @timeoutStatus()

  onPlayingSoundToOthers: (args) ->
    @view.setStatus "playingTo", args.listeners
    @timeoutStatus()

  handleSoundEnd: (sound) =>
    @view.dehighlightSound(sound)
    @view.revertStatus()

  timeoutStatus: ->
    setTimeout((=> @view.revertStatus()), 2500)


class SoundPlayer

  constructor: ->
    @context = new webkitAudioContext()
    @samples = {}

    @reverb = @context.createConvolver()
    @reverb.connect(@context.destination)
    @load("/audio/reverb.wav", (response) =>
      @reverb.buffer = @context.createBuffer(response, false))

  play: (path, options) ->
    sample = @context.createBufferSource()
    sample.connect(@context.destination)
    sample.connect(@reverb) if options.reverb == true
    id = @context.currentTime
    @samples[id] = sample
    @load("/audio/#{path}.ogg", (response) =>
      @samples[id].buffer = @context.createBuffer(response, false)
      @samples[id].noteOn(0)
      setTimeout(=>
        @samples[id].noteOff(0)
        @samples[id] = null
        options.callback(options.file_base)
      , @samples[id].buffer.duration * 1000)
    )


  load: (path, callback) ->
    request = new XMLHttpRequest()
    request.open("GET", path, true)
    request.responseType = "arraybuffer"
    request.onload = ->
      callback(request.response)
    request.send()


jQuery ->
  new App(new View)
