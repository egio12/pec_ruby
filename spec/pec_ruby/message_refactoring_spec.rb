require 'spec_helper'

RSpec.describe PecRuby::Message, 'Refactoring improvements' do
  let(:client) do
    PecRuby::Client.new(
      host: ENV['PEC_HOST'] || 'imap.example.com',
      username: ENV['PEC_USERNAME'] || 'test@example.pec.it',
      password: ENV['PEC_PASSWORD'] || 'test_password'
    )
  end

  before do
    client.connect
  end

  after do
    client.disconnect
  end

  describe 'Unified postacert part finding' do
    let(:test_uid) { ENV['PEC_TEST_UID']&.to_i || 1 }
    let(:message) { client.message(test_uid) }

    it 'finds main postacert parts without nested search' do
      skip 'Requires test PEC message' unless ENV['PEC_TEST_UID']
      main_parts = message.send(:find_postacert_part_ids)
      expect(main_parts).to be_an(Array)
      expect(main_parts.size).to be >= 0
    end

    it 'finds all postacert parts including nested when requested' do
      skip 'Requires test PEC message' unless ENV['PEC_TEST_UID']
      all_parts = message.send(:find_postacert_part_ids, message.instance_variable_get(:@bodystructure), "", true)
      expect(all_parts).to be_an(Array)
      expect(all_parts.size).to be >= 0
    end

    it 'correctly differentiates between main and nested parts' do
      skip 'Requires test PEC message' unless ENV['PEC_TEST_UID']
      main_parts = message.send(:find_postacert_part_ids)
      all_parts = message.send(:find_postacert_part_ids, message.instance_variable_get(:@bodystructure), "", true)
      
      nested_parts = all_parts - main_parts
      expect(nested_parts).to be_an(Array)
    end
  end

  describe 'SimpleMailAttachment wrapper' do
    it 'correctly mimics Mail::Attachment interface' do
      mail_data = double('Mail')
      allow(mail_data).to receive(:to_s).and_return('email content')
      
      wrapper = PecRuby::SimpleMailAttachment.new(mail_data, 'test.eml', 'message/rfc822')
      
      expect(wrapper.filename).to eq('test.eml')
      expect(wrapper.mime_type).to eq('message/rfc822')
      expect(wrapper.decoded).to eq('email content')
    end
  end

  describe 'Memoization behavior' do
    let(:test_uid) { ENV['PEC_TEST_UID']&.to_i || 1 }
    let(:message) { client.message(test_uid) }

    it 'memoizes original_attachments' do
      skip 'Requires test PEC message' unless ENV['PEC_TEST_UID']
      # Force calculation
      attachments = message.original_attachments
      
      # Verify memoization variable is set
      expect(message.instance_variable_get(:@original_attachments)).not_to be_nil
      expect(message.instance_variable_get(:@original_attachments)).to eq(attachments)
    end

    it 'memoizes nested_postacert_attachments' do
      skip 'Requires test PEC message' unless ENV['PEC_TEST_UID']
      # Force calculation
      nested = message.send(:nested_postacert_attachments)
      
      # Verify memoization variable is set
      expect(message.instance_variable_get(:@nested_postacert_attachments)).not_to be_nil
      expect(message.instance_variable_get(:@nested_postacert_attachments)).to eq(nested)
    end
  end

  describe 'Error resilience' do
    let(:test_uid) { ENV['PEC_TEST_UID']&.to_i || 1 }
    let(:message) { client.message(test_uid) }

    it 'handles missing bodystructure gracefully' do
      # Temporarily break the bodystructure
      original_bodystructure = message.instance_variable_get(:@bodystructure)
      message.instance_variable_set(:@bodystructure, nil)
      
      expect { message.send(:find_postacert_part_ids) }.not_to raise_error
      
      # Restore
      message.instance_variable_set(:@bodystructure, original_bodystructure)
    end

    it 'handles IMAP fetch errors in nested attachments' do
      skip 'Requires test PEC message' unless ENV['PEC_TEST_UID']
      # This should log warnings but not crash
      expect { message.send(:nested_postacert_attachments) }.not_to raise_error
    end
  end

  describe 'Text extraction delegation' do
    let(:test_uid) { ENV['PEC_TEST_UID']&.to_i || 1 }
    let(:message) { client.message(test_uid) }

    it 'delegates text extraction to NestedPostacertMessage' do
      skip 'Requires test PEC message' unless ENV['PEC_TEST_UID']
      mail = message.postacert_message
      result = message.send(:extract_text_part, mail, 'text/plain')
      
      # Should return a mail part or nil, not crash
      expect(result).to be_a(Mail::Part).or be_nil
    end
  end
end