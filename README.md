## Building whisper

1. Install CocoaPods. Using [bundler](http://bundler.io/) is recommended due to that CocoaPods has a habit of making breaking changes with new versions. Install bundler, then run `bundle install`.
2. Install mogenerator with `brew install mogenerator`. You can also just [download the binary](http://rentzsch.github.io/mogenerator/); if you do put it in `/usr/local/bin`.
3. Install the rest of the dependencies with `bundle exec pod install`.
4. Open whisper.xcworkspace, select the whisper - tigase.im target, and hit build.

## Running a local XMPP server

A configuration file for [Prosody](http://prosody.im/) is provided, so simply install Prosody 0.9 (note: 0.8 is not supported) then run `prosody --config prosody.cfg.lua`
