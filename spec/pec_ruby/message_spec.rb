# frozen_string_literal: true

require 'ostruct'

RSpec.describe PecRuby::Message do
  let(:client) { instance_double(PecRuby::Client) }
  let(:uid) { 123 }
  let(:envelope) { double('envelope') }
  let(:bodystructure) { double('bodystructure') }
  let(:fetch_data) do
    double('fetch_data', attr: {
      'UID' => uid,
      'ENVELOPE' => envelope,
      'BODYSTRUCTURE' => bodystructure
    })
  end
  let(:message) { described_class.new(client, fetch_data) }

  describe '#initialize' do
    it 'sets the client, uid, envelope, and bodystructure' do
      expect(message.client).to eq(client)
      expect(message.uid).to eq(uid)
      expect(message.envelope).to eq(envelope)
      expect(message.bodystructure).to eq(bodystructure)
    end
  end

  describe '#subject' do
    context 'when envelope has no subject' do
      before { allow(envelope).to receive(:subject).and_return(nil) }

      it 'returns nil' do
        expect(message.subject).to be_nil
      end
    end

    context 'when envelope has a subject' do
      let(:raw_subject) { 'Test Subject' }

      before do
        allow(envelope).to receive(:subject).and_return(raw_subject)
        allow(Mail::Encodings).to receive(:value_decode).with(raw_subject).and_return(raw_subject)
      end

      it 'returns the decoded subject' do
        expect(message.subject).to eq('Test Subject')
      end

      context 'when subject starts with POSTA CERTIFICATA:' do
        let(:raw_subject) { 'POSTA CERTIFICATA: Test Subject' }

        before do
          allow(Mail::Encodings).to receive(:value_decode).with(raw_subject).and_return(raw_subject)
        end

        it 'removes the POSTA CERTIFICATA: prefix' do
          expect(message.subject).to eq('Test Subject')
        end
      end
    end
  end

  describe '#from' do
    context 'when envelope has no from address' do
      before { allow(envelope).to receive(:from).and_return(nil) }

      it 'returns nil' do
        expect(message.from).to be_nil
      end
    end

    context 'when envelope has from address' do
      let(:from_addr) { double('from_addr', mailbox: 'test', host: 'example.com', name: nil) }

      before { allow(envelope).to receive(:from).and_return([from_addr]) }

      it 'returns the email address' do
        expect(message.from).to eq('test@example.com')
      end

      context 'when from address has "Per conto di:" in name' do
        let(:from_addr) do
          double('from_addr', 
            mailbox: 'pec', 
            host: 'example.com', 
            name: 'Per conto di: real@sender.com'
          )
        end

        it 'extracts the real sender email' do
          expect(message.from).to eq('real@sender.com')
        end
      end
    end
  end

  describe '#to' do
    context 'when envelope has no to addresses' do
      before { allow(envelope).to receive(:to).and_return(nil) }

      it 'returns empty array' do
        expect(message.to).to eq([])
      end
    end

    context 'when envelope has to addresses' do
      let(:to_addrs) do
        [
          double('addr1', mailbox: 'user1', host: 'example.com'),
          double('addr2', mailbox: 'user2', host: 'example.org')
        ]
      end

      before { allow(envelope).to receive(:to).and_return(to_addrs) }

      it 'returns array of email addresses' do
        expect(message.to).to eq(['user1@example.com', 'user2@example.org'])
      end
    end
  end

  describe '#date' do
    context 'when envelope has no date' do
      before { allow(envelope).to receive(:date).and_return(nil) }

      it 'returns nil' do
        expect(message.date).to be_nil
      end
    end

    context 'when envelope has date' do
      let(:date_string) { "Wed, 01 Jan 2020 12:00:00 +0000" }

      before { allow(envelope).to receive(:date).and_return(date_string) }

      it 'returns parsed Time object' do
        result = message.date
        expect(result).to be_a(Time)
        expect(result.year).to eq(2020)
      end
    end
  end

  describe '#has_postacert?' do
    context 'when no postacert part exists' do
      before do
        allow(message).to receive(:find_postacert_part_ids).and_return([])
      end

      it 'returns false' do
        expect(message.has_postacert?).to be false
      end
    end

    context 'when postacert part exists' do
      before do
        allow(message).to receive(:find_postacert_part_ids).and_return(['1.2'])
      end

      it 'returns true' do
        expect(message.has_postacert?).to be true
      end
    end
  end

  describe '#postacert_message' do
    context 'when no postacert exists' do
      before do
        allow(message).to receive(:find_postacert_part_ids).and_return([])
      end

      it 'returns nil' do
        expect(message.postacert_message).to be_nil
      end

      it 'caches the result' do
        expect(message).to receive(:find_postacert_part_ids).once
        message.postacert_message
        message.postacert_message
      end
    end

    context 'when postacert exists' do
      let(:raw_email_data) { "From: test@example.com\r\nTo: user@example.com\r\nSubject: Test\r\n\r\nBody" }
      let(:mail_object) { double('Mail') }

      before do
        allow(message).to receive(:find_postacert_part_ids).and_return(['1.2'])
        allow(client).to receive(:fetch_body_part).with(uid, '1.2').and_return(raw_email_data)
        allow(Mail).to receive(:read_from_string).with(raw_email_data).and_return(mail_object)
      end

      it 'fetches and parses the postacert email' do
        expect(message.postacert_message).to eq(mail_object)
      end

      it 'caches the result' do
        expect(client).to receive(:fetch_body_part).once
        message.postacert_message
        message.postacert_message
      end
    end

    context 'when parsing fails' do
      before do
        allow(message).to receive(:find_postacert_part_ids).and_return(['1.2'])
        allow(client).to receive(:fetch_body_part).and_raise(StandardError, "Parse error")
      end

      it 'raises PecRuby::Error' do
        expect { message.postacert_message }.to raise_error(PecRuby::Error, /Failed to extract postacert.eml/)
      end
    end
  end

  describe '#original_subject' do
    context 'when postacert message exists' do
      let(:postacert_mail) { double('Mail', subject: 'Original Subject') }

      before do
        allow(message).to receive(:postacert_message).and_return(postacert_mail)
      end

      it 'returns the original subject' do
        expect(message.original_subject).to eq('Original Subject')
      end
    end

    context 'when postacert message does not exist' do
      before do
        allow(message).to receive(:postacert_message).and_return(nil)
      end

      it 'returns nil' do
        expect(message.original_subject).to be_nil
      end
    end
  end

  describe '#original_attachments' do
    context 'when postacert message has no attachments' do
      let(:postacert_mail) { double('Mail', attachments: nil) }

      before do
        allow(message).to receive(:postacert_message).and_return(postacert_mail)
      end

      it 'returns empty array' do
        expect(message.original_attachments).to eq([])
      end
    end

    context 'when postacert message has attachments' do
      let(:mail_attachment) { double('mail_attachment') }
      let(:postacert_mail) { double('Mail', attachments: [mail_attachment]) }
      let(:attachment) { instance_double(PecRuby::Attachment) }

      before do
        allow(message).to receive(:postacert_message).and_return(postacert_mail)
        allow(PecRuby::Attachment).to receive(:new).with(mail_attachment).and_return(attachment)
      end

      it 'returns array of Attachment objects' do
        expect(message.original_attachments).to eq([attachment])
      end
    end
  end

  describe '#original_body' do
    context 'when postacert message does not exist' do
      before do
        allow(message).to receive(:postacert_message).and_return(nil)
      end

      it 'returns nil' do
        expect(message.original_body).to be_nil
      end
    end

    context 'when postacert message has text/plain part' do
      let(:text_part) { double('text_part', mime_type: 'text/plain', charset: 'UTF-8') }
      let(:html_part) { double('html_part', mime_type: 'text/html') }
      let(:postacert_mail) { double('Mail') }
      let(:body_content) { 'Plain text content' }

      before do
        allow(message).to receive(:postacert_message).and_return(postacert_mail)
        allow(message).to receive(:extract_text_part).with(postacert_mail, 'text/plain').and_return(text_part)
        allow(message).to receive(:extract_text_part).with(postacert_mail, 'text/html').and_return(html_part)
        allow(text_part).to receive_message_chain(:body, :decoded).and_return(body_content)
        allow(text_part).to receive(:content_type_parameters).and_return(nil)
      end

      it 'returns hash with text content and metadata' do
        result = message.original_body
        expect(result).to be_a(Hash)
        expect(result[:content]).to eq(body_content)
        expect(result[:content_type]).to eq('text/plain')
        expect(result[:charset]).to eq('UTF-8')
      end
    end

    context 'when postacert message has only HTML part' do
      let(:html_part) { double('html_part', mime_type: 'text/html', charset: 'ISO-8859-1') }
      let(:postacert_mail) { double('Mail') }
      let(:body_content) { '<p>HTML content</p>' }

      before do
        allow(message).to receive(:postacert_message).and_return(postacert_mail)
        allow(message).to receive(:extract_text_part).with(postacert_mail, 'text/plain').and_return(nil)
        allow(message).to receive(:extract_text_part).with(postacert_mail, 'text/html').and_return(html_part)
        allow(html_part).to receive_message_chain(:body, :decoded).and_return(body_content)
        allow(html_part).to receive(:content_type_parameters).and_return(nil)
      end

      it 'returns hash with HTML content and metadata' do
        result = message.original_body
        expect(result).to be_a(Hash)
        expect(result[:content]).to eq(body_content)
        expect(result[:content_type]).to eq('text/html')
        expect(result[:charset]).to eq('ISO-8859-1')
      end
    end
  end

  describe '#original_body_text' do
    context 'when text part exists' do
      let(:text_part) { double('text_part', charset: 'UTF-8') }
      let(:postacert_mail) { double('Mail') }
      let(:body_content) { 'Plain text content' }

      before do
        allow(message).to receive(:postacert_message).and_return(postacert_mail)
        allow(message).to receive(:extract_text_part).with(postacert_mail, 'text/plain').and_return(text_part)
        allow(text_part).to receive_message_chain(:body, :decoded).and_return(body_content)
        allow(text_part).to receive(:content_type_parameters).and_return(nil)
      end

      it 'returns plain text content' do
        expect(message.original_body_text).to eq(body_content)
      end
    end

    context 'when text part does not exist' do
      before do
        allow(message).to receive(:postacert_message).and_return(double('Mail'))
        allow(message).to receive(:extract_text_part).with(anything, 'text/plain').and_return(nil)
      end

      it 'returns nil' do
        expect(message.original_body_text).to be_nil
      end
    end
  end

  describe '#original_body_html' do
    context 'when HTML part exists' do
      let(:html_part) { double('html_part', charset: 'UTF-8') }
      let(:postacert_mail) { double('Mail') }
      let(:body_content) { '<p>HTML content</p>' }

      before do
        allow(message).to receive(:postacert_message).and_return(postacert_mail)
        allow(message).to receive(:extract_text_part).with(postacert_mail, 'text/html').and_return(html_part)
        allow(html_part).to receive_message_chain(:body, :decoded).and_return(body_content)
        allow(html_part).to receive(:content_type_parameters).and_return(nil)
      end

      it 'returns HTML content' do
        expect(message.original_body_html).to eq(body_content)
      end
    end

    context 'when HTML part does not exist' do
      before do
        allow(message).to receive(:postacert_message).and_return(double('Mail'))
        allow(message).to receive(:extract_text_part).with(anything, 'text/html').and_return(nil)
      end

      it 'returns nil' do
        expect(message.original_body_html).to be_nil
      end
    end
  end

  describe '#nested_postacerts' do
    let(:postacert_attachment) { instance_double(PecRuby::Attachment, postacert?: true) }
    let(:regular_attachment) { instance_double(PecRuby::Attachment, postacert?: false) }

    before do
      allow(message).to receive(:original_attachments).and_return([postacert_attachment, regular_attachment])
    end

    it 'returns only postacert attachments' do
      expect(message.nested_postacerts).to eq([postacert_attachment])
    end
  end

  describe '#original_regular_attachments' do
    let(:postacert_attachment) { instance_double(PecRuby::Attachment, postacert?: true) }
    let(:regular_attachment) { instance_double(PecRuby::Attachment, postacert?: false) }

    before do
      allow(message).to receive(:original_attachments).and_return([postacert_attachment, regular_attachment])
    end

    it 'returns only non-postacert attachments' do
      expect(message.original_regular_attachments).to eq([regular_attachment])
    end
  end

  describe '#has_nested_postacerts?' do
    context 'when has nested postacerts' do
      before { allow(message).to receive(:nested_postacerts).and_return([double]) }

      it 'returns true' do
        expect(message.has_nested_postacerts?).to be true
      end
    end

    context 'when has no nested postacerts' do
      before { allow(message).to receive(:nested_postacerts).and_return([]) }

      it 'returns false' do
        expect(message.has_nested_postacerts?).to be false
      end
    end
  end

  describe '#nested_postacert_messages' do
    let(:postacert_attachment) { instance_double(PecRuby::Attachment) }
    let(:nested_message) { instance_double(PecRuby::NestedPostacertMessage) }

    before do
      allow(message).to receive(:nested_postacerts).and_return([postacert_attachment])
      allow(postacert_attachment).to receive(:as_postacert_message).and_return(nested_message)
    end

    it 'returns parsed nested postacert messages' do
      expect(message.nested_postacert_messages).to eq([nested_message])
    end
  end

  describe '#all_postacert_messages' do
    let(:nested_message) { instance_double(PecRuby::NestedPostacertMessage, has_nested_postacerts?: false) }

    before do
      allow(message).to receive(:has_postacert?).and_return(true)
      allow(message).to receive(:nested_postacert_messages).and_return([nested_message])
    end

    it 'returns flattened array of all postacert messages' do
      result = message.all_postacert_messages
      
      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
      
      # Main postacert
      expect(result[0][:level]).to eq(0)
      expect(result[0][:type]).to eq(:main_postacert)
      expect(result[0][:message]).to eq(message)
      
      # Nested postacert
      expect(result[1][:level]).to eq(1)
      expect(result[1][:type]).to eq(:nested_postacert)
      expect(result[1][:message]).to eq(nested_message)
    end
  end

  describe '#summary' do
    before do
      allow(message).to receive(:subject).and_return('Test Subject')
      allow(message).to receive(:from).and_return('sender@example.com')
      allow(message).to receive(:to).and_return(['recipient@example.com'])
      allow(message).to receive(:date).and_return(Time.parse('2020-01-01'))
      allow(message).to receive(:has_postacert?).and_return(true)
      allow(message).to receive(:original_subject).and_return('Original Subject')
      allow(message).to receive(:original_from).and_return('original@example.com')
      allow(message).to receive(:original_to).and_return(['original_recipient@example.com'])
      allow(message).to receive(:original_date).and_return(Time.parse('2020-01-01'))
      allow(message).to receive(:original_attachments).and_return([double, double])
      allow(message).to receive(:original_regular_attachments).and_return([double])
      allow(message).to receive(:nested_postacerts).and_return([double])
      allow(message).to receive(:has_nested_postacerts?).and_return(true)
      allow(message).to receive(:all_postacert_messages).and_return([double, double])
    end

    it 'returns a hash with all message information including nested postacerts' do
      summary = message.summary
      expect(summary).to be_a(Hash)
      expect(summary[:uid]).to eq(uid)
      expect(summary[:subject]).to eq('Test Subject')
      expect(summary[:has_postacert]).to be true
      expect(summary[:attachments_count]).to eq(2)
      expect(summary[:regular_attachments_count]).to eq(1)
      expect(summary[:nested_postacerts_count]).to eq(1)
      expect(summary[:has_nested_postacerts]).to be true
      expect(summary[:total_postacert_messages]).to eq(2)
    end
  end
end