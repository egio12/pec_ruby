# frozen_string_literal: true

require 'mail'

module PecRuby
  class Attachment
    attr_reader :mail_attachment

    def initialize(mail_attachment)
      @mail_attachment = mail_attachment
    end

    def filename
      @mail_attachment.filename || "unnamed_file"
    end

    def mime_type
      @mail_attachment.mime_type || "application/octet-stream"
    end

    def size
      content.bytesize
    end

    def size_kb
      (size / 1024.0).round(1)
    end

    def size_mb
      (size / 1024.0 / 1024.0).round(2)
    end

    def content
      @mail_attachment.decoded
    end

    # Save attachment to file
    def save_to(path)
      File.binwrite(path, content)
    end

    # Save attachment to directory with original filename
    def save_to_dir(directory)
      path = File.join(directory, filename)
      save_to(path)
      path
    end

    def summary
      {
        filename: filename,
        mime_type: mime_type,
        size: size,
        size_kb: size_kb,
        size_mb: size_mb
      }
    end

    def to_s
      "#{filename} (#{mime_type}, #{size_kb} KB)"
    end

    # Check if this attachment is a postacert.eml file
    def postacert?
      filename&.downcase&.include?('postacert.eml') || 
      (filename&.downcase&.end_with?('.eml') && mime_type&.include?('message'))
    end

    # Parse this attachment as a postacert.eml if it is one
    # Returns a PecRuby::Message-like object for the nested postacert
    def as_postacert_message
      return nil unless postacert?
      
      begin
        # Parse the attachment content as an email message
        nested_mail = Mail.read_from_string(content)
        
        # Create a simplified message object for the nested postacert
        NestedPostacertMessage.new(nested_mail)
      rescue => e
        raise PecRuby::Error, "Failed to parse nested postacert.eml: #{e.message}"
      end
    end
  end

  # Simplified message class for nested postacert emails
  class NestedPostacertMessage
    attr_reader :mail

    def initialize(mail)
      @mail = mail
    end

    def subject
      @mail.subject
    end

    def from
      @mail.from&.first
    end

    def to
      @mail.to || []
    end

    def date
      @mail.date
    end

    def body
      # Try to get text/plain first, then text/html
      text_part = extract_text_part(@mail, "text/plain")
      html_part = extract_text_part(@mail, "text/html")
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

    def body_text
      text_part = extract_text_part(@mail, "text/plain")
      return nil unless text_part

      raw_body = text_part.body.decoded
      charset = text_part.charset || 
                text_part.content_type_parameters&.[]("charset") || 
                "UTF-8"
      
      raw_body.dup.force_encoding(charset).encode("UTF-8")
    end

    def body_html
      html_part = extract_text_part(@mail, "text/html")
      return nil unless html_part

      raw_body = html_part.body.decoded
      charset = html_part.charset || 
                html_part.content_type_parameters&.[]("charset") || 
                "UTF-8"
      
      raw_body.dup.force_encoding(charset).encode("UTF-8")
    end

    def attachments
      return [] unless @mail&.attachments

      @mail.attachments.map { |att| Attachment.new(att) }
    end

    def summary
      {
        subject: subject,
        from: from,
        to: to,
        date: date,
        attachments_count: attachments.size,
        nested_postacerts_count: nested_postacerts.size
      }
    end

    # Find any nested postacert.eml files in this message's attachments
    def nested_postacerts
      attachments.select(&:postacert?)
    end

    # Check if this nested message has any nested postacert.eml files
    def has_nested_postacerts?
      !nested_postacerts.empty?
    end

    private

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