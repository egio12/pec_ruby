# PecRuby

A comprehensive Ruby gem for decoding and managing Italian PEC (Posta Elettronica Certificata) email messages.

## Features

- **IMAP Connection**: Connect to Italian PEC servers
- **Automatic Extraction**: Automatically extracts original messages from postacert.eml attachments
- **Attachment Management**: Download and manage attachments easily
- **CLI Included**: Command-line interface for exploring PEC messages
- **Programmatic API**: Methods for integrating PEC functionality into your Ruby applications

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
puts message.original_body    # Original message body

# Attachments
message.original_attachments.each do |attachment|
  puts "#{attachment.filename} (#{attachment.size_kb} KB)"
  
  # Save attachment
  attachment.save_to("/path/to/file.pdf")
  # or
  attachment.save_to_dir("/downloads/")
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
message.original_body     # String: Original message body (decoded)
```

##### Attachments

```ruby
# Get original message attachments
message.original_attachments  # Array<PecRuby::Attachment>
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

# Summary
attachment.summary      # Hash: Complete attachment information
attachment.to_s         # String: Human-readable description
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
    puts "Attachments: #{message.original_attachments.size}"
    
    # Download attachments
    message.original_attachments.each do |attachment|
      attachment.save_to_dir('./downloads')
      puts "Downloaded: #{attachment.filename}"
    end
    
    puts "─" * 40
  end

ensure
  client&.disconnect
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

## Contact

Enrico Giordano - enricomaria.giordano@icloud.com

Project Link: [https://github.com/egio12/pec_ruby](https://github.com/egio12/pec_ruby)