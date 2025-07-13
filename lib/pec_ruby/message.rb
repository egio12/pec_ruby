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
      decoded = decoded.gsub("POSTA CERTIFICATA:", "") if decoded.start_with?("POSTA CERTIFICATA:")
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

    # Get original message body with format information
    def original_body
      mail = postacert_message
      return nil unless mail

      text_part = extract_text_part(mail, "text/plain")
      html_part = extract_text_part(mail, "text/html")
      
      # Prefer text/plain, but return HTML if that's all we have
      selected_part = text_part || html_part

      return nil unless selected_part

      raw_body = selected_part.body.decoded
      charset = selected_part.charset || 
                selected_part.content_type_parameters&.[]("charset") || 
                "UTF-8"
      
      content = raw_body.dup.force_encoding(charset).encode("UTF-8")
      
      {
        content: content,
        content_type: selected_part.mime_type,
        charset: charset
      }
    end

    # Get original message body as plain text only
    def original_body_text
      mail = postacert_message
      return nil unless mail

      text_part = extract_text_part(mail, "text/plain")
      return nil unless text_part

      raw_body = text_part.body.decoded
      charset = text_part.charset || 
                text_part.content_type_parameters&.[]("charset") || 
                "UTF-8"
      
      raw_body.dup.force_encoding(charset).encode("UTF-8")
    end

    # Get original message body as HTML only
    def original_body_html
      mail = postacert_message
      return nil unless mail

      html_part = extract_text_part(mail, "text/html")
      return nil unless html_part

      raw_body = html_part.body.decoded
      charset = html_part.charset || 
                html_part.content_type_parameters&.[]("charset") || 
                "UTF-8"
      
      raw_body.dup.force_encoding(charset).encode("UTF-8")
    end

    # Get original message attachments (with memoization)
    def original_attachments
      @original_attachments ||= begin
        mail = postacert_message
        attachments = []
        
        # Add attachments from the original message
        if mail&.attachments
          attachments += mail.attachments.map { |att| Attachment.new(att) }
        end
        
        # Also check for postacert.eml attachments in the outer message structure
        # This handles cases where postacert.eml files are forwarded as attachments
        attachments += nested_postacert_attachments
        
        attachments
      end
    end

    # Get original message attachments that are NOT postacert.eml files
    def original_regular_attachments
      original_attachments.reject(&:postacert?)
    end

    # Get nested postacert.eml files from original message attachments
    def nested_postacerts
      @nested_postacerts ||= original_attachments.select(&:postacert?)
    end

    # Check if original message has nested postacert.eml files
    def has_nested_postacerts?
      !nested_postacerts.empty?
    end

    # Get all nested postacert messages parsed and ready to use
    def nested_postacert_messages
      nested_postacerts.map(&:as_postacert_message).compact
    end

    # Get a flattened view of all postacert messages (original + nested)
    # Returns array with the original message first, followed by nested ones
    def all_postacert_messages
      messages = []
      
      # Add the main postacert message (this message)
      if has_postacert?
        messages << {
          level: 0,
          message: self,
          type: :main_postacert
        }
      end
      
      # Add nested postacert messages
      nested_postacert_messages.each_with_index do |nested_msg, index|
        messages << {
          level: 1,
          message: nested_msg,
          type: :nested_postacert,
          index: index
        }
        
        # Check for deeper nesting (postacert within postacert within postacert)
        if nested_msg.has_nested_postacerts?
          nested_msg.nested_postacerts.each_with_index do |deep_nested, deep_index|
            deep_nested_msg = deep_nested.as_postacert_message
            if deep_nested_msg
              messages << {
                level: 2,
                message: deep_nested_msg,
                type: :deep_nested_postacert,
                parent_index: index,
                index: deep_index
              }
            end
          end
        end
      end
      
      messages
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
        attachments_count: original_attachments.size,
        regular_attachments_count: original_regular_attachments.size,
        nested_postacerts_count: nested_postacerts.size,
        has_nested_postacerts: has_nested_postacerts?,
        total_postacert_messages: all_postacert_messages.size
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

    def nested_postacert_attachments
      @nested_postacert_attachments ||= begin
        attachments = []
        
        # Find all postacert.eml parts (including nested)
        all_postacert_part_ids = find_postacert_part_ids(@bodystructure, "", true)
        main_postacert_part_id = find_postacert_part_ids.first
        
        # Add any postacert.eml parts that are not the main one as attachments
        nested_postacert_part_ids = all_postacert_part_ids - [main_postacert_part_id]
        
        nested_postacert_part_ids.each do |part_id|
          begin
            raw_data = @client.fetch_body_part(@uid, part_id)
            mail_data = Mail.read_from_string(raw_data)
            
            # Create a simplified attachment wrapper
            wrapper = SimpleMailAttachment.new(mail_data, "postacert.eml", "message/rfc822")
            attachments << Attachment.new(wrapper)
          rescue => e
            puts "Warning: Failed to extract nested postacert.eml at #{part_id}: #{e.message}"
          end
        end
        
        attachments
      end
    end
    

    def find_postacert_part_ids(bodystructure = @bodystructure, path = "", include_nested = false)
      results = []
      
      return results unless bodystructure

      if bodystructure.respond_to?(:parts) && bodystructure.parts
        bodystructure.parts.each_with_index do |part, index|
          part_path = path.empty? ? "#{index + 1}" : "#{path}.#{index + 1}"
          results += find_postacert_part_ids(part, part_path, include_nested)
        end
      elsif bodystructure.respond_to?(:media_type) && bodystructure.media_type == "MESSAGE" && 
            bodystructure.respond_to?(:subtype) && bodystructure.subtype == "RFC822"
        if bodystructure.respond_to?(:param) && bodystructure.param && 
           bodystructure.param["NAME"]&.downcase&.include?("postacert.eml")
          results << path
        end
        
        # Search inside MESSAGE/RFC822 bodies for nested postacert.eml files if requested
        if include_nested && bodystructure.respond_to?(:body) && bodystructure.body&.respond_to?(:parts)
          bodystructure.body.parts.each_with_index do |nested_part, nested_index|
            nested_path = "#{path}.#{nested_index + 1}"
            results += find_postacert_part_ids(nested_part, nested_path, include_nested)
          end
        end
      end

      results
    end

    # Delegate to the shared implementation in NestedPostacertMessage
    def extract_text_part(mail, preferred_type = "text/plain")
      NestedPostacertMessage.new(mail).send(:extract_text_part, mail, preferred_type)
    end
  end
end