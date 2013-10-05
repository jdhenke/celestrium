define(["underscore", "backbone"], function(_, Backbone) {

  var Model = Backbone.Model.extend({

    initialize: function() {
      this.set("nodes", []);
      this.set("links", []);
    },

    getNodes: function() {
      return this.get("nodes");
    },

    getLinks: function() {
      return this.get("links");
    },

    putNode: function(node) {
      this.trigger("add:node", node);
      this.pushDatum("nodes", node);
    },

    putLink: function(link) {
      this.pushDatum("links", link);
    },

    pushDatum: function(attr, datum) {
      var data = this.get(attr);
      data.push(datum);
      this.set(attr, data);
      // QA: this is not already fired because of the rep-exposure of get.
      //     `data` is the actual underlying object so even though set 
      //     performs a deep search to detect changes, it will not detect any
      //     because it's literally comparing the same object
      // Note: at least we know this will never be a redundant trigger
      this.trigger("change:" + attr);
      this.trigger("change");
    },

    /* also removes links incident to any node which is removed */
    filterNodes: function(filter) {
      var removed = [];
      function wrappedFilter(d) {
        var decision = filter(d);
        if (!decision) {
          removed.push(d);
        }
        return decision;
      }
      this.filterAttribute("nodes", wrappedFilter);
      function nodeWasRemoved(node) {
        return _.some(removed, function(n) {
          return _.isEqual(n, node);
        });
      }
      function linkFilter(link) {
        return !nodeWasRemoved(link.source) && !nodeWasRemoved(link.target);
      }
      this.filterLinks(linkFilter);
    },

    filterLinks: function(filter) {
      this.filterAttribute("links", filter);
    },

    filterAttribute: function(attr, filter) {
      var filteredData = _.filter(this.get(attr), filter);
      this.set(attr, filteredData);
    },

  });

  return Model
});
