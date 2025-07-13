# frozen_string_literal: true

require 'mail'

module PecRuby
  class Message
    attr_reader :uid, :envelope, :bodystructure, :client

    def initialize(client, fetch_data)
      @client = client
      @uid = fetch_data.attr["UID"]
      @envelope = fetch_data.attr["ENVELOPE"]
      @bodystructure = fetch_data.attr["BODYSTRUCTURE"]
      @postacert_mail = nil
      @postacert_extracted = false
    end

    # Basic envelope information
    def subject
      return nil unless @envelope.subject
      
      decoded = Mail::Encodings.value_decode(@envelope.subject)
      decoded.gsub!("POSTA CERTIFICATA:", "") if decoded.start_with?("POSTA CERTIFICATA:")
      decoded.strip
    end

    def from
      return nil unless @envelope.from&.first
      
      from_addr = @envelope.from.first
      extract_real_sender(from_addr)
    end

    def to
      return [] unless @envelope.to
      
      @envelope.to.map { |addr| "#{addr.mailbox}@#{addr.host}" }
    end

    def date
      @envelope.date ? Time.parse(@envelope.date.to_s) : nil
    end

    # Check if message contains postacert.eml
    def has_postacert?
      !find_postacert_part_ids.empty?
    end

    # Extract and return the original message from postacert.eml
    def postacert_message
      return @postacert_mail if @postacert_extracted
      
      @postacert_extracted = true
      part_ids = find_postacert_part_ids
      
      if part_ids.empty?
        @postacert_mail = nil
        return nil
      end

      begin
        part_id = part_ids.first
        raw_data = @client.fetch_body_part(@uid, part_id)
        @postacert_mail = Mail.read_from_string(raw_data)
      rescue => e
        raise Error, "Failed to extract postacert.eml: #{e.message}"
      end

      @postacert_mail
    end

    # Get original message subject
    def original_subject
      postacert_message&.subject
    end

    # Get original message sender
    def original_from
      postacert_message&.from&.first
    end

    # Get original message recipients
    def original_to
      postacert_message&.to || []
    end

    # Get original message date
    def original_date
      postacert_message&.date
    end

    # Get original message body (text/plain preferred)
    def original_body
      mail = postacert_message
      return nil unless mail

      text_part = extract_text_part(mail, "text/plain")
      html_part = extract_text_part(mail, "text/html")
      selected_part = text_part || html_part

      return nil unless selected_part

      raw_body = selected_part.body.decoded
      charset = selected_part.charset || 
                selected_part.content_type_parameters&.[]("charset") || 
                "UTF-8"
      
      raw_body.force_encoding(charset).encode("UTF-8")
    end

    # Get original message attachments
    def original_attachments
      mail = postacert_message
      return [] unless mail&.attachments

      mail.attachments.map { |att| Attachment.new(att) }
    end

    # Summary information
    def summary
      {
        uid: @uid,
        subject: subject,
        from: from,
        to: to,
        date: date,
        has_postacert: has_postacert?,
        original_subject: original_subject,
        original_from: original_from,
        original_to: original_to,
        original_date: original_date,
        attachments_count: original_attachments.size
      }
    end

    private

    def extract_real_sender(from_addr)
      email = "#{from_addr.mailbox}@#{from_addr.host}"
      
      # Handle "Per conto di:" in name field
      if from_addr.name&.include?("Per conto di:")
        email_match = from_addr.name.match(/([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/)
        return email_match[1] if email_match
      elsif from_addr.name && !from_addr.name.include?("posta-certificata@")
        return from_addr.name
      end
      
      email
    end

    def find_postacert_part_ids(bodystructure = @bodystructure, path = "")
      results = []

      if bodystructure.respond_to?(:parts) && bodystructure.parts
        bodystructure.parts.each_with_index do |part, index|
          part_path = path.empty? ? "#{index + 1}" : "#{path}.#{index + 1}"
          results += find_postacert_part_ids(part, part_path)
        end
      elsif bodystructure.media_type == "MESSAGE" && bodystructure.subtype == "RFC822"
        if bodystructure.param && bodystructure.param["NAME"]&.downcase&.include?("postacert.eml")
          results << path
        end
      end

      results
    end

    def extract_text_part(mail, preferred_type = "text/plain")
      return mail unless mail.multipart?

      mail.parts.each do |part|
        if part.multipart?
          found = extract_text_part(part, preferred_type)
          return found if found
        elsif part.mime_type == preferred_type
          return part
        end
      end

      nil
    end
  end
end