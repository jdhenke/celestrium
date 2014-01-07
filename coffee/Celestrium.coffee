class Celestrium

  constructor: () ->
    @defs = {}

  register: (Plugin) ->
    @defs[Plugin.uri] = Plugin

  init: (plugins, callback) ->
    instances = {}
    _.each plugins, (args, uri) =>
      Plugin = @defs[uri]
      instance = new Plugin(args)
      if instance.init?
        instance.init instances
      instances[pluginPaths[i]] = instance
    callback(instances) if callback?

window.celestrium = new Celestrium()
