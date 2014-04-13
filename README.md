Celestrium
==========

Easily create graph visualization and exploration interfaces on the web.

## Setup

The typical setup for using Celestrium is to add it as a git submodule of your repo.

```bash
# add this repo as a submodule
git submodule add https://github.com/jdhenke/celestrium.git ./celestrium

# install node packages required to build the full script
(cd celestrium && npm install)
```

Celestrium doesn't commit the compiled script itself - it must be built.
To do this, make sure you have `grunt-cli` installed globally, then simply run

```bash
(cd celestrium && grunt)
```

If you are making changes to celestrium, you might want to use the grunt task which watches for changes in files and automatically triggers the build.
```bash
(cd celestrium && grunt watch)
```

These will generate `celestrium.js`, `celestrium.js.map` and `celestrium.src.coffee` in `celestrium`.

Here is an example of a way to structure a repo which uses celestrium.

    repo/
      celestrium/      # git submodule inside repo
        ...
      index.html
      js/
        celestrium.js  # symbolic link to ../celestrium/celestrium.js

You can also link `celestrium.js.map` and `celestrium.src.coffee`.

See [celestrium-example](https://github.com/jdhenke/celestrium-example) for a working example.

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
These are typically things which are specific to an implementation.

To use your plugin, you are required to call `celestrium.register` with the class definition as the argument.
This allows you to reference your plugin by it's URI in `celestrium.init`.
Your plugins, therefore, must be registered *before* being referenced in `celestrium.init`.
It is therefore recommended to run `celestrium.init` after the page has loaded.

### DataProvider

TODO
