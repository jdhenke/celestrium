Celestrium
==========

Easily create graph visualization and exploration interfaces on the web.

See [celestrium-example](https://github.com/jdhenke/celestrium-example) for an example infrastructure.

## API

### Main Entry Point

Celestrium is accessible as the globally defined `celestrium` variable.

You can use it's plugins, and any you create, with `celestrium.init`.
It accepts a dictionary with each key, value pair as a plugin's URI and it's constructor argument, respectively.

```coffeescript
celestrium.init
  "Layout":
    "el": document.querySelector '#workspace'
  "KeyListener": {}
  # etc...
```

Note, a second argument to `celestrium.init` may be a function, which will be called after all plugins have been initialized with a dictionary that has key, value pairs as the uri, instance of that plugin.

```coffeescript
celestrium.init pluginsDict, (instances) ->
  someInstance = instances[someURI]
```

### General Plugin Spec

Here's the spec for a plugin class which may be used by celestrium.

```coffeescript

# example plugin class definition
class ExamplePlugin

  # URI should be a string unique to this plugin
  @uri: "ExamplePlugin"

  # specify which attributes to which to assign instances of other attributes
  @needs:
    "otherPlugin": "OtherPluginURI"

  # args is the value from celestrium.init
  constructor: (arg) ->
    # can reference @otherPlugin here

# register your plugin so it can be specified in celestrium.init
celestrium.register(ExamplePlugin)

```

The **uri** is a hard requirement for every plugin.
This is the string used in `celestrium.init` to locate the class definition.

The **needs** attribute is optional.
It defines which attributes to assign instances of other plugins.
The attributes will be available to the plugin instance, even in the constructor.

The **constructor** is optional, and will be provided a single argument - the value for it's URI key in the dictionary passed to `celestrium.init`.
These are typically things which are specific to an impelementation.

To use your plugin, you are required to call `celestrium.register` with the class definition as the argument.
This allows you to reference your plugin by it's URI in `celestrium.init`.
Your plugins, therefore, must be registered *before* being referenced in `celestrium.init`.
It is therefore recommended to run `celestrium.init` after the page has loaded.

### DataProvider

This is an abstract class definition which should be extended to allow the graph to be populated. Here's an example.

```coffeescript

# define an implementation of DataProvider
class ExampleDataProvider extends celestrium.defs["DataProvider"]

  @uri: "ExampleDataProvider"

  # calls callback with nodes adjacent to any node in nodes
  getNeighbors: (nodes, callback) ->

  # calls callback with links between node and nodes
  getLinks: (node, nodes, callback) ->

celestrium.register ExampleDataProvider

```

The **getNeighbors** function must call `callback` with an array of node objects for each node adjacent to any node in `nodes`.
Node objects are javascript objects and should not conflict with [d3's attributes](https://github.com/mbostock/d3/wiki/Force-Layout#wiki-nodes).
Additionally, a `text` attribute should be defined as the text to be displayed next to the node in the graph.

The **getLinks** function must call its `callback` with an array of link objects, `A`, st. `A[i]` is the link object for the link from `node` to `nodes[i]`.
`null` values are ignored.
Node objects are javascript objects and should not conflict with [d3's attributes](https://github.com/mbostock/d3/wiki/Force-Layout#wiki-links) - DataProvider automatically assigns each link's source and target per this specification.
A `strength` attribute may also be defined for a link and must be between 0 and 1.
The default value is 1.

You can now reference your Data Provider implementation in `celestrium.init` with it's URI as the key and anything as it's value, typically `{}`.
