# frozen_string_literal: true

require_relative 'pec_ruby/version'
require_relative 'pec_ruby/client'
require_relative 'pec_ruby/message'
require_relative 'pec_ruby/attachment'

# CLI is optional - only load if dependencies are available
begin
  require_relative 'pec_ruby/cli'
rescue LoadError
  # CLI dependencies not available - skip CLI functionality
end

module PecRuby
  class Error < StandardError; end
  class ConnectionError < Error; end
  class AuthenticationError < Error; end
  class MessageNotFoundError < Error; end
  class PostacertNotFoundError < Error; end
  class FolderError < Error; end
end
