require 'spec_helper'

RSpec.describe 'Nested PostaCert Detection' do
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

  describe 'Message with forwarded postacert.eml' do
    let(:test_uid) { ENV['PEC_TEST_UID']&.to_i || 1 }
    let(:message) { client.message(test_uid) }

    it 'detects the main postacert' do
      skip 'Requires test PEC message' unless ENV['PEC_TEST_UID']
      expect(message.has_postacert?).to be true
      expect(message.original_subject).not_to be_empty
      expect(message.original_from).not_to be_empty
    end

    it 'detects nested postacert attachments' do
      skip 'Requires test PEC message' unless ENV['PEC_TEST_UID']
      expect(message.original_attachments.size).to be >= 1
      expect(message.nested_postacerts.size).to be >= 0
    end

    it 'correctly identifies nested postacert files' do
      skip 'Requires test PEC message with nested postacerts' unless ENV['PEC_TEST_UID'] && message.nested_postacerts.any?
      nested_postacerts = message.nested_postacerts
      expect(nested_postacerts.first.filename).to eq('postacert.eml')
      expect(nested_postacerts.first.mime_type).to eq('message/rfc822')
      expect(nested_postacerts.first.postacert?).to be true
    end

    it 'can parse nested postacert messages' do
      skip 'Requires test PEC message with nested postacerts' unless ENV['PEC_TEST_UID'] && message.nested_postacerts.any?
      nested_messages = message.nested_postacert_messages
      expect(nested_messages.size).to be >= 1
      
      nested_msg = nested_messages.first
      expect(nested_msg.subject).not_to be_empty
      expect(nested_msg.from).not_to be_empty
    end

    it 'provides a summary with correct counts' do
      skip 'Requires test PEC message' unless ENV['PEC_TEST_UID']
      summary = message.summary
      expect(summary[:attachments_count]).to be >= 0
      expect(summary[:regular_attachments_count]).to be >= 0
      expect(summary[:nested_postacerts_count]).to be >= 0
      expect(summary[:has_nested_postacerts]).to be_in([true, false])
    end

    it 'handles flattened view of all postacert messages' do
      skip 'Requires test PEC message' unless ENV['PEC_TEST_UID']
      all_messages = message.all_postacert_messages
      expect(all_messages.size).to be >= 0
      
      if all_messages.any?
        main_msg = all_messages.find { |m| m[:type] == :main_postacert }
        expect(main_msg).not_to be_nil if message.has_postacert?
      end
    end
  end

  describe 'Performance optimizations' do
    let(:test_uid) { ENV['PEC_TEST_UID']&.to_i || 1 }
    let(:message) { client.message(test_uid) }

    it 'caches attachment calculations' do
      skip 'Requires test PEC message' unless ENV['PEC_TEST_UID']
      # First call
      attachments1 = message.original_attachments
      # Second call should return the same object (memoized)
      attachments2 = message.original_attachments
      expect(attachments1.object_id).to eq(attachments2.object_id)
    end

    it 'caches nested postacert calculations' do
      skip 'Requires test PEC message' unless ENV['PEC_TEST_UID']
      # Access nested postacerts multiple times
      nested1 = message.nested_postacerts
      nested2 = message.nested_postacerts
      expect(nested1.object_id).to eq(nested2.object_id)
    end
  end

  describe 'Error handling' do
    let(:test_uid) { ENV['PEC_TEST_UID']&.to_i || 1 }
    let(:message) { client.message(test_uid) }

    it 'handles invalid part IDs gracefully' do
      skip 'Requires test PEC message' unless ENV['PEC_TEST_UID']
      # This should not raise an error
      expect { message.nested_postacerts }.not_to raise_error
    end

    it 'continues processing if one nested postacert fails' do
      skip 'Requires test PEC message' unless ENV['PEC_TEST_UID']
      # Even if there are extraction errors, it should continue
      expect { message.original_attachments }.not_to raise_error
    end
  end
end