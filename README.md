# PecRuby

A comprehensive Ruby gem for decoding and managing Italian PEC (Posta Elettronica Certificata) email messages.

## Features

- **IMAP Connection**: Connect to Italian PEC servers
- **Automatic Extraction**: Automatically extracts original messages from postacert.eml attachments
- **Nested PEC Support**: **NEW in v0.2.1** - Detects and processes forwarded PEC messages (nested postacert.eml files)
- **Attachment Management**: Download and manage attachments easily
- **Performance Optimized**: **NEW in v0.2.1** - Memoization for faster repeated access to attachments
- **Ruby Way Behavior**: **NEW in v0.2.3** - Intuitive method behavior where `subject/from/to/date` always return the most relevant content
- **Smart Body Access**: **NEW in v0.2.3** - Universal body access methods work with both received and sent messages
- **Folder Management**: **NEW in v0.2.3** - Easy navigation and selection of PEC folders (INBOX, sent, drafts, etc.)
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
gem 'tty-screen', '~> 0.8'
gem 'awesome_print', '~> 1.9'
```

## CLI Usage

After complete installation (with CLI dependencies), you can use the CLI:

```bash
pec_ruby
```

**Note**: If you installed only the library without CLI dependencies, the `pec_ruby` executable will inform you how to install them.

**CLI Dependencies:**
- `tty-prompt` (~> 0.23) - Interactive menus and prompts
- `tty-screen` (~> 0.8) - Screen management and layout
- `awesome_print` (~> 1.9) - Enhanced object printing

The CLI allows you to:
- Connect to your PEC server
- **NEW in v0.2.3**: Select and switch between different folders (INBOX, Sent, etc.)
- Explore received messages with Ruby Way behavior (most relevant content displayed first)
- View decoded original message contents
- Download attachments
- **NEW in v0.2.1**: Detect and process forwarded PEC messages (nested postacert.eml files)
- **NEW in v0.2.1**: Enhanced performance with memoization for large attachments

### CLI Workflow (v0.2.3)

The CLI now features a **professional, full-screen interface** with enhanced performance and user experience:

**🚀 Performance Improvements:**
- **Optimized IMAP fetching**: Messages load in ~0.2s instead of several seconds
- **Smart envelope caching**: List view uses only envelope data (no postacert fetching)
- **Batch processing**: Efficient handling of large mailboxes
- **On-demand loading**: Full message details fetched only when selected

**🎨 Enhanced Interface:**
- **Fixed header**: Banner and status always visible
- **Clean screen management**: No scrolling, professional layout
- **Interactive message viewer**: Menu-driven navigation with options
- **Progress indicators**: Real-time feedback for all operations
- **Folder management**: Easy switching between INBOX, Sent, Trash, etc.

**📋 Complete Workflow:**
1. **Connect** to your PEC server with credential validation
2. **Select folder** from available options (INBOX, Sent, drafts, etc.)
3. **Browse messages** with fast envelope-based listing
4. **Message details** with interactive menu:
   - View complete message body
   - Download attachments with progress tracking
   - Navigate between Ruby Way and PEC envelope data
5. **Attachment management** with visual progress and batch download

**Main Menu Options:**
- **Connect to PEC server**: Secure login with connection status
- **Select folder**: Visual folder picker with current selection indicator
- **List and analyze messages**: Fast message browsing with timing information
- **Disconnect**: Clean logout with confirmation

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
messages = client.messages(limit: 10)

# Specific message by UID
message = client.message(12345)
```

### Working with Messages

```ruby
message = client.messages.first

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

##### `#available_folders` (NEW in v0.2.3)
Lists all available folders in the mailbox.

```ruby
folders = client.available_folders
# Returns: Array<String>
# Example: ["INBOX", "INBOX.inviata", "INBOX.bozze", "INBOX.cestino"]
```

##### `#select_folder(folder)` (NEW in v0.2.3)
Selects a specific folder for operations.

```ruby
client.select_folder('INBOX.inviata')
# Returns: Net::IMAP response
# Raises: PecRuby::FolderError if folder doesn't exist
```

##### `#select_inbox` (NEW in v0.2.3)
Convenience method to select the INBOX folder.

```ruby
client.select_inbox
# Returns: Net::IMAP response
# Raises: PecRuby::FolderError if INBOX doesn't exist
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


##### `#message(uid)`
Retrieves a specific message by UID.

```ruby
message = client.message(12345)
# Returns: PecRuby::Message or nil
```

### PecRuby::Message

Represents a PEC message with access to both container and original message data.

#### Instance Methods

##### Ruby Way Behavior - Most Relevant Content (NEW in v0.2.3)

```ruby
# These methods return the most relevant content:
# - postacert.eml content if available (received messages)
# - direct message content if no postacert.eml (sent messages)
message.uid            # Integer: Message UID
message.subject        # String: Most relevant subject
message.from           # String: Most relevant sender
message.to             # Array<String>: Most relevant recipients
message.date           # Time: Most relevant message date
message.has_postacert? # Boolean: Check if postacert.eml is available
```

##### PEC Container Access

```ruby
# These methods always return the outer PEC container information
message.original_subject  # String: PEC envelope subject (cleaned)
message.original_from     # String: PEC envelope sender
message.original_to       # Array<String>: PEC envelope recipients
message.original_date     # Time: PEC envelope date
```

##### Postacert.eml Access

```ruby
# Direct access to postacert.eml content (nil if not available)
message.postacert_body       # Hash: Postacert message body with format info
message.postacert_body_text  # String: Plain text body only
message.postacert_body_html  # String: HTML body only

# Legacy aliases for backward compatibility
message.original_body        # Hash: Alias for postacert_body
message.original_body_text   # String: Alias for postacert_body_text
message.original_body_html   # String: Alias for postacert_body_html
```

##### Smart Message Body Access (NEW in v0.2.3)

```ruby
# Smart body access - works with both received and sent messages
message.raw_body          # Hash: Body with format info (postacert.eml if available, otherwise direct message)
message.raw_body_text     # String: Plain text body (postacert.eml if available, otherwise direct message)
message.raw_body_html     # String: HTML body (postacert.eml if available, otherwise direct message)
```

**Behavior:**
- For received messages (with postacert.eml): Returns content from postacert.eml (same as `original_*` methods)
- For sent messages (without postacert.eml): Returns content from the message itself
- **Recommended**: Use `raw_body_*` methods for universal compatibility

##### Message Body Handling

Both `original_body` and `raw_body` methods return a hash with format information, allowing you to handle different content types appropriately:

```ruby
# Use raw_body for universal compatibility (recommended)
body_info = message.raw_body
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
text_only = message.raw_body_text  # Works for both received and sent messages
html_only = message.raw_body_html  # Works for both received and sent messages

# Use original_* methods only when you specifically need postacert.eml content
original_text = message.original_body_text  # Returns nil if no postacert.eml
original_html = message.original_body_html  # Returns nil if no postacert.eml
```

##### Attachments

```ruby
# Smart attachment access - returns most relevant attachments
message.attachments                  # Array<PecRuby::Attachment> - Smart attachment access
message.regular_attachments         # Array<PecRuby::Attachment> - Non-postacert attachments only

# Direct postacert.eml attachment access
message.postacert_attachments       # Array<PecRuby::Attachment> - All postacert attachments
message.postacert_regular_attachments # Array<PecRuby::Attachment> - Non-postacert attachments only
message.nested_postacerts           # Array<PecRuby::Attachment> - Nested postacert.eml files only

# Check for nested postacerts (forwarded PECs)
message.has_nested_postacerts?      # Boolean
message.nested_postacert_messages   # Array<PecRuby::NestedPostacertMessage>

# Get all postacert messages in a flattened structure
message.all_postacert_messages      # Array<Hash> - Hierarchical view of all messages

# Legacy aliases for backward compatibility
message.original_attachments        # Array<PecRuby::Attachment> - Alias for postacert_attachments
message.original_regular_attachments # Array<PecRuby::Attachment> - Alias for postacert_regular_attachments
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
  messages = client.messages(limit: 5)
  
  messages.each do |message|
    # Ruby Way - these methods automatically return the most relevant content
    puts "Subject: #{message.subject}"         # Postacert.eml subject if available, otherwise PEC envelope
    puts "From: #{message.from}"               # Postacert.eml sender if available, otherwise PEC envelope
    puts "Date: #{message.date}"               # Postacert.eml date if available, otherwise PEC envelope
    puts "Total attachments: #{message.attachments.size}"
    puts "Regular attachments: #{message.regular_attachments.size}"
    puts "Nested PECs: #{message.nested_postacerts.size}"
    
    # Handle message body based on format - use raw_body for universal compatibility
    body_info = message.raw_body
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
    message.regular_attachments.each do |attachment|
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

### Ruby Way Behavior Change (v0.2.3)

**Important**: In v0.2.3, we've changed the behavior of core methods to be more intuitive and "Ruby Way":

```ruby
# OLD behavior (v0.2.2 and earlier)
message.subject        # → Always PEC envelope subject
message.original_subject # → Postacert.eml subject (if available)

# NEW behavior (v0.2.3 and later) - Ruby Way
message.subject        # → Postacert.eml subject if available, otherwise PEC envelope
message.original_subject # → Always PEC envelope subject
```

**Migration**: Most code will continue to work, but if you specifically need PEC envelope data, use `original_*` methods. For postacert.eml data, use `postacert_*` methods or the legacy `original_*` aliases.

### Working with Different Folders (NEW in v0.2.3)

The gem now supports easy folder navigation:

```ruby
# List all available folders
folders = client.available_folders
puts "Available folders: #{folders.join(', ')}"
# Output: Available folders: INBOX, INBOX.inviata, INBOX.bozze, INBOX.cestino

# Select a specific folder
client.select_folder('INBOX.inviata')
# or use the convenience method for INBOX
client.select_inbox

# Get messages from the selected folder
messages = client.messages(limit: 10)
```

### Working with Sent Messages

The `raw_body_*` methods work seamlessly with sent messages (which don't have postacert.eml):

```ruby
# Get sent messages using the new folder methods
client.select_folder('INBOX.inviata')
sent_messages = client.messages(limit: 5)

sent_messages.each do |message|
  puts "Subject: #{message.subject}"
  puts "From: #{message.from}"
  puts "Date: #{message.date}"
  puts "Has postacert: #{message.has_postacert?}"  # Will be false for sent messages
  
  # Use raw_body methods for universal compatibility
  body_text = message.raw_body_text
  if body_text
    puts "Body preview: #{body_text[0..100]}..."
  end
  
  # original_* methods will return nil for sent messages
  puts "Original body: #{message.original_body_text.inspect}"  # => nil
  
  puts "─" * 40
end
```

### Nested PEC Detection Example (NEW in v0.2.1)

Handle forwarded PEC messages that contain other PEC messages as attachments:

```ruby
# Find a message with forwarded PECs
message = client.messages.find { |msg| msg.has_nested_postacerts? }

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
PecRuby::FolderError           # Folder selection issues (NEW in v0.2.3)
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
