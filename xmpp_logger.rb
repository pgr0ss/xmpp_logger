require 'date'
require 'fileutils'
require 'json'
require 'time'
require 'yaml'

require 'rubygems'
require 'xmpp4r'
require 'xmpp4r/muc/helper/simplemucclient'

LOG_DIR = '/tmp/logs'

def main
  usage if ARGV.count != 1

  config = YAML.load_file(ARGV.first)

  client = Jabber::Client.new(config['jabber_id'])

  client.connect
  client.auth(config['password'])
  client.send(Jabber::Presence.new.set_type(:available))

  client.add_message_callback do |m|
    begin
      puts m
      log_chat(m)
    rescue => e
      puts e
    end
  end

  %w(temp devnull developer blue dataeng).each do |room|
    Thread.new do
      muc_client = Jabber::MUC::MUCClient.new(client)
      muc_client.add_message_callback do |message|
        begin
          puts
          puts message
          puts
          log_group_chat(message)
        rescue => e
          puts e
        end
      end
      muc_client.join("#{room}@conference.braintree.xmpp.slack.com/pg")
    end
  end

  Thread.stop
  client.close
end

def usage
  puts "ruby xmpp_logger.rb </path/to/config.yml>"
  exit 1
end

def log_chat(message)
  attributes = {
    time: Time.now.utc.iso8601,
    from: message.from.to_s.split('/').first,
    to: message.to.to_s,
    message: message.body,
  }

  path = chat_log_path(attributes)

  FileUtils.mkdir_p(File.dirname(path))

  File.open(path, 'a') do |file|
    file.puts(attributes.to_json)
  end
end

def log_group_chat(message)
  attributes = {
    time: Time.now.utc.iso8601,
    from: message.from.resource,
  }

  if message.subject
    attributes.merge!(subject: message.subject)
  else
    attributes.merge!(message: message.body)
  end

  path = group_chat_log_path(message)

  FileUtils.mkdir_p(File.dirname(path))

  File.open(path, 'a') do |file|
    file.puts(attributes.to_json)
  end
end

def chat_log_path(attributes)
  from_address = attributes[:from]
  filename = "#{Date.today.to_s}.txt"
  File.join(LOG_DIR, from_address, filename)
end

def group_chat_log_path(message)
  room_name = message.from.to_s.split('/').first
  filename = "#{Date.today.to_s}.txt"
  File.join(LOG_DIR, room_name, filename)
end

main if __FILE__ == $0
