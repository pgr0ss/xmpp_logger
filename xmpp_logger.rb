require 'date'
require 'fileutils'
require 'json'
require 'time'
require 'yaml'

require 'rubygems'
require 'xmpp4r'
require 'xmpp4r/muc/helper/mucclient'

class XMPPLogger
  def initialize(config)
    @host = config['host']
    @username = config['username']
    @password = config['password']
    @log_dir = config['log_directory']
    @rooms = config['rooms']
  end

  def start
    connect

    @client.add_message_callback do |message|
      direct_message_received(message)
    end

    join_chat_rooms

    Thread.stop
    @client.close
  end

  def connect
    jabber_id = "#{@username}@#{@host}"
    @client = Jabber::Client.new(jabber_id)

    @client.connect
    @client.auth(@password)
    @client.send(Jabber::Presence.new.set_type(:available))
  end

  def join_chat_rooms
    @rooms.each do |room|
      Thread.new do
        muc_client = Jabber::MUC::MUCClient.new(@client)
        muc_client.add_message_callback do |message|
          group_message_received(message)
        end
        muc_client.join("#{room}@conference.braintree.xmpp.slack.com/pg")
      end
    end
  end

  def direct_message_received(message)
    begin
      puts message
      log_chat(message)
    rescue => e
      puts e.message, e.backtrace
    end
  end

  def group_message_received(message)
    begin
      puts
      puts message
      puts
      log_group_chat(message)
    rescue => e
      puts e.message, e.backtrace
    end
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
    File.join(@log_dir, from_address, filename)
  end

  def group_chat_log_path(message)
    room_name = message.from.to_s.split('/').first
    filename = "#{Date.today.to_s}.txt"
    File.join(@log_dir, room_name, filename)
  end
end

def main
  usage if ARGV.count != 1

  config = YAML.load_file(ARGV.first)
  XMPPLogger.new(config).start
end

def usage
  puts "Usage: ruby xmpp_logger.rb </path/to/config.yml>"
  exit 1
end

main if __FILE__ == $0
