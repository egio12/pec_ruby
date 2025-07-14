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

  describe '#has_postacert?' do
    context 'when no postacert part exists' do
      before { allow(message).to receive(:find_postacert_part_ids).and_return([]) }

      it 'returns false' do
        expect(message.has_postacert?).to be false
      end
    end

    context 'when postacert part exists' do
      before { allow(message).to receive(:find_postacert_part_ids).and_return(['1']) }

      it 'returns true' do
        expect(message.has_postacert?).to be true
      end
    end
  end

  describe 'Ruby Way behavior - subject/from/to/date methods' do
    let(:outer_subject) { 'POSTA CERTIFICATA: Outer Subject' }
    let(:outer_from) { double('from', name: 'Outer Sender', mailbox: 'outer', host: 'example.com') }
    let(:outer_to) { [double('to', mailbox: 'recipient', host: 'example.com')] }
    let(:outer_date) { Time.parse('2023-01-01 10:00:00') }
    
    let(:inner_subject) { 'Inner Subject' }
    let(:inner_from) { ['inner@example.com'] }
    let(:inner_to) { ['inner_recipient@example.com'] }
    let(:inner_date) { Time.parse('2023-01-01 12:00:00') }

    before do
      # Mock envelope (outer message)
      allow(envelope).to receive(:subject).and_return(outer_subject)
      allow(envelope).to receive(:from).and_return([outer_from])
      allow(envelope).to receive(:to).and_return(outer_to)
      allow(envelope).to receive(:date).and_return(outer_date)
      
      # Mock Mail::Encodings
      allow(Mail::Encodings).to receive(:value_decode).with(outer_subject).and_return(outer_subject)
      allow(message).to receive(:extract_real_sender).with(outer_from).and_return('outer@example.com')
    end

    context 'when message has postacert.eml' do
      let(:postacert_mail) do
        double('postacert_mail',
          subject: inner_subject,
          from: inner_from,
          to: inner_to,
          date: inner_date
        )
      end

      before do
        allow(message).to receive(:has_postacert?).and_return(true)
        allow(message).to receive(:postacert_message).and_return(postacert_mail)
      end

      it 'subject returns postacert.eml subject' do
        expect(message.subject).to eq(inner_subject)
      end

      it 'from returns postacert.eml from' do
        expect(message.from).to eq(inner_from.first)
      end

      it 'to returns postacert.eml to' do
        expect(message.to).to eq(inner_to)
      end

      it 'date returns postacert.eml date' do
        expect(message.date).to eq(inner_date)
      end

      it 'original_subject returns envelope subject (cleaned)' do
        expect(message.original_subject).to eq('Outer Subject')
      end

      it 'original_from returns envelope from' do
        expect(message.original_from).to eq('outer@example.com')
      end

      it 'original_to returns envelope to' do
        expect(message.original_to).to eq(['recipient@example.com'])
      end

      it 'original_date returns envelope date' do
        expect(message.original_date).to eq(outer_date)
      end
    end

    context 'when message has no postacert.eml' do
      before do
        allow(message).to receive(:has_postacert?).and_return(false)
        allow(message).to receive(:postacert_message).and_return(nil)
      end

      it 'subject returns envelope subject (cleaned)' do
        expect(message.subject).to eq('Outer Subject')
      end

      it 'from returns envelope from' do
        expect(message.from).to eq('outer@example.com')
      end

      it 'to returns envelope to' do
        expect(message.to).to eq(['recipient@example.com'])
      end

      it 'date returns envelope date' do
        expect(message.date).to eq(outer_date)
      end

      it 'original_subject returns same as subject' do
        expect(message.original_subject).to eq(message.subject)
      end

      it 'original_from returns same as from' do
        expect(message.original_from).to eq(message.from)
      end

      it 'original_to returns same as to' do
        expect(message.original_to).to eq(message.to)
      end

      it 'original_date returns same as date' do
        expect(message.original_date).to eq(message.date)
      end
    end
  end

  describe '#postacert_message' do
    context 'when no postacert exists' do
      before { allow(message).to receive(:find_postacert_part_ids).and_return([]) }

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
      let(:raw_postacert_data) { 'raw email data' }
      let(:postacert_mail) { double('postacert_mail') }

      before do
        allow(message).to receive(:find_postacert_part_ids).and_return(['1'])
        allow(client).to receive(:fetch_body_part).with(uid, '1').and_return(raw_postacert_data)
        allow(Mail).to receive(:read_from_string).with(raw_postacert_data).and_return(postacert_mail)
      end

      it 'fetches and parses the postacert email' do
        expect(message.postacert_message).to eq(postacert_mail)
      end

      it 'caches the result' do
        expect(client).to receive(:fetch_body_part).once
        message.postacert_message
        message.postacert_message
      end
    end

    context 'when parsing fails' do
      before do
        allow(message).to receive(:find_postacert_part_ids).and_return(['1'])
        allow(client).to receive(:fetch_body_part).and_raise(StandardError.new('Parse error'))
      end

      it 'raises PecRuby::Error' do
        expect { message.postacert_message }.to raise_error(PecRuby::Error, /Failed to extract postacert.eml/)
      end
    end
  end

  describe 'body methods' do
    let(:postacert_mail) { double('postacert_mail') }
    let(:text_part) { double('text_part', body: double(decoded: 'decoded content'), mime_type: 'text/plain', charset: 'UTF-8', content_type_parameters: nil) }
    let(:html_part) { double('html_part', body: double(decoded: '<p>decoded content</p>'), mime_type: 'text/html', charset: 'UTF-8', content_type_parameters: nil) }

    before do
      allow(message).to receive(:postacert_message).and_return(postacert_mail)
      allow(message).to receive(:extract_text_part).and_return(text_part)
    end

    describe '#postacert_body' do
      context 'when postacert message does not exist' do
        before { allow(message).to receive(:postacert_message).and_return(nil) }

        it 'returns nil' do
          expect(message.postacert_body).to be_nil
        end
      end

      context 'when postacert message has text/plain part' do
        before do
          allow(message).to receive(:extract_text_part).with(postacert_mail, 'text/plain').and_return(text_part)
          allow(message).to receive(:extract_text_part).with(postacert_mail, 'text/html').and_return(nil)
        end

        it 'returns hash with text content and metadata' do
          result = message.postacert_body
          expect(result[:content]).to eq('decoded content')
          expect(result[:content_type]).to eq('text/plain')
          expect(result[:charset]).to eq('UTF-8')
        end
      end

      context 'when postacert message has only HTML part' do
        before do
          allow(message).to receive(:extract_text_part).with(postacert_mail, 'text/plain').and_return(nil)
          allow(message).to receive(:extract_text_part).with(postacert_mail, 'text/html').and_return(html_part)
        end

        it 'returns hash with HTML content and metadata' do
          result = message.postacert_body
          expect(result[:content]).to eq('<p>decoded content</p>')
          expect(result[:content_type]).to eq('text/html')
          expect(result[:charset]).to eq('UTF-8')
        end
      end
    end

    describe '#postacert_body_text' do
      context 'when text part exists' do
        before do
          allow(message).to receive(:extract_text_part).with(postacert_mail, 'text/plain').and_return(text_part)
        end

        it 'returns plain text content' do
          expect(message.postacert_body_text).to eq('decoded content')
        end
      end

      context 'when text part does not exist' do
        before do
          allow(message).to receive(:extract_text_part).with(postacert_mail, 'text/plain').and_return(nil)
        end

        it 'returns nil' do
          expect(message.postacert_body_text).to be_nil
        end
      end
    end

    describe '#postacert_body_html' do
      context 'when HTML part exists' do
        before do
          allow(message).to receive(:extract_text_part).with(postacert_mail, 'text/html').and_return(html_part)
        end

        it 'returns HTML content' do
          expect(message.postacert_body_html).to eq('<p>decoded content</p>')
        end
      end

      context 'when HTML part does not exist' do
        before do
          allow(message).to receive(:extract_text_part).with(postacert_mail, 'text/html').and_return(nil)
        end

        it 'returns nil' do
          expect(message.postacert_body_html).to be_nil
        end
      end
    end
  end

  describe 'attachment methods' do
    let(:postacert_mail) { double('postacert_mail') }
    let(:mail_attachment) { double('mail_attachment') }
    let(:attachment) { instance_double(PecRuby::Attachment) }
    let(:regular_attachment) { instance_double(PecRuby::Attachment, postacert?: false) }
    let(:postacert_attachment) { instance_double(PecRuby::Attachment, postacert?: true) }

    before do
      allow(message).to receive(:postacert_message).and_return(postacert_mail)
      allow(message).to receive(:nested_postacert_attachments).and_return([])
    end

    describe '#postacert_attachments' do
      context 'when postacert message has no attachments' do
        before { allow(postacert_mail).to receive(:attachments).and_return(nil) }

        it 'returns empty array' do
          expect(message.postacert_attachments).to eq([])
        end
      end

      context 'when postacert message has attachments' do
        before do
          allow(postacert_mail).to receive(:attachments).and_return([mail_attachment])
          allow(PecRuby::Attachment).to receive(:new).with(mail_attachment).and_return(attachment)
        end

        it 'returns array of Attachment objects' do
          expect(message.postacert_attachments).to eq([attachment])
        end
      end
    end

    describe '#nested_postacerts' do
      before { allow(message).to receive(:postacert_attachments).and_return([regular_attachment, postacert_attachment]) }

      it 'returns only postacert attachments' do
        expect(message.nested_postacerts).to eq([postacert_attachment])
      end
    end

    describe '#postacert_regular_attachments' do
      before { allow(message).to receive(:postacert_attachments).and_return([regular_attachment, postacert_attachment]) }

      it 'returns only non-postacert attachments' do
        expect(message.postacert_regular_attachments).to eq([regular_attachment])
      end
    end

    describe '#has_nested_postacerts?' do
      context 'when has nested postacerts' do
        before { allow(message).to receive(:nested_postacerts).and_return([postacert_attachment]) }

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
      let(:nested_message) { double('nested_message') }

      before do
        allow(message).to receive(:nested_postacerts).and_return([postacert_attachment])
        allow(postacert_attachment).to receive(:as_postacert_message).and_return(nested_message)
      end

      it 'returns parsed nested postacert messages' do
        expect(message.nested_postacert_messages).to eq([nested_message])
      end
    end

    describe '#all_postacert_messages' do
      let(:nested_message) { double('nested_message', has_nested_postacerts?: false) }

      before do
        allow(message).to receive(:nested_postacert_messages).and_return([nested_message])
      end

      it 'returns flattened array of all postacert messages' do
        result = message.all_postacert_messages
        expect(result).to be_an(Array)
        expect(result).not_to be_empty
      end
    end
  end

  describe 'backward compatibility methods' do
    let(:postacert_attachments) { [double('attachment')] }
    let(:postacert_body) { { content: 'body', content_type: 'text/plain', charset: 'UTF-8' } }

    before do
      allow(message).to receive(:postacert_attachments).and_return(postacert_attachments)
      allow(message).to receive(:postacert_body).and_return(postacert_body)
      allow(message).to receive(:postacert_body_text).and_return('text')
      allow(message).to receive(:postacert_body_html).and_return('<p>html</p>')
    end

    it 'original_attachments delegates to postacert_attachments' do
      expect(message.original_attachments).to eq(postacert_attachments)
    end

    it 'original_body delegates to postacert_body' do
      expect(message.original_body).to eq(postacert_body)
    end

    it 'original_body_text delegates to postacert_body_text' do
      expect(message.original_body_text).to eq('text')
    end

    it 'original_body_html delegates to postacert_body_html' do
      expect(message.original_body_html).to eq('<p>html</p>')
    end
  end

  describe '#summary' do
    before do
      allow(message).to receive(:subject).and_return('Test Subject')
      allow(message).to receive(:from).and_return('sender@example.com')
      allow(message).to receive(:to).and_return(['recipient@example.com'])
      allow(message).to receive(:date).and_return(Time.parse('2023-01-01'))
      allow(message).to receive(:has_postacert?).and_return(true)
      allow(message).to receive(:postacert_attachments).and_return([])
      allow(message).to receive(:nested_postacerts).and_return([])
      allow(message).to receive(:nested_postacert_messages).and_return([])
      allow(message).to receive(:original_subject).and_return('Test Subject')
      allow(message).to receive(:original_from).and_return('sender@example.com')
      allow(message).to receive(:original_to).and_return(['recipient@example.com'])
      allow(message).to receive(:original_date).and_return(Time.parse('2023-01-01'))
    end

    it 'returns a hash with all message information including nested postacerts' do
      result = message.summary
      expect(result).to be_a(Hash)
      expect(result[:subject]).to eq('Test Subject')
      expect(result[:from]).to eq('sender@example.com')
      expect(result[:to]).to eq(['recipient@example.com'])
      expect(result[:has_postacert]).to be true
    end
  end
end