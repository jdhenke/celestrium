(function() {
  var Celestrium, DataProvider, DependencyProvider, ForceSliders, GraphModel, GraphView, KeyListener, Layout, LinkDistributionView, LinkFilter, NodeDetailsView, NodeSelection, PluginWrapper, SelectionLayer, SlidersView, StaticProvider, StatsView, height, margin, maxStrength, minStrength, width, _ref, _ref1, _ref2, _ref3,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  Celestrium = (function() {
    function Celestrium() {
      this.defs = {};
    }

    Celestrium.prototype.register = function(Plugin) {
      return this.defs[Plugin.uri] = Plugin;
    };

    Celestrium.prototype.init = function(plugins, callback) {
      var arg, instances, instantiate, queue, uri,
        _this = this;
      instances = {};
      queue = (function() {
        var _results;
        _results = [];
        for (uri in plugins) {
          arg = plugins[uri];
          _results.push(uri);
        }
        return _results;
      })();
      instantiate = function(uri, parents) {
        var Temp, attr, cycleStr, index, instance, parentURI, _fn, _ref, _ref1;
        if (__indexOf.call(parents, uri) >= 0) {
          cycleStr = JSON.stringify(parents.concat([uri]));
          throw new Error("Circular dependency detected: " + cycleStr);
        }
        if (_this.defs[uri] == null) {
          throw new Error("" + uri + " has not been registered");
        }
        index = queue.indexOf(uri);
        if (index > -1) {
          queue.splice(index, 1);
        } else {
          throw new Error("" + uri + " was not specified in celestrium.init");
        }
        /* create instance of plugin identified by `uri`*/

        Temp = (function(_super) {
          __extends(Temp, _super);

          function Temp() {
            _ref = Temp.__super__.constructor.apply(this, arguments);
            return _ref;
          }

          return Temp;

        })(_this.defs[uri]);
        if (Temp.needs == null) {
          Temp.needs = {};
        }
        _ref1 = Temp.needs;
        _fn = function(attr, parentURI) {
          if (instances[parentURI] == null) {
            instantiate(parentURI, parents.concat([uri]));
          }
          return Temp.prototype[attr] = instances[parentURI];
        };
        for (attr in _ref1) {
          parentURI = _ref1[attr];
          _fn(attr, parentURI);
        }
        arg = plugins[uri];
        instance = new Temp(arg);
        return instances[uri] = instance;
      };
      while (queue.length > 0) {
        instantiate(queue[0], []);
      }
      if (callback != null) {
        return callback(instances);
      }
    };

    return Celestrium;

  })();

  window.celestrium = new Celestrium();

  DataProvider = (function() {
    DataProvider.uri = "DataProvider";

    DataProvider.needs = {
      graphModel: "GraphModel",
      keyListener: "KeyListener",
      nodeSelection: "NodeSelection"
    };

    function DataProvider() {
      var _this = this;
      this.keyListener.on("down:16:187", function() {
        return _this.searchAround(function(nodes, links) {
          _.each(nodes, function(node) {
            return _this.graphModel.putNode(node);
          });
          return _.each(links, function(link) {
            return _this.graphModel.putLink(link);
          });
        });
      });
    }

    DataProvider.prototype.searchAround = function(callback) {};

    return DataProvider;

  })();

  celestrium.register(DataProvider);

  DependencyProvider = (function(_super) {
    __extends(DependencyProvider, _super);

    function DependencyProvider() {
      _ref = DependencyProvider.__super__.constructor.apply(this, arguments);
      return _ref;
    }

    DependencyProvider.uri = "DependencyProvider";

    DependencyProvider.prototype.searchAround = function(callback) {
      var links, needs, newNodes, nodes,
        _this = this;
      nodes = this.graphModel.getNodes();
      newNodes = _.chain(this.nodeSelection.getSelectedNodes()).map(function(node) {
        var needs;
        needs = celestrium.defs[node.text].needs;
        if (needs == null) {
          needs = {};
        }
        return _.values(needs);
      }).flatten().filter(function(text) {
        return !_this.graphModel.get("nodeSet")[text];
      }).uniq().map(function(text) {
        return {
          text: text
        };
      }).value();
      needs = function(a, b) {
        var A, output, _ref1;
        A = celestrium.defs[a.text];
        output = (A.needs != null) && (_ref1 = b.text, __indexOf.call(_.values(A.needs), _ref1) >= 0);
        return output;
      };
      links = [];
      _.each(nodes, function(oldNode, i) {
        return _.each(newNodes, function(newNode, j) {
          if (needs(oldNode, newNode)) {
            return links.push({
              source: i,
              target: nodes.length + j,
              strength: 0.8,
              direction: "forward"
            });
          } else if (needs(newNode, oldNode)) {
            return links.push({
              source: i,
              target: nodes.length + j,
              strength: 0.8,
              direction: "backward"
            });
          }
        });
      });
      _.each(newNodes, function(node1, i) {
        return _.each(newNodes, function(node2, j) {
          if (i === j) {
            return;
          }
          if (needs(node1, node2)) {
            return links.push({
              source: nodes.length + i,
              target: nodes.length + j,
              strength: 0.8,
              direction: "forward"
            });
          }
        });
      });
      return callback(newNodes, links);
    };

    return DependencyProvider;

  })(celestrium.defs["DataProvider"]);

  celestrium.register(DependencyProvider);

  ForceSliders = (function() {
    ForceSliders.uri = "ForceSliders";

    ForceSliders.needs = {
      sliders: "Sliders",
      graphView: "GraphView"
    };

    function ForceSliders(instances) {
      var force, scale;
      scale = d3.scale.linear().domain([-20, -2000]).range([0, 100]);
      force = this.graphView.getForceLayout();
      this.sliders.addSlider("Spacing", scale(force.charge()), function(val) {
        force.charge(scale.invert(val));
        return force.start();
      });
    }

    return ForceSliders;

  })();

  celestrium.register(ForceSliders);

  GraphModel = (function(_super) {
    __extends(GraphModel, _super);

    function GraphModel() {
      _ref1 = GraphModel.__super__.constructor.apply(this, arguments);
      return _ref1;
    }

    GraphModel.uri = "GraphModel";

    GraphModel.prototype.initialize = function() {
      return this.set({
        "nodes": [],
        "links": [],
        "nodeSet": {},
        "nodeHash": function(node) {
          return node.text;
        },
        "linkHash": function(link) {
          return link.source.text + link.target.text;
        }
      });
    };

    GraphModel.prototype.getNodes = function() {
      return this.get("nodes");
    };

    GraphModel.prototype.getLinks = function() {
      return this.get("links");
    };

    GraphModel.prototype.hasNode = function(node) {
      return this.get("nodeSet")[this.get("nodeHash")(node)] != null;
    };

    GraphModel.prototype.putNode = function(node) {
      var nodeAttributes;
      if (this.hasNode(node)) {
        return;
      }
      nodeAttributes = this.get("nodeAttributes");
      node.getAttributeValue = function(attr) {
        return nodeAttributes[attr].getValue(node);
      };
      this.get("nodeSet")[this.get("nodeHash")(node)] = true;
      this.trigger("add:node", node);
      return this.pushDatum("nodes", node);
    };

    GraphModel.prototype.putLink = function(link) {
      if (link.strength == null) {
        link.strength = 1;
      }
      this.pushDatum("links", link);
      return this.trigger("add:link", link);
    };

    GraphModel.prototype.linkHash = function(link) {
      return this.get("linkHash")(link);
    };

    GraphModel.prototype.pushDatum = function(attr, datum) {
      var data;
      data = this.get(attr);
      data.push(datum);
      this.set(attr, data);
      /*
      QA: this is not already fired because of the rep-exposure of get.
      `data` is the actual underlying object
      so even though set performs a deep search to detect changes,
      it will not detect any because it's literally comparing the same object.
      
      Note: at least we know this will never be a redundant trigger
      */

      this.trigger("change:" + attr);
      return this.trigger("change");
    };

    GraphModel.prototype.filterNodes = function(filter) {
      var linkFilter, nodeWasRemoved, removed, wrappedFilter,
        _this = this;
      nodeWasRemoved = function(node) {
        return _.some(removed, function(n) {
          return _.isEqual(n, node);
        });
      };
      linkFilter = function(link) {
        return !nodeWasRemoved(link.source) && !nodeWasRemoved(link.target);
      };
      removed = [];
      wrappedFilter = function(d) {
        var decision;
        decision = filter(d);
        if (!decision) {
          removed.push(d);
          delete _this.get("nodeSet")[_this.get("nodeHash")(d)];
        }
        return decision;
      };
      this.filterAttribute("nodes", wrappedFilter);
      return this.filterLinks(linkFilter);
    };

    GraphModel.prototype.filterLinks = function(filter) {
      return this.filterAttribute("links", filter);
    };

    GraphModel.prototype.filterAttribute = function(attr, filter) {
      var filteredData;
      filteredData = _.filter(this.get(attr), filter);
      return this.set(attr, filteredData);
    };

    return GraphModel;

  })(Backbone.Model);

  celestrium.register(GraphModel);

  LinkFilter = (function(_super) {
    __extends(LinkFilter, _super);

    function LinkFilter() {
      _ref2 = LinkFilter.__super__.constructor.apply(this, arguments);
      return _ref2;
    }

    LinkFilter.prototype.initialize = function() {
      return this.set("threshold", 0.75);
    };

    LinkFilter.prototype.filter = function(links) {
      var _this = this;
      return _.filter(links, function(link) {
        return link.strength > _this.get("threshold");
      });
    };

    LinkFilter.prototype.connectivity = function(value) {
      if (value) {
        return this.set("threshold", value);
      } else {
        return this.get("threshold");
      }
    };

    return LinkFilter;

  })(Backbone.Model);

  GraphView = (function(_super) {
    __extends(GraphView, _super);

    GraphView.uri = "GraphView";

    GraphView.needs = {
      model: "GraphModel"
    };

    function GraphView(options) {
      this.options = options;
      GraphView.__super__.constructor.call(this, this.options);
      this.model.on("change", this.update.bind(this));
      this.render();
    }

    GraphView.prototype.initialize = function(options) {
      this.linkFilter = new LinkFilter(this);
      return this.listenTo(this.linkFilter, "change:threshold", this.update);
    };

    GraphView.prototype.render = function() {
      var currentZoom, defs, initialWindowHeight, initialWindowWidth, linkContainer, nodeContainer, style, svg, translateLock, workspace, zoom, zoomCapture,
        _this = this;
      initialWindowWidth = this.$el.width();
      initialWindowHeight = this.$el.height();
      this.force = d3.layout.force().size([initialWindowWidth, initialWindowHeight]).charge(-500).gravity(0.2);
      this.linkStrength = function(link) {
        return (link.strength - _this.linkFilter.get("threshold")) / (1.0 - _this.linkFilter.get("threshold"));
      };
      this.force.linkStrength(this.linkStrength);
      svg = d3.select(this.el).append("svg:svg").attr("pointer-events", "all");
      zoom = d3.behavior.zoom();
      defs = svg.append("defs");
      defs.append("marker").attr("id", "Triangle").attr("viewBox", "0 0 20 15").attr("refX", "15").attr("refY", "5").attr("markerUnits", "userSpaceOnUse").attr("markerWidth", "20").attr("markerHeight", "15").attr("orient", "auto").append("path").attr("d", "M 0 0 L 10 5 L 0 10 z");
      defs.append("marker").attr("id", "Triangle2").attr("viewBox", "0 0 20 15").attr("refX", "-5").attr("refY", "5").attr("markerUnits", "userSpaceOnUse").attr("markerWidth", "20").attr("markerHeight", "15").attr("orient", "auto").append("path").attr("d", "M 10 0 L 0 5 L 10 10 z");
      style = $("    <style>      .nodeContainer .node text { opacity: 0.5; }      .nodeContainer .selected circle { fill: steelblue; }      .nodeContainer .node:hover text { opacity: 1; }      .nodeContainer:hover { cursor: pointer; }      .linkContainer .link { stroke: gray; opacity: 0.5; }    </style>    ");
      $("html > head").append(style);
      zoomCapture = svg.append("g");
      zoomCapture.append("svg:rect").attr("width", "100%").attr("height", "100%").style("fill-opacity", "0%");
      translateLock = false;
      currentZoom = void 0;
      this.force.drag().on("dragstart", function() {
        translateLock = true;
        return currentZoom = zoom.translate();
      }).on("dragend", function() {
        zoom.translate(currentZoom);
        return translateLock = false;
      });
      zoomCapture.call(zoom.on("zoom", function() {
        if (translateLock) {
          return;
        }
        return workspace.attr("transform", "translate(" + d3.event.translate + ") scale(" + d3.event.scale + ")");
      })).on("dblclick.zoom", null);
      workspace = zoomCapture.append("svg:g");
      linkContainer = workspace.append("svg:g").classed("linkContainer", true);
      nodeContainer = workspace.append("svg:g").classed("nodeContainer", true);
      return this;
    };

    GraphView.prototype.update = function() {
      var filteredLinks, link, linkEnter, links, node, nodeEnter, nodes,
        _this = this;
      nodes = this.model.get("nodes");
      links = this.model.get("links");
      filteredLinks = this.linkFilter ? this.linkFilter.filter(links) : links;
      this.force.nodes(nodes).links(filteredLinks).start();
      link = this.linkSelection = d3.select(this.el).select(".linkContainer").selectAll(".link").data(filteredLinks, this.model.get("linkHash"));
      linkEnter = link.enter().append("line").attr("class", "link").attr('marker-end', function(link) {
        if (link.direction === 'forward' || link.direction === 'bidirectional') {
          return 'url(#Triangle)';
        }
      }).attr('marker-start', function(link) {
        if (link.direction === 'backward' || link.direction === 'bidirectional') {
          return 'url(#Triangle2)';
        }
      });
      this.force.start();
      link.exit().remove();
      link.attr("stroke-width", function(link) {
        return 5 * (_this.linkStrength(link));
      });
      node = this.nodeSelection = d3.select(this.el).select(".nodeContainer").selectAll(".node").data(nodes, this.model.get("nodeHash"));
      nodeEnter = node.enter().append("g").attr("class", "node").call(this.force.drag);
      nodeEnter.append("text").attr("dx", 12).attr("dy", ".35em").text(function(d) {
        return d.text;
      });
      nodeEnter.append("circle").attr("r", 5).attr("cx", 0).attr("cy", 0);
      this.trigger("enter:node", nodeEnter);
      this.trigger("enter:link", linkEnter);
      node.exit().remove();
      return this.force.on("tick", function() {
        link.attr("x1", function(d) {
          return d.source.x;
        }).attr("y1", function(d) {
          return d.source.y;
        }).attr("x2", function(d) {
          return d.target.x;
        }).attr("y2", function(d) {
          return d.target.y;
        });
        return node.attr("transform", function(d) {
          return "translate(" + d.x + "," + d.y + ")";
        });
      });
    };

    GraphView.prototype.getNodeSelection = function() {
      return this.nodeSelection;
    };

    GraphView.prototype.getLinkSelection = function() {
      return this.linkSelection;
    };

    GraphView.prototype.getForceLayout = function() {
      return this.force;
    };

    GraphView.prototype.getLinkFilter = function() {
      return this.linkFilter;
    };

    return GraphView;

  })(Backbone.View);

  celestrium.register(GraphView);

  KeyListener = (function() {
    KeyListener.uri = "KeyListener";

    function KeyListener() {
      var state, target, watch,
        _this = this;
      target = document.querySelector("body");
      _.extend(this, Backbone.Events);
      state = {};
      watch = [17, 65, 27, 46, 13, 16, 80, 187, 191];
      $(window).keydown(function(e) {
        var eventName, keysDown;
        if (e.target !== target || !_.contains(watch, e.which)) {
          return;
        }
        state[e.which] = e;
        keysDown = _.chain(state).map(function(event, which) {
          return which;
        }).sortBy(function(which) {
          return which;
        }).value();
        eventName = "down:" + (keysDown.join(':'));
        _this.trigger(eventName, e);
        if (e.isDefaultPrevented()) {
          return delete state[e.which];
        }
      });
      $(window).keyup(function(e) {
        if (e.target !== target) {
          return;
        }
        return delete state[e.which];
      });
    }

    return KeyListener;

  })();

  celestrium.register(KeyListener);

  PluginWrapper = (function(_super) {
    __extends(PluginWrapper, _super);

    function PluginWrapper() {
      _ref3 = PluginWrapper.__super__.constructor.apply(this, arguments);
      return _ref3;
    }

    PluginWrapper.prototype.className = 'plugin-wrapper';

    PluginWrapper.prototype.initialize = function(args) {
      this.plugin = args.plugin;
      this.pluginName = args.name;
      this.collapsed = false;
      return this.render();
    };

    PluginWrapper.prototype.events = {
      'click .plugin-controls .header': 'close'
    };

    PluginWrapper.prototype.close = function(e) {
      if (this.collapsed) {
        this.collapsed = false;
        return this.expand(this.$el.find('.plugin-content'));
      } else {
        this.collapsed = true;
        return this.collapse(this.$el.find('.plugin-content'));
      }
    };

    PluginWrapper.prototype.expand = function(el) {
      el.slideDown(300);
      return this.$el.removeClass('collapsed');
    };

    PluginWrapper.prototype.collapse = function(el) {
      el.slideUp(300);
      return this.$el.addClass('collapsed');
    };

    PluginWrapper.prototype.render = function() {
      this.controls = $("<div class=\"plugin-controls\">\n  <div class=\"header\">\n    <span>" + this.pluginName + "</span>\n    <div class=\"arrow\"></div>\n  </div>\n</div>");
      this.content = $("<div class=\"plugin-content\"></div>");
      this.content.append(this.plugin);
      this.$el.append(this.controls);
      return this.$el.append(this.content);
    };

    return PluginWrapper;

  })(Backbone.View);

  Layout = (function(_super) {
    __extends(Layout, _super);

    Layout.uri = "Layout";

    function Layout(options) {
      this.options = options;
      Layout.__super__.constructor.call(this, this.options);
      this.pluginWrappers = {};
      this.render();
    }

    Layout.prototype.render = function() {
      this.pluginContainer = $("<div class=\"plugin-container\"/>");
      this.$el.append(this.pluginContainer);
      return this;
    };

    Layout.prototype.renderPlugins = function() {
      var keys,
        _this = this;
      keys = _.keys(this.pluginWrappers).sort();
      return _.each(keys, function(key, i) {
        var pluginWrappersList;
        pluginWrappersList = _this.pluginWrappers[key];
        return _.each(pluginWrappersList, function(pluginWrapper) {
          return _this.pluginContainer.append(pluginWrapper.el);
        });
      });
    };

    Layout.prototype.addCenter = function(el) {
      return this.$el.append(el);
    };

    Layout.prototype.addPlugin = function(plugin, pluginOrder, name) {
      var pluginWrapper;
      if (name == null) {
        name = "Plugin";
      }
      if (pluginOrder == null) {
        pluginOrder = Number.MAX_VALUE;
      }
      pluginWrapper = new PluginWrapper({
        plugin: plugin,
        name: name,
        order: pluginOrder
      });
      if (_.has(this.pluginWrappers, pluginOrder)) {
        this.pluginWrappers[pluginOrder].push(pluginWrapper);
      } else {
        this.pluginWrappers[pluginOrder] = [pluginWrapper];
      }
      return this.renderPlugins();
    };

    return Layout;

  })(Backbone.View);

  celestrium.register(Layout);

  margin = {
    top: 10,
    right: 10,
    bottom: 40,
    left: 10
  };

  width = 200 - margin.left - margin.right;

  height = 200 - margin.top - margin.bottom;

  minStrength = 0;

  maxStrength = 1;

  LinkDistributionView = (function(_super) {
    __extends(LinkDistributionView, _super);

    LinkDistributionView.uri = "LinkDistribution";

    LinkDistributionView.needs = {
      graphModel: "GraphModel",
      graphView: "GraphView",
      sliders: "Sliders"
    };

    LinkDistributionView.prototype.className = "link-pdf";

    function LinkDistributionView(options) {
      this.options = options;
      this.windowModel = new Backbone.Model();
      this.windowModel.set("window", 10);
      this.listenTo(this.windowModel, "change:window", this.paint);
      LinkDistributionView.__super__.constructor.call(this, this.options);
      this.listenTo(this.graphModel, "change:links", this.paint);
      this.render();
    }

    LinkDistributionView.prototype.render = function() {
      /* one time setup of link strength pdf view*/

      var bottom, style, thresholdX, xAxis,
        _this = this;
      this.svg = d3.select(this.el).append("svg").classed("pdf", true).attr("width", width + margin.left + margin.right).attr("height", height + margin.top + margin.bottom).append("g").classed("workspace", true).attr("transform", "translate(" + margin.left + "," + margin.top + ")");
      this.svg.append("g").classed("pdfs", true);
      style = $("    <style>      .pdf { margin-left: auto; margin-right: auto; width: 200px; }      .pdf .axis text { font-size: 6pt; }      .pdf .axis path, .pdf .axis line {        fill: none; stroke: #000; shape-rendering: crispEdges;      }      .pdf .axis .label { font-size: 10pt; text-anchor: middle; }      .pdf path { fill: steelblue; }      .pdf .threshold-line {        stroke: #000; stroke-width: 2px; cursor: ew-resize;      }      .pdf.drag { cursor: ew-resize; }    </style>    ");
      $("html > head").append(style);
      this.x = d3.scale.linear().domain([minStrength, maxStrength]).range([0, width]);
      xAxis = d3.svg.axis().scale(this.x).orient("bottom");
      bottom = this.svg.append("g").attr("class", "x axis").attr("transform", "translate(0," + height + ")");
      bottom.append("g").call(xAxis);
      bottom.append("text").classed("label", true).attr("x", width / 2).attr("y", 35).text("Link Strength");
      this.paint();
      /* create draggable threshold line*/

      d3.select(this.el).select(".workspace").append("line").classed("threshold-line", true);
      thresholdX = this.x(this.graphView.getLinkFilter().get("threshold"));
      d3.select(this.el).select(".threshold-line").attr("x1", thresholdX).attr("x2", thresholdX).attr("y1", 0).attr("y2", height);
      this.$(".threshold-line").on("mousedown", function(e) {
        var $line, moveListener, originalX, pageX;
        $line = _this.$(".threshold-line");
        pageX = e.pageX;
        originalX = parseInt($line.attr("x1"));
        d3.select(".pdf").classed("drag", true);
        $(window).one("mouseup", function() {
          $(window).off("mousemove", moveListener);
          return d3.select(".pdf").classed("drag", false);
        });
        moveListener = function(e) {
          var dx, newX;
          _this.paint();
          dx = e.pageX - pageX;
          newX = Math.min(Math.max(0, originalX + dx), width);
          _this.graphView.getLinkFilter().set("threshold", _this.x.invert(newX));
          $line.attr("x1", newX);
          return $line.attr("x2", newX);
        };
        $(window).on("mousemove", moveListener);
        return e.preventDefault();
      });
      return this;
    };

    LinkDistributionView.prototype.paint = function() {
      /* function called everytime link strengths change*/

      var area, cdf, data, halfWindow, i, layout, maxY, path, pdf, sum, threshold, values, visiblePDF, y,
        _this = this;
      layout = d3.layout.histogram().range([minStrength, maxStrength]).frequency(false).bins(100);
      values = _.pluck(this.graphModel.getLinks(), "strength");
      sum = 0;
      cdf = _.chain(layout(values)).map(function(bin) {
        return {
          "x": bin.x,
          "y": sum += bin.y
        };
      }).value();
      halfWindow = Math.max(1, parseInt(this.windowModel.get("window") / 2));
      pdf = _.map(cdf, function(bin, i) {
        var q1, q2, slope, y1, y2;
        q1 = Math.max(0, i - halfWindow);
        q2 = Math.min(cdf.length - 1, i + halfWindow);
        y1 = cdf[q1]["y"];
        y2 = cdf[q2]["y"];
        slope = (y2 - y1) / (q2 - q1);
        return {
          "x": bin.x,
          "y": slope
        };
      });
      maxY = _.chain(pdf).map(function(bin) {
        return bin.y;
      }).max().value();
      this.y = d3.scale.linear().domain([0, maxY]).range([height, 0]);
      area = d3.svg.area().interpolate("monotone").x(function(d) {
        return _this.x(d.x);
      }).y0(this.y(0)).y1(function(d) {
        return _this.y(d.y);
      });
      /*
      
      define the x and y points to use for the visible links.
      they should be the points from the original pdf that are above
      the threshold
      
      to avoid granularity issues (jdhenke/celestrium#75),
      we also prepend this list of points with a point with x value exactly at
      the threshold and y value that is the average of it's neighbors' y values
      */

      threshold = this.graphView.getLinkFilter().get("threshold");
      visiblePDF = _.filter(pdf, function(bin) {
        return bin.x > threshold;
      });
      if (visiblePDF.length > 0) {
        i = pdf.length - visiblePDF.length;
        if (i > 0) {
          y = (pdf[i - 1].y + pdf[i].y) / 2.0;
        } else {
          y = pdf[i].y;
        }
        visiblePDF.unshift({
          "x": threshold,
          "y": y
        });
      }
      pdf.opacity = 0.25;
      visiblePDF.opacity = 1;
      data = [pdf];
      if (visiblePDF.length !== 0) {
        data.push(visiblePDF);
      }
      path = d3.select(this.el).select(".pdfs").selectAll(".pdf").data(data);
      path.enter().append("path").classed("pdf", true);
      path.exit().remove();
      return path.attr("d", area).style("opacity", function(d) {
        return d.opacity;
      });
    };

    return LinkDistributionView;

  })(Backbone.View);

  celestrium.register(LinkDistributionView);

  NodeDetailsView = (function(_super) {
    __extends(NodeDetailsView, _super);

    function NodeDetailsView(options) {
      this.options = options;
      NodeDetailsView.__super__.constructor.call(this);
    }

    NodeDetailsView.prototype.init = function(instances) {
      var _this = this;
      this.selection = instances["NodeSelection"];
      this.selection.on("change", this.update.bind(this));
      this.listenTo(instances["KeyListener"], "down:80", function() {
        return _this.$el.toggle();
      });
      instances["Layout"].addPlugin(this.el, this.options.pluginOrder, 'Node Details');
      return this.$el.toggle();
    };

    NodeDetailsView.prototype.update = function() {
      var $container, blacklist, selectedNodes;
      this.$el.empty();
      selectedNodes = this.selection.getSelectedNodes();
      $container = $("<div class=\"node-profile-helper\"/>").appendTo(this.$el);
      blacklist = ["index", "x", "y", "px", "py", "fixed", "selected", "weight"];
      return _.each(selectedNodes, function(node) {
        var $nodeDiv;
        $nodeDiv = $("<div class=\"node-profile\"/>").appendTo($container);
        $("<div class=\"node-profile-title\">" + node['text'] + "</div>").appendTo($nodeDiv);
        return _.each(node, function(value, property) {
          if (blacklist.indexOf(property) < 0) {
            return $("<div class=\"node-profile-property\">" + property + ":  " + value + "</div>").appendTo($nodeDiv);
          }
        });
      });
    };

    return NodeDetailsView;

  })(Backbone.View);

  NodeSelection = (function() {
    NodeSelection.uri = "NodeSelection";

    NodeSelection.needs = {
      keyListener: "KeyListener",
      graphView: "GraphView",
      graphModel: "GraphModel"
    };

    function NodeSelection() {
      var clickSemaphore,
        _this = this;
      _.extend(this, Backbone.Events);
      this.linkFilter = this.graphView.getLinkFilter();
      this.listenTo(this.keyListener, "down:17:65", this.selectAll);
      this.listenTo(this.keyListener, "down:27", this.deselectAll);
      this.listenTo(this.keyListener, "down:46", this.removeSelection);
      this.listenTo(this.keyListener, "down:13", this.removeSelectionCompliment);
      clickSemaphore = 0;
      this.graphView.on("enter:node", function(nodeEnterSelection) {
        return nodeEnterSelection.on("click", function(datum, index) {
          var savedClickSemaphore;
          if (d3.event.defaultPrevented) {
            return;
          }
          datum.fixed = true;
          clickSemaphore += 1;
          savedClickSemaphore = clickSemaphore;
          return setTimeout((function() {
            if (clickSemaphore === savedClickSemaphore) {
              _this.toggleSelection(datum);
              return datum.fixed = false;
            } else {
              clickSemaphore += 1;
              return datum.fixed = false;
            }
          }), 250);
        }).on("dblclick", function(datum, index) {
          return _this.selectConnectedComponent(datum);
        });
      });
    }

    NodeSelection.prototype.renderSelection = function() {
      var nodeSelection;
      nodeSelection = this.graphView.getNodeSelection();
      if (nodeSelection) {
        return nodeSelection.call(function(selection) {
          return selection.classed("selected", function(d) {
            return d.selected;
          });
        });
      }
    };

    NodeSelection.prototype.filterSelection = function(filter) {
      _.each(this.graphModel.getNodes(), function(node) {
        return node.selected = filter(node);
      });
      return this.renderSelection();
    };

    NodeSelection.prototype.selectAll = function() {
      this.filterSelection(function(n) {
        return true;
      });
      return this.trigger("change");
    };

    NodeSelection.prototype.deselectAll = function() {
      this.filterSelection(function(n) {
        return false;
      });
      return this.trigger("change");
    };

    NodeSelection.prototype.toggleSelection = function(node) {
      node.selected = !node.selected;
      this.trigger("change");
      return this.renderSelection();
    };

    NodeSelection.prototype.removeSelection = function() {
      return this.graphModel.filterNodes(function(node) {
        return !node.selected;
      });
    };

    NodeSelection.prototype.removeSelectionCompliment = function() {
      return this.graphModel.filterNodes(function(node) {
        return node.selected;
      });
    };

    NodeSelection.prototype.getSelectedNodes = function() {
      return _.filter(this.graphModel.getNodes(), function(node) {
        return node.selected;
      });
    };

    NodeSelection.prototype.selectBoundedNodes = function(dim) {
      var intersect, selectRect;
      selectRect = {
        left: dim.x,
        right: dim.x + dim.width,
        top: dim.y,
        bottom: dim.y + dim.height
      };
      intersect = function(rect1, rect2) {
        return !(rect1.right < rect2.left || rect1.bottom < rect2.top || rect1.left > rect2.right || rect1.top > rect2.bottom);
      };
      this.graphView.getNodeSelection().each(function(datum, i) {
        var bcr;
        bcr = this.getBoundingClientRect();
        return datum.selected = intersect(selectRect, bcr);
      });
      this.trigger('change');
      return this.renderSelection();
    };

    NodeSelection.prototype.selectConnectedComponent = function(node) {
      var allTrue, graph, lookup, newSelected, seen, visit;
      visit = function(text) {
        if (!_.has(seen, text)) {
          seen[text] = 1;
          return _.each(graph[text], function(ignore, neighborText) {
            return visit(neighborText);
          });
        }
      };
      graph = {};
      lookup = {};
      _.each(this.graphModel.getNodes(), function(node) {
        graph[node.text] = {};
        return lookup[node.text] = node;
      });
      _.each(this.linkFilter.filter(this.graphModel.getLinks()), function(link) {
        graph[link.source.text][link.target.text] = 1;
        return graph[link.target.text][link.source.text] = 1;
      });
      seen = {};
      visit(node.text);
      allTrue = true;
      _.each(seen, function(ignore, text) {
        return allTrue = allTrue && lookup[text].selected;
      });
      newSelected = !allTrue;
      _.each(seen, function(ignore, text) {
        return lookup[text].selected = newSelected;
      });
      this.trigger("change");
      return this.renderSelection();
    };

    return NodeSelection;

  })();

  celestrium.register(NodeSelection);

  SelectionLayer = (function() {
    SelectionLayer.uri = "SelectionLayer";

    SelectionLayer.needs = {
      graphView: "GraphView",
      nodeSelection: "NodeSelection"
    };

    function SelectionLayer() {
      this._clearRect = __bind(this._clearRect, this);
      this._drawRect = __bind(this._drawRect, this);
      this.renderRect = __bind(this.renderRect, this);
      this.determineSelection = __bind(this.determineSelection, this);
      this._registerEvents = __bind(this._registerEvents, this);
      this._setStartPoint = __bind(this._setStartPoint, this);
      this._intializeDragVariables = __bind(this._intializeDragVariables, this);
      this._sizeCanvas = __bind(this._sizeCanvas, this);
      this.render = __bind(this.render, this);
      this.$parent = this.graphView.$el;
      _.extend(this, Backbone.Events);
      this._intializeDragVariables();
      this.render();
    }

    SelectionLayer.prototype.render = function() {
      this.canvas = $('<canvas/>').addClass('selectionLayer').css('position', 'absolute').css('top', 0).css('left', 0).css('pointer-events', 'none')[0];
      this._sizeCanvas();
      this.$parent.append(this.canvas);
      return this._registerEvents();
    };

    SelectionLayer.prototype._sizeCanvas = function() {
      var ctx;
      ctx = this.canvas.getContext('2d');
      ctx.canvas.width = $(window).width();
      return ctx.canvas.height = $(window).height();
    };

    SelectionLayer.prototype._intializeDragVariables = function() {
      this.dragging = false;
      this.startPoint = {
        x: 0,
        y: 0
      };
      this.prevPoint = {
        x: 0,
        y: 0
      };
      return this.currentPoint = {
        x: 0,
        y: 0
      };
    };

    SelectionLayer.prototype._setStartPoint = function(coord) {
      this.startPoint.x = coord.x;
      return this.startPoint.y = coord.y;
    };

    SelectionLayer.prototype._registerEvents = function() {
      var _this = this;
      $(window).resize(function(e) {
        return _this._sizeCanvas();
      });
      this.$parent.mousedown(function(e) {
        if (e.shiftKey) {
          _this.dragging = true;
          _.extend(_this.startPoint, {
            x: e.clientX,
            y: e.clientY
          });
          _.extend(_this.currentPoint, {
            x: e.clientX,
            y: e.clientY
          });
          _this.determineSelection();
          return false;
        }
      });
      this.$parent.mousemove(function(e) {
        if (e.shiftKey) {
          if (_this.dragging) {
            _.extend(_this.prevPoint, _this.currentPoint);
            _.extend(_this.currentPoint, {
              x: e.clientX,
              y: e.clientY
            });
            _this.renderRect();
            _this.determineSelection();
            return false;
          }
        }
      });
      this.$parent.mouseup(function(e) {
        _this.dragging = false;
        _this._clearRect(_this.startPoint, _this.currentPoint);
        _.extend(_this.startPoint, {
          x: 0,
          y: 0
        });
        return _.extend(_this.currentPoint, {
          x: 0,
          y: 0
        });
      });
      return $(window).keyup(function(e) {
        if (e.keyCode === 16) {
          _this.dragging = false;
          _this._clearRect(_this.startPoint, _this.prevPoint);
          return _this._clearRect(_this.startPoint, _this.currentPoint);
        }
      });
    };

    SelectionLayer.prototype.determineSelection = function() {
      var rectDim;
      rectDim = this.rectDim(this.startPoint, this.currentPoint);
      return this.nodeSelection.selectBoundedNodes(rectDim);
    };

    SelectionLayer.prototype.renderRect = function() {
      this._clearRect(this.startPoint, this.prevPoint);
      return this._drawRect(this.startPoint, this.currentPoint);
    };

    SelectionLayer.prototype.rectDim = function(startPoint, endPoint) {
      var dim;
      dim = {};
      dim.x = startPoint.x < endPoint.x ? startPoint.x : endPoint.x;
      dim.y = startPoint.y < endPoint.y ? startPoint.y : endPoint.y;
      dim.width = Math.abs(startPoint.x - endPoint.x);
      dim.height = Math.abs(startPoint.y - endPoint.y);
      return dim;
    };

    SelectionLayer.prototype._drawRect = function(startPoint, endPoint) {
      var ctx, dim;
      dim = this.rectDim(startPoint, endPoint);
      ctx = this.canvas.getContext('2d');
      ctx.fillStyle = 'rgba(255, 255, 0, 0.2)';
      return ctx.fillRect(dim.x, dim.y, dim.width, dim.height);
    };

    SelectionLayer.prototype._clearRect = function(startPoint, endPoint) {
      var ctx, dim;
      dim = this.rectDim(startPoint, endPoint);
      ctx = this.canvas.getContext('2d');
      return ctx.clearRect(dim.x, dim.y, dim.width, dim.height);
    };

    return SelectionLayer;

  })();

  celestrium.register(SelectionLayer);

  /*
  
  provides an interface to add sliders to the ui
  
  `addSlider(label, initialValue, onChange)` does the following
    - shows the text `label` next to the slider
    - starts it at `initialValue`
    - calls `onChange` when the value changes
      with the new value as the argument
  
  sliders have range [0, 100]
  */


  SlidersView = (function(_super) {
    __extends(SlidersView, _super);

    SlidersView.uri = "Sliders";

    function SlidersView(options) {
      this.options = options;
      SlidersView.__super__.constructor.call(this, this.options);
      this.render();
    }

    SlidersView.prototype.render = function() {
      var $container;
      $container = $("<div class=\"sliders-container\">\n  <table border=\"0\">\n  </table>\n</div>");
      $container.appendTo(this.$el);
      return this;
    };

    SlidersView.prototype.addSlider = function(label, initialValue, onChange) {
      var $row;
      $row = $("<tr>\n  <td class=\"slider-label\">" + label + ": </td>\n  <td><input type=\"range\" min=\"0\" max=\"100\"></td>\n</tr>");
      $row.find("input").val(initialValue).on("input", function() {
        var val;
        val = $(this).val();
        onChange(val);
        return $(this).blur();
      });
      return this.$("table").append($row);
    };

    return SlidersView;

  })(Backbone.View);

  celestrium.register(SlidersView);

  StaticProvider = (function(_super) {
    __extends(StaticProvider, _super);

    StaticProvider.uri = "StaticProvider";

    function StaticProvider(nodes, links) {
      var _this = this;
      StaticProvider.__super__.constructor.call(this);
      _.each(nodes, function(node) {
        return _this.graphModel.putNode(node);
      });
      _.each(links, function(link) {
        return _this.graphModel.putLink(link);
      });
    }

    StaticProvider.prototype.searchAround = function(callback) {};

    return StaticProvider;

  })(celestrium.defs["DataProvider"]);

  StaticProvider = (function(_super) {
    __extends(StaticProvider, _super);

    StaticProvider.uri = "StaticProvider";

    function StaticProvider(data) {
      var _ref4,
        _this = this;
      StaticProvider.__super__.constructor.call(this);
      _ref4 = [data.nodes, data.links], this.nodes = _ref4[0], this.links = _ref4[1];
      this.graph = {};
      this.linkDict = {};
      _.each(this.links, function(link) {
        var source, target, _base, _base1, _name, _name1, _ref5;
        _ref5 = [link.source, link.target], source = _ref5[0], target = _ref5[1];
        if ((_base = _this.graph)[_name = source.text] == null) {
          _base[_name] = [];
        }
        _this.graph[source.text].push(link);
        if ((_base1 = _this.graph)[_name1 = target.text] == null) {
          _base1[_name1] = [];
        }
        _this.graph[target.text].push(link);
        return _this.linkDict[_this.graphModel.linkHash(link)] = link;
      });
      _.each(this.nodes, function(node) {
        return _this.graphModel.putNode(node);
      });
      _.each(this.links, function(link) {
        return _this.graphModel.putLink(link);
      });
    }

    StaticProvider.prototype.searchAround = function(callback) {
      var getLink, links, newNodes, selectedNodes,
        _this = this;
      selectedNodes = this.nodeSelection.getSelectedNodes();
      newNodes = _.chain(selectedNodes).map(function(node) {
        var links;
        links = _this.graph[node.text];
        if (links == null) {
          links = [];
        }
        return _.map(links, function(link) {
          if (link.source === node) {
            return link.target;
          } else {
            return link.source;
          }
        });
      }).flatten().uniq().filter(function(node) {
        return !_this.graphModel.hasNode(node);
      }).value();
      getLink = function(node1, node2) {
        return _this.linkDict[_this.graphModel.linkHash({
          source: node1,
          target: node2
        })];
      };
      links = [];
      _.each(newNodes, function(newNode) {
        return _.each(_this.graphModel.getNodes(), function(oldNode) {
          var link1, link2;
          link1 = getLink(newNode, oldNode);
          link2 = getLink(oldNode, newNode);
          if (link1 != null) {
            links.push(link1);
          }
          if (link2 != null) {
            return links.push(link2);
          }
        });
      });
      _.each(newNodes, function(newNode1, i) {
        return _.each(newNodes, function(newNode2, j) {
          var link;
          if (i === j) {
            return;
          }
          link = getLink(newNode1, newNode2);
          if (link != null) {
            return links.push(link);
          }
        });
      });
      return callback(newNodes, links);
    };

    return StaticProvider;

  })(celestrium.defs["DataProvider"]);

  celestrium.register(StaticProvider);

  StatsView = (function(_super) {
    __extends(StatsView, _super);

    StatsView.uri = "Stats";

    StatsView.needs = {
      graphModel: "GraphModel"
    };

    function StatsView(options) {
      this.options = options;
      StatsView.__super__.constructor.call(this, this.options);
      this.render();
      this.listenTo(this.graphModel, "change", this.update);
    }

    StatsView.prototype.render = function() {
      var container;
      container = $("<div />").addClass("graph-stats-container").appendTo(this.$el);
      this.$table = $("<table border=\"0\"/>").appendTo(container);
      this.updateNodes = this.addStat("Nodes");
      this.updateLinks = this.addStat("Links");
      this.update();
      return this;
    };

    StatsView.prototype.update = function() {
      this.updateNodes(this.graphModel.getNodes().length);
      return this.updateLinks(this.graphModel.getLinks().length);
    };

    StatsView.prototype.addStat = function(label) {
      var $label, $row, $stat;
      $label = $("<td class=\"graph-stat-label\">" + label + ": </td>");
      $stat = $("<td class=\"graph-stat\"></td>)");
      $row = $("<tr />").append($label).append($stat);
      this.$table.append($row);
      return function(newVal) {
        return $stat.text(newVal);
      };
    };

    return StatsView;

  })(Backbone.View);

  celestrium.register(StatsView);

}).call(this);

/*
//@ sourceMappingURL=celestrium.js.map
*/