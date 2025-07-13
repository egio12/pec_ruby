# PecRuby

A comprehensive Ruby gem for decoding and managing Italian PEC (Posta Elettronica Certificata) email messages.

## Features

- **IMAP Connection**: Connect to Italian PEC servers
- **Automatic Extraction**: Automatically extracts original messages from postacert.eml attachments
- **Nested PEC Support**: **NEW in v0.2.1** - Detects and processes forwarded PEC messages (nested postacert.eml files)
- **Attachment Management**: Download and manage attachments easily
- **Performance Optimized**: **NEW in v0.2.1** - Memoization for faster repeated access to attachments
- **CLI Included**: Command-line interface for exploring PEC messages
- **Programmatic API**: Methods for integrating PEC functionality into your Ruby applications
- **Comprehensive Testing**: Full test suite with both unit and integration tests

## Installation

### Library Only (without CLI)

To use only the programmatic API without the command-line interface:

```ruby
gem 'pec_ruby'
```

Or install directly:

```bash
gem install pec_ruby
```

### With CLI Included

To also use the command-line interface, install additional dependencies:

```bash
gem install pec_ruby tty-prompt awesome_print
```

Or in your Gemfile:

```ruby
gem 'pec_ruby'
gem 'tty-prompt', '~> 0.23'
gem 'awesome_print', '~> 1.9'
```

## CLI Usage

After complete installation (with CLI dependencies), you can use the CLI:

```bash
pec_ruby
```

**Note**: If you installed only the library without CLI dependencies, the `pec_ruby` executable will inform you how to install them.

The CLI allows you to:
- Connect to your PEC server
- Explore received messages
- View decoded original message contents
- Download attachments
- **NEW in v0.2.1**: Detect and process forwarded PEC messages (nested postacert.eml files)
- **NEW in v0.2.1**: Enhanced performance with memoization for large attachments

## Programmatic Usage

### Basic Connection

```ruby
require 'pec_ruby'

# Connect to PEC server
client = PecRuby::Client.new(
  host: 'imaps.pec.aruba.it',
  username: 'your@domain.pec.it', 
  password: 'password'
)

client.connect
```

### Retrieving Messages

```ruby
# All messages (last 10)
messages = client.messages(limit: 10)

# Only PEC messages (with postacert.eml)
pec_messages = client.pec_messages(limit: 10)

# Specific message by UID
message = client.message(12345)
```

### Working with Messages

```ruby
message = client.pec_messages.first

# PEC container information
puts message.subject        # PEC message subject
puts message.from          # PEC sender
puts message.date          # PEC message date

# Original message information
puts message.original_subject  # Original subject
puts message.original_from    # Original sender
body_info = message.original_body    # Original message body with format info

# Attachments
message.original_attachments.each do |attachment|
  puts "#{attachment.filename} (#{attachment.size_kb} KB)"
  
  # Check if attachment is a nested postacert.eml (forwarded PEC)
  if attachment.postacert?
    puts "  -> This is a nested postacert.eml!"
    nested_msg = attachment.as_postacert_message
    puts "  -> Original subject: #{nested_msg.subject}"
    puts "  -> Original from: #{nested_msg.from}"
  else
    # Save regular attachment
    attachment.save_to("/path/to/file.pdf")
    # or
    attachment.save_to_dir("/downloads/")
  end
end

# Handle nested postacerts (forwarded PECs)
if message.has_nested_postacerts?
  puts "This message contains #{message.nested_postacerts.size} forwarded PEC(s)"
  
  message.nested_postacert_messages.each do |nested_msg|
    puts "Nested PEC: #{nested_msg.subject} from #{nested_msg.from}"
  end
end
```

## API Documentation

### PecRuby::Client

The main client class for connecting to PEC servers.

#### Constructor

```ruby
PecRuby::Client.new(host:, username:, password:, ssl: true)
```

**Parameters:**
- `host` (String): IMAP server hostname
- `username` (String): PEC email address
- `password` (String): Account password
- `ssl` (Boolean): Use SSL connection (default: true)

> **Security Note**: For production usage, consider using environment variables instead of hardcoding credentials:
> ```ruby
> client = PecRuby::Client.new(
>   host: ENV['PEC_HOST'],
>   username: ENV['PEC_USERNAME'],
>   password: ENV['PEC_PASSWORD']
> )
> ```

#### Instance Methods

##### `#connect`
Establishes connection to the PEC server.

```ruby
client.connect
# Returns: self
# Raises: PecRuby::ConnectionError, PecRuby::AuthenticationError
```

##### `#disconnect`
Safely disconnects from the PEC server.

```ruby
client.disconnect
# Returns: nil
```

##### `#connected?`
Checks if currently connected to the server.

```ruby
client.connected?
# Returns: Boolean
```

##### `#messages(limit: nil, reverse: true)`
Retrieves messages from the server.

```ruby
messages = client.messages(limit: 10, reverse: true)
# Returns: Array<PecRuby::Message>
```

**Parameters:**
- `limit` (Integer, optional): Maximum number of messages to retrieve
- `reverse` (Boolean): Return newest messages first (default: true)

##### `#pec_messages(limit: nil, reverse: true)`
Retrieves only messages containing postacert.eml.

```ruby
pec_messages = client.pec_messages(limit: 5)
# Returns: Array<PecRuby::Message>
```

##### `#message(uid)`
Retrieves a specific message by UID.

```ruby
message = client.message(12345)
# Returns: PecRuby::Message or nil
```

### PecRuby::Message

Represents a PEC message with access to both container and original message data.

#### Instance Methods

##### Basic PEC Container Information

```ruby
# PEC envelope information
message.uid            # Integer: Message UID
message.subject        # String: PEC subject (cleaned)
message.from           # String: PEC sender
message.to             # Array<String>: PEC recipients
message.date           # Time: PEC message date
```

##### Original Message Access

```ruby
# Check if postacert.eml is available
message.has_postacert?    # Boolean

# Original message information
message.original_subject  # String: Original subject
message.original_from     # String: Original sender
message.original_to       # Array<String>: Original recipients
message.original_date     # Time: Original message date
message.original_body     # Hash: Original message body with format info
message.original_body_text  # String: Plain text body only
message.original_body_html  # String: HTML body only
```

##### Original Message Body

The `original_body` method returns a hash with format information, allowing you to handle different content types appropriately:

```ruby
body_info = message.original_body
if body_info
  puts "Content type: #{body_info[:content_type]}"
  puts "Charset: #{body_info[:charset]}"
  
  case body_info[:content_type]
  when 'text/html'
    # Handle HTML content - preserve formatting for web display
    html_content = body_info[:content]
    # You can now render this in a web browser or HTML viewer
  when 'text/plain'
    # Handle plain text content
    text_content = body_info[:content]
    puts text_content
  end
end

# Or use convenience methods for specific formats
text_only = message.original_body_text  # Returns nil if no text/plain part
html_only = message.original_body_html  # Returns nil if no text/html part
```

##### Attachments

```ruby
# Get original message attachments
message.original_attachments         # Array<PecRuby::Attachment> - All attachments
message.original_regular_attachments # Array<PecRuby::Attachment> - Non-postacert attachments only
message.nested_postacerts           # Array<PecRuby::Attachment> - Nested postacert.eml files only

# Check for nested postacerts (forwarded PECs)
message.has_nested_postacerts?      # Boolean
message.nested_postacert_messages   # Array<PecRuby::NestedPostacertMessage>

# Get all postacert messages in a flattened structure
message.all_postacert_messages      # Array<Hash> - Hierarchical view of all messages
```

##### Summary Information

```ruby
# Get complete message summary
summary = message.summary
# Returns: Hash with all message information
```

### PecRuby::Attachment

Represents an attachment from the original message.

#### Instance Methods

```ruby
# Basic information
attachment.filename     # String: Original filename
attachment.mime_type    # String: MIME type
attachment.size         # Integer: Size in bytes
attachment.size_kb      # Float: Size in KB
attachment.size_mb      # Float: Size in MB

# Content access
attachment.content      # String: Raw binary content

# File operations
attachment.save_to(path)           # Save to specific path
attachment.save_to_dir(directory)  # Save to directory with original filename

# Nested postacert detection and parsing
attachment.postacert?              # Boolean: Check if this is a postacert.eml
attachment.as_postacert_message    # PecRuby::NestedPostacertMessage: Parse as nested PEC

# Summary
attachment.summary      # Hash: Complete attachment information
attachment.to_s         # String: Human-readable description
```

### PecRuby::NestedPostacertMessage

Represents a nested postacert.eml file (forwarded PEC) found within attachments.

#### Instance Methods

```ruby
# Basic message information
nested_msg.subject      # String: Subject of the nested message
nested_msg.from         # String: Sender of the nested message
nested_msg.to           # Array<String>: Recipients of the nested message
nested_msg.date         # Time: Date of the nested message

# Body content (same API as original_body)
nested_msg.body         # Hash: Body with content_type and charset info
nested_msg.body_text    # String: Plain text body only
nested_msg.body_html    # String: HTML body only

# Nested attachments
nested_msg.attachments           # Array<PecRuby::Attachment>
nested_msg.nested_postacerts     # Array<PecRuby::Attachment> - Even deeper nesting!
nested_msg.has_nested_postacerts? # Boolean: Check for deeper nesting

# Summary
nested_msg.summary      # Hash: Complete nested message information
```

## Complete Example

```ruby
require 'pec_ruby'

begin
  # Connect
  client = PecRuby::Client.new(
    host: 'imaps.pec.aruba.it',
    username: 'example@pec.it',
    password: 'password'
  )
  client.connect

  # Get last 5 PEC messages
  pec_messages = client.pec_messages(limit: 5)
  
  pec_messages.each do |message|
    puts "Subject: #{message.original_subject}"
    puts "From: #{message.original_from}"
    puts "Total attachments: #{message.original_attachments.size}"
    puts "Regular attachments: #{message.original_regular_attachments.size}"
    puts "Nested PECs: #{message.nested_postacerts.size}"
    
    # Handle message body based on format
    body_info = message.original_body
    if body_info
      puts "Body format: #{body_info[:content_type]}"
      case body_info[:content_type]
      when 'text/html'
        puts "HTML content available for web display"
        # Save HTML to file for viewing
        File.write("./downloads/message_#{message.uid}.html", body_info[:content])
      when 'text/plain'
        puts "Text content:"
        puts body_info[:content][0..100] + "..." # First 100 chars
      end
    end
    
    # Download regular attachments
    message.original_regular_attachments.each do |attachment|
      attachment.save_to_dir('./downloads')
      puts "Downloaded: #{attachment.filename}"
    end
    
    # Handle nested postacerts (forwarded PECs)
    if message.has_nested_postacerts?
      puts "Found #{message.nested_postacerts.size} forwarded PEC(s):"
      
      message.nested_postacert_messages.each_with_index do |nested_msg, index|
        puts "  Nested PEC ##{index + 1}:"
        puts "    Subject: #{nested_msg.subject}"
        puts "    From: #{nested_msg.from}"
        puts "    Attachments: #{nested_msg.attachments.size}"
        
        # Download nested PEC attachments
        nested_msg.attachments.each do |nested_attachment|
          unless nested_attachment.postacert? # Avoid infinite recursion
            nested_attachment.save_to_dir('./downloads/nested')
            puts "    Downloaded nested: #{nested_attachment.filename}"
          end
        end
        
        # Check for even deeper nesting
        if nested_msg.has_nested_postacerts?
          puts "    -> This nested PEC contains #{nested_msg.nested_postacerts.size} more nested PEC(s)!"
        end
      end
    end
    
    puts "─" * 40
  end

ensure
  client&.disconnect
end
```

### Nested PEC Detection Example (NEW in v0.2.1)

Handle forwarded PEC messages that contain other PEC messages as attachments:

```ruby
# Find a message with forwarded PECs
message = client.pec_messages.find { |msg| msg.has_nested_postacerts? }

if message
  puts "Found message with #{message.nested_postacerts.size} forwarded PEC(s):"
  
  # Process each forwarded PEC
  message.nested_postacert_messages.each_with_index do |nested_msg, index|
    puts "  Forwarded PEC ##{index + 1}:"
    puts "    Subject: #{nested_msg.subject}"
    puts "    From: #{nested_msg.from}"
    puts "    Date: #{nested_msg.date}"
    puts "    Attachments: #{nested_msg.attachments.size}"
    
    # Download attachments from the forwarded PEC
    nested_msg.attachments.each do |attachment|
      unless attachment.postacert? # Avoid infinite recursion
        attachment.save_to_dir('./downloads/forwarded')
        puts "    Downloaded: #{attachment.filename}"
      end
    end
    
    # Check for even deeper nesting (PEC forwarded within forwarded PEC)
    if nested_msg.has_nested_postacerts?
      puts "    -> Contains #{nested_msg.nested_postacerts.size} more forwarded PEC(s)!"
    end
  end
end
```

## Error Handling

The gem defines several specific error classes:

```ruby
PecRuby::Error                 # Base error class
PecRuby::ConnectionError       # Connection issues
PecRuby::AuthenticationError   # Login failures
PecRuby::MessageNotFoundError  # Message not found
PecRuby::PostacertNotFoundError # postacert.eml not found
```

Example with error handling:

```ruby
begin
  client = PecRuby::Client.new(...)
  client.connect
rescue PecRuby::AuthenticationError => e
  puts "Login failed: #{e.message}"
rescue PecRuby::ConnectionError => e
  puts "Connection error: #{e.message}"
rescue PecRuby::Error => e
  puts "PEC error: #{e.message}"
end
```

## Supported PEC Providers

The gem has been tested with:
- Aruba PEC (`imaps.pec.aruba.it`) ✅ **Fully tested**

Other providers should work if they support standard IMAP, but have not been tested yet.

## Current Limitations

- **Message Threading**: The gem currently does not support message threading or conversation grouping. Each message is handled individually.
- **Provider Testing**: Only tested with Aruba PEC. Other providers may work but are not guaranteed.
- **Legal Compliance**: This library has not been evaluated for compliance with Italian PEC regulations or legal requirements. The message parsing methods used may not preserve all legally required aspects of certified email messages. Users should consult with legal experts and review applicable regulations before using this library in legally sensitive contexts.

## Testing & Development Configuration

### Environment Variables

For security, use environment variables to configure your PEC credentials:

```bash
# Copy the example environment file
cp .env.example .env

# Edit .env with your actual credentials
export PEC_HOST=imaps.pec.aruba.it
export PEC_USERNAME=your@domain.pec.it
export PEC_PASSWORD=your_password
export PEC_TEST_UID=1234  # Optional: specific message UID for testing
```

### Running Tests

The gem includes comprehensive tests for all functionality:

```bash
bundle install

# Run all tests (will skip integration tests without PEC credentials)
bundle exec rspec

# Run with PEC credentials for full integration testing
PEC_HOST=imaps.pec.aruba.it PEC_USERNAME=your@domain.pec.it PEC_PASSWORD=your_password bundle exec rspec

# Run specific test suites
bundle exec rspec spec/pec_ruby/nested_postacert_spec.rb  # Nested PEC detection tests
bundle exec rspec spec/pec_ruby/message_refactoring_spec.rb  # Performance & refactoring tests

# Check code style
bundle exec rubocop
```

**Note**: Integration tests require real PEC credentials and will be skipped if environment variables are not set. Unit tests will always run.

## Development

After cloning the repository:

```bash
bundle install
bundle exec rspec          # Run tests
bundle exec rubocop        # Check code style
```

## Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

Distributed under the MIT License. See `LICENSE` for more information.
