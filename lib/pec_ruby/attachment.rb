# frozen_string_literal: true

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
  end
end