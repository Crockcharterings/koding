bongo = require 'bongo'

{secure} = bongo

JMachine = require './computeproviders/machine'


module.exports = class SharedMachine extends bongo.Base

  @share()


  @add = secure (client, uid, target, callback) ->

    asUser  = yes
    options = {target, asUser}
    setUsers client, uid, options, callback


  setUsers = (client, uid, options, callback) ->

    options.permanent = yes
    JMachine.shareByUId client, uid, options, callback
