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
    listen_to_direct_messages
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

  def listen_to_direct_messages
    @client.add_message_callback do |message|
      message_received(message)
    end
  end

  def join_chat_rooms
    @rooms.each do |room|
      Thread.new do
        muc_client = Jabber::MUC::MUCClient.new(@client)
        muc_client.add_message_callback do |message|
          message_received(message)
        end
        muc_client.join("#{room}@conference.#{@host}/#{@username}")
      end
    end
  end

  def message_received(message)
    puts message
    if message.type == :chat
      log_chat(message)
    elsif message.type == :groupchat
      log_group_chat(message)
    else
      puts "Unknown message type: #{message.type}"
    end
  rescue => e
    puts e.message, e.backtrace
  end

  def log_chat(message)
    attributes = {
      time: Time.now.utc.iso8601,
      from: message.from.to_s,
      to: message.to.to_s,
      message: message.body,
    }

    write_log_entry(attributes, log_path(message))
  end

  def log_group_chat(message)
    return if message.subject.nil? && message.body.nil?

    attributes = {
      time: Time.now.utc.iso8601,
      from: message.from.resource,
    }

    attributes.merge!(subject: message.subject) if message.subject
    attributes.merge!(message: message.body) if message.body

    write_log_entry(attributes, log_path(message))
  end

  def log_path(message)
    File.join(@log_dir, message.from.domain, message.from.node, "#{Date.today.to_s}.txt")
  end

  def write_log_entry(attributes, path)
    FileUtils.mkdir_p(File.dirname(path))

    File.open(path, 'a') do |file|
      file.puts(attributes.to_json)
    end
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
