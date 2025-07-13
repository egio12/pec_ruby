# frozen_string_literal: true

require 'net/imap'
require 'mail'

module PecRuby
  class Client
    attr_reader :imap, :host, :username

    def initialize(host:, username:, password:, ssl: true)
      @host = host
      @username = username
      @password = password
      @ssl = ssl
      @imap = nil
    end

    def connect
      @imap = Net::IMAP.new(@host, ssl: @ssl)
      authenticate
      select_inbox
      self
    rescue Net::IMAP::Error => e
      raise ConnectionError, "Failed to connect to #{@host}: #{e.message}"
    end

    def disconnect
      return unless @imap

      begin
        @imap.logout if @imap && !@imap.disconnected?
      rescue => e
        # Ignore logout errors if connection is already closed
      end
      
      begin
        @imap.disconnect if @imap && !@imap.disconnected?
      rescue => e
        # Ignore disconnect errors if connection is already closed
      end
      
      @imap = nil
    end

    def connected?
      return false unless @imap
      !@imap.disconnected?
    end

    # Get all messages or a subset
    def messages(limit: nil, reverse: true)
      raise ConnectionError, "Not connected" unless connected?
      
      sequence_numbers = @imap.search(['ALL'])
      sequence_numbers = sequence_numbers.reverse if reverse
      sequence_numbers = sequence_numbers.first(limit) if limit
      
      fetch_messages(sequence_numbers)
    end

    # Get a specific message by UID
    def message(uid)
      raise ConnectionError, "Not connected" unless connected?
      
      fetch_data = @imap.uid_fetch(uid, ["UID", "ENVELOPE", "BODYSTRUCTURE"])
      return nil if fetch_data.nil? || fetch_data.empty?
      
      Message.new(self, fetch_data.first)
    end

    # Get messages with postacert.eml only
    def pec_messages(limit: nil, reverse: true)
      messages(limit: limit, reverse: reverse).select(&:has_postacert?)
    end

    # Internal method to fetch message body parts
    def fetch_body_part(uid, part_id)
      @imap.uid_fetch(uid, "BODY[#{part_id}]")[0].attr["BODY[#{part_id}]"]
    end

    private

    def authenticate
      @imap.authenticate("PLAIN", @username, @password)
    rescue Net::IMAP::Error => e
      raise AuthenticationError, "Authentication failed: #{e.message}"
    end

    def select_inbox
      @imap.select('INBOX')
    end

    def fetch_messages(sequence_numbers)
      return [] if sequence_numbers.empty?
      
      messages_data = @imap.fetch(sequence_numbers, ["UID", "ENVELOPE", "BODYSTRUCTURE"])
      messages_data.map { |msg_data| Message.new(self, msg_data) }
    end
  end
end