# jQuery.vivified v1.2.0
# https://github.com/marcandre/vivified

# Simple base class to extend jQuery
#
class jQuery.Extension extends jQuery
  rootjQuery = $(document)
  constructor: (selector, context, root = rootjQuery) ->
    r = @init(selector, context, root)
    if r != this # jQuery sometimes bypasses normal object creation
      for key, val of r
        @[key] = val

  __class__: @
  @vivify: -> # See https://github.com/marcandre/vivified#the-constructor-hack
    @::__class__ = @
    ctor = -> @constructor = @__class__; @
    ctor.prototype = @__super__
    @__super__ = new ctor()
    @::constructor = jQuery
    @

  @ancestors: []

# Makes it easy to turn DOM elements into objects with your own methods,
# as well as those of jQuery.
#
# See doc at https://github.com/marcandre/vivified
#
class jQuery.Vivified extends jQuery.Extension
  constructor: (selector, args...) ->
    super(selector)
    if @length isnt 1
      console.warn("Expected selector #{selector} to match exactly 1 element, matched #{@length}", @)
    unless reg = @.data('vivified')
      @.data('vivified', reg = {})
    if @__class__ is jQuery.Vivified # We can catch direct descendants not calling vivify:
      console.error("Class must call @vivify")
    if reg[@__class__]
      console.error("Constructor called on already vivified DOM object", this)
    reg[klass] = this for klass in @__class__.ancestors

    @on 'refresh', => @refresh()
    @initialize?(args...)
    @refresh()

  refresh: ->
    for selector, klass of @__class__.autoVivified || {}
      @find(selector).vivify(klass)
    @

  @vivify: (autoVivify) ->
    $.extend(@autoVivified ||= {}, autoVivify) if autoVivify
    @ancestors = [@, @ancestors...] unless @ancestors[0] is @
    super()

  @vivify()

$.fn.vivify = (klass, initArgs...) ->
  [first, rest...] = for obj in @get()
    ((reg = $(obj).data('vivified')) and reg[klass]) or new klass(obj, initArgs...)
  first ||= $()
  first = first.add(other) for other in rest
  first

$.fn.vivified = ->
  [first, rest...] = for obj in @get()
    values = (value for key, value of $(obj).data('vivified'))
    if values.length == 0
      console.error "DOM object is not vivified:", obj
      $(obj)
    else
      if (u=$.unique(values)).length > 1
        console.error "DOM object is vivified with more than one class:", obj, u
      values[0] # Topmost class is stored first
  first ||= $()
  first = first.add(other) for other in rest
  first
