xmpp_logger
===========

Your chat provider stores chat logs. Shouldn't you have a copy?

`xmpp_logger` is a program which connects to an XMPP/Jabber server and logs all direct and group chats to files.

## Installation

```
git clone https://github.com/pgr0ss/xmpp_logger.git
cd xmpp_logger
gem install bundler
bundle install
```

## Usage

```
cp config.yml.example config.yml
```

Update config.yml with your XMPP/Jabber settings

```
ruby xmpp_logger.rb config.yml
```
