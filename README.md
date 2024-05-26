# Lapis
## A GNU/Linux Shell built in the Ruby programming language.
It's designed to be feature-complete and with a syntax compatible with the default ruby one.

## What's implemented
- [ ] Custom line editor
  * [x] Basic input navigation: backspace, arrow keys, enter
  * [x] Basic file completions using `ls`
  * [ ] History navigation
- [x] Custom syntax parser
  * [x] Program calls
  * [x] Ruby languge interoperability (mixing programs and functions, etc)
  * [x] Blocks as arguments to programs

- [ ] Other/Wishlist
  * [x] A config file to store the prompt configuration
  * [ ] A way to extend or customize the line editor
  
## An example config file
Put this in  `/home/youruser/.config/lapis/config.rb` to get started.
```ruby
# this function is mandatory. you can optionally use any functions to aid in
# building this one, which MUST be present.
# this is just a prompt example, you can build it however  you want.
def prompt ()
  user = ENV['USER']
  host = ENV['HOSTNAME']
  "#{user}@#{host} => "
end

prompt
```
  
# Warning
⚠️ **Some components of the parser might break unpredictably. Use at your own risk for now.**
