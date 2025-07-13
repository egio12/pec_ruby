# frozen_string_literal: true

require 'ostruct'

RSpec.describe PecRuby::Client do
  let(:host) { 'imap.example.com' }
  let(:username) { 'test@example.com' }
  let(:password) { 'password' }
  let(:client) { described_class.new(host: host, username: username, password: password) }

  describe '#initialize' do
    it 'sets the connection parameters' do
      expect(client.host).to eq(host)
      expect(client.username).to eq(username)
      expect(client.imap).to be_nil
    end

    it 'sets SSL to true by default' do
      expect(client.instance_variable_get(:@ssl)).to be true
    end

    it 'allows SSL to be disabled' do
      client_no_ssl = described_class.new(host: host, username: username, password: password, ssl: false)
      expect(client_no_ssl.instance_variable_get(:@ssl)).to be false
    end
  end

  describe '#connected?' do
    context 'when not connected' do
      it 'returns false' do
        expect(client.connected?).to be false
      end
    end

    context 'when imap is set but disconnected' do
      before do
        mock_imap = double('Net::IMAP')
        allow(mock_imap).to receive(:disconnected?).and_return(true)
        client.instance_variable_set(:@imap, mock_imap)
      end

      it 'returns false' do
        expect(client.connected?).to be false
      end
    end

    context 'when connected' do
      before do
        mock_imap = double('Net::IMAP')
        allow(mock_imap).to receive(:disconnected?).and_return(false)
        client.instance_variable_set(:@imap, mock_imap)
      end

      it 'returns true' do
        expect(client.connected?).to be true
      end
    end
  end

  describe '#connect' do
    let(:mock_imap) { double('Net::IMAP') }

    before do
      allow(Net::IMAP).to receive(:new).and_return(mock_imap)
      allow(mock_imap).to receive(:authenticate)
      allow(mock_imap).to receive(:select)
    end

    it 'creates a new IMAP connection' do
      expect(Net::IMAP).to receive(:new).with(host, ssl: true)
      client.connect
    end

    it 'authenticates with the server' do
      expect(mock_imap).to receive(:authenticate).with("PLAIN", username, password)
      client.connect
    end

    it 'selects the INBOX' do
      expect(mock_imap).to receive(:select).with('INBOX')
      client.connect
    end

    it 'returns self' do
      expect(client.connect).to eq(client)
    end

    context 'when connection fails' do
      before do
        allow(Net::IMAP).to receive(:new).and_raise(Net::IMAP::Error, "Connection failed")
      end

      it 'raises ConnectionError' do
        expect { client.connect }.to raise_error(PecRuby::ConnectionError, /Failed to connect/)
      end
    end

    context 'when authentication fails' do
      before do
        allow(mock_imap).to receive(:authenticate).and_raise(Net::IMAP::Error, "Auth failed")
      end

      it 'raises AuthenticationError' do
        expect { client.connect }.to raise_error(PecRuby::AuthenticationError, /Authentication failed/)
      end
    end
  end

  describe '#disconnect' do
    let(:mock_imap) { double('Net::IMAP') }

    context 'when connected' do
      before do
        client.instance_variable_set(:@imap, mock_imap)
        allow(mock_imap).to receive(:disconnected?).and_return(false)
      end

      it 'logs out and disconnects' do
        expect(mock_imap).to receive(:logout)
        expect(mock_imap).to receive(:disconnect)
        client.disconnect
      end

      it 'sets @imap to nil' do
        allow(mock_imap).to receive(:logout)
        allow(mock_imap).to receive(:disconnect)
        client.disconnect
        expect(client.imap).to be_nil
      end
    end

    context 'when not connected' do
      it 'does nothing' do
        expect { client.disconnect }.not_to raise_error
      end
    end

    context 'when logout raises an error' do
      before do
        client.instance_variable_set(:@imap, mock_imap)
        allow(mock_imap).to receive(:disconnected?).and_return(false)
        allow(mock_imap).to receive(:logout).and_raise(StandardError)
      end

      it 'ignores the error and continues' do
        expect(mock_imap).to receive(:disconnect)
        expect { client.disconnect }.not_to raise_error
      end
    end
  end

  describe '#messages' do
    let(:mock_imap) { double('Net::IMAP') }

    before do
      client.instance_variable_set(:@imap, mock_imap)
      allow(mock_imap).to receive(:disconnected?).and_return(false)
    end

    context 'when not connected' do
      before do
        allow(mock_imap).to receive(:disconnected?).and_return(true)
      end

      it 'raises ConnectionError' do
        expect { client.messages }.to raise_error(PecRuby::ConnectionError, "Not connected")
      end
    end

    context 'when connected' do
      let(:sequence_numbers) { [1, 2, 3] }
      let(:mock_fetch_data) { [double('fetch_data')] }

      before do
        allow(mock_imap).to receive(:search).with(['ALL']).and_return(sequence_numbers)
        allow(mock_imap).to receive(:fetch).and_return(mock_fetch_data)
        allow(PecRuby::Message).to receive(:new)
      end

      it 'searches for all messages' do
        expect(mock_imap).to receive(:search).with(['ALL'])
        client.messages
      end

      it 'reverses the order by default' do
        expect(mock_imap).to receive(:fetch).with([3, 2, 1], anything)
        client.messages
      end

      it 'respects reverse: false option' do
        expect(mock_imap).to receive(:fetch).with([1, 2, 3], anything)
        client.messages(reverse: false)
      end

      it 'respects limit option' do
        expect(mock_imap).to receive(:fetch).with([3, 2], anything)
        client.messages(limit: 2)
      end
    end
  end

  describe '#message' do
    let(:mock_imap) { double('Net::IMAP') }
    let(:uid) { 123 }

    before do
      client.instance_variable_set(:@imap, mock_imap)
      allow(mock_imap).to receive(:disconnected?).and_return(false)
    end

    context 'when not connected' do
      before do
        allow(mock_imap).to receive(:disconnected?).and_return(true)
      end

      it 'raises ConnectionError' do
        expect { client.message(uid) }.to raise_error(PecRuby::ConnectionError, "Not connected")
      end
    end

    context 'when message exists' do
      let(:fetch_data) { [double('fetch_data')] }

      before do
        allow(mock_imap).to receive(:uid_fetch).and_return(fetch_data)
        allow(PecRuby::Message).to receive(:new)
      end

      it 'fetches the message by UID' do
        expect(mock_imap).to receive(:uid_fetch).with(uid, ["UID", "ENVELOPE", "BODYSTRUCTURE"])
        client.message(uid)
      end

      it 'creates a Message object' do
        expect(PecRuby::Message).to receive(:new).with(client, fetch_data.first)
        client.message(uid)
      end
    end

    context 'when message does not exist' do
      before do
        allow(mock_imap).to receive(:uid_fetch).and_return(nil)
      end

      it 'returns nil' do
        expect(client.message(uid)).to be_nil
      end
    end
  end
end