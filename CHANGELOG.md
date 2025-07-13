# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.2] - 2025-07-13

### Fixed
- **CLI body display bug**: Fixed `NoMethodError` when displaying message body in CLI where `original_body` hash was treated as string
- **Message ordering in CLI**: Fixed message sorting to properly show newest messages first by date instead of sequence number

### Changed
- **CLI improvements**: Increased message limit from 20 to 50 messages for better user experience
- **Text formatting**: Enhanced body text formatting with smart quote normalization and line ending cleanup

### Added
- Better text readability in CLI with automatic formatting improvements
- Proper handling of different character encodings in message body display

## [0.2.1] - 2025-07-13

### Fixed
- **Fixed forwarded postacert.eml detection**: Now correctly detects and processes postacert.eml files that are forwarded as attachments in nested MESSAGE/RFC822 structures
- Improved nested postacert part ID detection algorithm to handle complex IMAP message structures

### Added
- Comprehensive test suite for nested postacert detection scenarios
- Performance optimizations with memoization for attachment calculations
- Enhanced error handling for malformed IMAP structures
- Support for environment variable configuration (`PEC_HOST`, `PEC_USERNAME`, `PEC_PASSWORD`)
- Security improvements to prevent credential leaks in test files

### Changed
- **Code refactoring**: Unified duplicate postacert detection methods into single parameterized method
- **Performance**: Added memoization to `original_attachments`, `nested_postacerts`, and `nested_postacert_attachments` methods
- **Security**: Test files now use environment variables instead of hardcoded credentials
- Improved robustness of bodystructure parsing with defensive programming techniques

### Security
- Removed all hardcoded credentials from test files
- Added `.env.example` for secure configuration
- Enhanced `.gitignore` to prevent accidental credential commits
- Added security documentation in README

## [0.2.0] - 2025-07-13

### Changed
- **Breaking Change**: `original_body` now returns a hash with format information instead of plain text
  - Hash contains: `content`, `content_type`, and `charset` keys
  - Allows proper handling of HTML vs plain text content
  - Preserves original formatting for correct display

### Added  
- `original_body_text` method for getting plain text content only
- `original_body_html` method for getting HTML content only
- Enhanced body format detection and handling
- Better charset handling for international content
- **Nested postacert.eml support** for handling forwarded PECs
  - `Attachment#postacert?` to detect postacert.eml attachments
  - `Attachment#as_postacert_message` to parse nested PECs
  - `Message#nested_postacerts` to get nested postacert attachments
  - `Message#original_regular_attachments` to get non-postacert attachments
  - `Message#has_nested_postacerts?` to check for nested PECs
  - `Message#nested_postacert_messages` to get parsed nested messages
  - `Message#all_postacert_messages` for hierarchical view of all messages
- `PecRuby::NestedPostacertMessage` class for nested postacert handling
  - Full API compatibility with original message methods
  - Support for multi-level nesting (postacert within postacert)
  - Automatic detection and parsing of deeper nesting levels

## [0.1.0] - 2025-07-13

### Added
- Initial release of PecRuby gem
- IMAP client for connecting to Italian PEC servers
- Automatic extraction of postacert.eml attachments
- Message parsing and decoding functionality
- Attachment management with download capabilities
- Command-line interface (CLI) for interactive exploration
- Comprehensive error handling
- Support for flexible installation (with/without CLI dependencies)
- Complete API documentation
- Example usage files

### Features
- **PecRuby::Client**: Main client class for IMAP operations
- **PecRuby::Message**: Message representation with original content extraction
- **PecRuby::Attachment**: Attachment handling with save capabilities
- **PecRuby::CLI**: Interactive command-line interface
- **Error Classes**: Specific error types for better error handling
- **Flexible Dependencies**: Optional CLI dependencies for minimal installations

### Supported Providers
- Aruba PEC (imaps.pec.aruba.it)
- Generic IMAP-compliant PEC providers

[Unreleased]: https://github.com/egio12/pec_ruby/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/egio12/pec_ruby/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/egio12/pec_ruby/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/egio12/pec_ruby/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/egio12/pec_ruby/releases/tag/v0.1.0