# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/egio12/pec_ruby/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/egio12/pec_ruby/releases/tag/v0.1.0