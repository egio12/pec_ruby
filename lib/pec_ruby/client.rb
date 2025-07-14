# frozen_string_literal: true

require 'net/imap'
require 'mail'

module PecRuby
  class Client
    attr_reader :imap, :host, :username, :current_folder

    def initialize(host:, username:, password:, ssl: true)
      @host = host
      @username = username
      @password = password
      @ssl = ssl
      @imap = nil
      @current_folder = nil
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
      rescue StandardError => e
        # Ignore logout errors if connection is already closed
      end

      begin
        @imap.disconnect if @imap && !@imap.disconnected?
      rescue StandardError => e
        # Ignore disconnect errors if connection is already closed
      end

      @imap = nil
    end

    def connected?
      return false unless @imap

      !@imap.disconnected?
    end

    # Get the list of available folders in the mailbox
    def available_folders
      raise ConnectionError, 'Not connected' unless connected?

      @imap.list('', '*').map(&:name)
    end

    def select_folder(folder)
      raise ConnectionError, 'Not connected' unless connected?

      # Check if the folder exists
      raise FolderError, "Folder '#{folder}' does not exist" unless available_folders.include?(folder)

      @imap.select(folder)
      @current_folder = folder
    rescue Net::IMAP::Error => e
      raise FolderError, "Failed to select folder '#{folder}': #{e.message}"
    end

    def select_inbox
      select_folder('INBOX')
      @current_folder = 'INBOX'
    rescue FolderError => e
      raise FolderError, "Failed to select INBOX: #{e.message}"
    end

    # Get all messages or a subset
    def messages(limit: nil, reverse: true)
      raise ConnectionError, 'Not connected' unless connected?

      # Use search to get available sequence numbers (safer approach)
      begin
        sequence_numbers = @imap.search(['ALL'])
      rescue Net::IMAP::Error => e
        raise ConnectionError, "Failed to search messages: #{e.message}"
      end
      
      return [] if sequence_numbers.empty?

      # Sort and limit the sequence numbers
      if reverse
        sequence_numbers = sequence_numbers.sort.reverse
      else
        sequence_numbers = sequence_numbers.sort
      end
      
      # Apply limit if specified
      sequence_numbers = sequence_numbers.first(limit) if limit

      fetch_messages_by_sequence(sequence_numbers)
    end

    # Get a specific message by UID
    def message(uid)
      raise ConnectionError, 'Not connected' unless connected?

      fetch_data = @imap.uid_fetch(uid, %w[UID ENVELOPE BODYSTRUCTURE])
      return nil if fetch_data.nil? || fetch_data.empty?

      Message.new(self, fetch_data.first)
    end


    # Internal method to fetch messages by sequence number
    def fetch_messages_by_sequence(sequence_numbers)
      return [] if sequence_numbers.empty?

      # Fetch messages in batches to avoid memory issues
      batch_size = 50
      all_messages = []

      sequence_numbers.each_slice(batch_size) do |seq_batch|
        fetch_data = @imap.fetch(seq_batch, %w[UID ENVELOPE BODYSTRUCTURE])
        next if fetch_data.nil?

        batch_messages = fetch_data.map { |data| Message.new(self, data) }
        all_messages.concat(batch_messages)
      end

      all_messages
    end

    # Internal method to fetch message body parts
    def fetch_body_part(uid, part_id)
      @imap.uid_fetch(uid, "BODY[#{part_id}]")[0].attr["BODY[#{part_id}]"]
    end

    private

    def authenticate
      @imap.authenticate('PLAIN', @username, @password)
    rescue Net::IMAP::Error => e
      raise AuthenticationError, "Authentication failed: #{e.message}"
    end

  end
end
