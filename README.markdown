# Summary

$.Vivified is meant to be used with CoffeeScript and jQuery.

It makes it easy to use CoffeeScript classes to add functionality to DOM elements while subclassing jQuery.

# Intro

A Vivified object:
- has methods from jQuery
- has methods form your class
- corresponds uniquely with a DOM element

Let's start with an example:

    class MyList extends jQuery.Vivified
      cycle: ->
        @append(@find('li:first').detach())

Note that we are extending jQuery, so all methods of jQuery are
accessible in our methods (here `@append` & `@find`).

Now we can do:

    new MyList('ul#foo').cycle() # => cycles the li

This did *not* add any method to jQuery itself, so:

    $('ul#foo').cycle()  # => Object [object Object] has no method 'cycle'

## Constructor

A DOM object can be vivified once. This is quite helpful to retain state:

* you can use `@key` instead of `@data('key')` (and thus `@key ||= 42` instead of `@data('key') || @data('key') = 42`, etc...)
* no risk of collision if another piece of code uses `.data('key')`

It also means that the constructor will be executed only once, so it's a great time to bind events, etc...

The first argument has to be either a jQuery selector or a jQuery object. Other arguments are your own.

If you define a `constructor` methods, you must remember to call `super` and you probably want to do that first, since you won't be able to use any of jQuery's functionality before that.

It's easier to define an `initialize` method, though. The default constructor will call the `initialize` method and pass on all the arguments except the first one, so typically this is the best way to define a constructor. No need to call `super` in that case too.

    class MyList extends jQuery.Vivified
      initialize: (@howMany = 1) ->
        @on 'click', =>
          @cycle()
          @howMany += 1  # Cycle more each time we click

      cycle: ->
        for i in [1..@howMany]
          @append(@find('li:first').detach())

*Caution*: Don't mixup `initialize` (our custom construction method) with `init` which is an existing jQuery method.

*Note*: If you try to vivify the same DOM element twice with the same class, a error is added on the console.

## Accessing vivified objects

You can call the global jQuery method `vivify` to access a vivified object. This will vivify it if it wasn't already:

    $('ul#foo').vivify(MyList)  # => Assuming this is the first time, the UL is vivified, constructor called
    $('ul#foo').vivify(MyList)  # => returns exact same object as above, constructor not called again.

The same DOM object can be vivified by more than one class. The methods of each class will behave completely independently.

    $('ul#foo').vivify(MyList).howMany # => 1
    $('ul#foo').vivify(SomeBehavior)  # => The UL is vivified with SomeBehavior, constructor of SomeBehavior called
    $('ul#foo').vivify(SomeBehavior).howMany # => undefined, since instance variables or methods are not shared

The `vivified` global jQuery function will return the vivified object for an element. If it was vivified with more than one class, an error is shown in the console. This method is mostly meant for debugging, as it is shorter and doesn't require access to the class (which might be a local variable).

    $('ul#foo').vivify(MyList) # => vivified object
    $('ul#foo').vivified() # => returns same object as above

## @refresh

The method `refresh` is meant to refresh an object after it has been modified. It is meant to be callable at any time without causing a problem. If your class specializes `refresh`, finish by calling `super`.

The method 'refresh' is automatically bound to the custom event 'refresh' and is automatically called at the end of the constructor, after `initialize` is called.

## Vivified.vivify

Although I didn't write it in the examples above, each Subclass of `Vivified` must call `Vivified.vivify()` (technical reason [at the end](#the-constructor-hack)).

You may pass `{selector: class}` to `vivify()` to automatically vivify children matching the selector:

    class MyItem extends jQuery.Vivified
      @vivify()  # Must be called to setup the class
      # ...

    class MyList extends jQuery.Vivified
      @vivify 'li.special': MyItem
      # ...

    new MyList('ul#foo')  # => All the 'li.special' inside 'ul#foo' will be vivified

The children are vivified by `refresh`, so if you add a child, simply trigger a `refresh` event or call `refresh()` to vivify the new children.

# $.Extension

`Vivified` extends a basic class called `$.Extension`. That class doesn't do much expect make it possible to extend jQuery.

It's actually not trivial to extend jQuery for two reasons.

## Calling jQuery

The first difficulty is that `jQuery(...)` sometimes acts like a constructor by setting `this.foo = ...`, sometimes as a function, by returning an altogether different object.

This is reasonably easy to deal with in the constructor.

## The `constructor` hack

Next, jQuery uses `new this.constructor` to create new jQuery object. I don't know why, but that's not what I want. Indeed, `new MyList('ul').find('li')` should return a normal jQuery object, not an instance of `MyList`. So I must do the unthinkable and change `MyList.prototype.constructor` to point to jQuery instead of `MyList`.

If we ever need the actual `constructor`, `$.Extension` sets up `__class__` which we can use instead.

    $list = new MyList('ul')
    $list.constructor # => jQuery
    $list.__class__   # => MyList

The last part of the hack is to restore things for CoffeeScript. For the default constructor and `super`, CS relies on `__super__.constructor`. Since we just modified that for jQuery, that would cause problems.

So what `$.Extension` does is replace `__super__` with an intermediary object that is equivalent to the actual super class, except that its `constructor` points to the right class. Technically, instead of `MyList.__super__` being equal to `$.Vivified.prototype` (or some other super class), we have `MyList.__super__` equal to an object whose prototype is `$.Vivified.prototype` and with a single attribute `constructor` equal to `$.Vivified.prototype`. CS can now rely on `__super__.whatever` being correct.

Confused? Hopefully these diagrams can help: here's what things would look like [without the hack](support/without_hack.jpg), and what they look like [with the hack](support/with_hack.jpg).
