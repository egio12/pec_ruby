# frozen_string_literal: true

require 'tempfile'

RSpec.describe PecRuby::Attachment do
  let(:mail_attachment) { double('mail_attachment') }
  let(:attachment) { described_class.new(mail_attachment) }

  describe '#initialize' do
    it 'stores the mail attachment' do
      expect(attachment.mail_attachment).to eq(mail_attachment)
    end
  end

  describe '#filename' do
    context 'when mail attachment has filename' do
      before { allow(mail_attachment).to receive(:filename).and_return('test.pdf') }

      it 'returns the filename' do
        expect(attachment.filename).to eq('test.pdf')
      end
    end

    context 'when mail attachment has no filename' do
      before { allow(mail_attachment).to receive(:filename).and_return(nil) }

      it 'returns default filename' do
        expect(attachment.filename).to eq('unnamed_file')
      end
    end
  end

  describe '#mime_type' do
    context 'when mail attachment has mime_type' do
      before { allow(mail_attachment).to receive(:mime_type).and_return('application/pdf') }

      it 'returns the mime_type' do
        expect(attachment.mime_type).to eq('application/pdf')
      end
    end

    context 'when mail attachment has no mime_type' do
      before { allow(mail_attachment).to receive(:mime_type).and_return(nil) }

      it 'returns default mime_type' do
        expect(attachment.mime_type).to eq('application/octet-stream')
      end
    end
  end

  describe '#content' do
    let(:content_data) { 'binary data content' }

    before { allow(mail_attachment).to receive(:decoded).and_return(content_data) }

    it 'returns decoded content' do
      expect(attachment.content).to eq(content_data)
    end
  end

  describe '#size' do
    let(:content_data) { 'test content' }

    before do
      allow(mail_attachment).to receive(:decoded).and_return(content_data)
    end

    it 'returns content size in bytes' do
      expect(attachment.size).to eq(content_data.bytesize)
    end
  end

  describe '#size_kb' do
    let(:content_data) { 'x' * 1536 } # 1.5 KB

    before do
      allow(mail_attachment).to receive(:decoded).and_return(content_data)
    end

    it 'returns size in KB rounded to 1 decimal' do
      expect(attachment.size_kb).to eq(1.5)
    end
  end

  describe '#size_mb' do
    let(:content_data) { 'x' * (1024 * 1024 * 2.5).to_i } # 2.5 MB

    before do
      allow(mail_attachment).to receive(:decoded).and_return(content_data)
    end

    it 'returns size in MB rounded to 2 decimals' do
      expect(attachment.size_mb).to eq(2.5)
    end
  end

  describe '#save_to' do
    let(:content_data) { 'test file content' }
    let(:temp_file) { Tempfile.new('rspec_test') }
    let(:file_path) { temp_file.path }

    before do
      allow(mail_attachment).to receive(:decoded).and_return(content_data)
      temp_file.close
    end

    after do
      temp_file.unlink if temp_file
    end

    it 'saves content to specified path' do
      attachment.save_to(file_path)
      expect(File.read(file_path)).to eq(content_data)
    end

    it 'writes in binary mode' do
      expect(File).to receive(:binwrite).with(file_path, content_data)
      attachment.save_to(file_path)
    end
  end

  describe '#save_to_dir' do
    let(:content_data) { 'test file content' }
    let(:filename) { 'test.txt' }
    let(:temp_dir) { Dir.mktmpdir('rspec_test') }

    before do
      allow(mail_attachment).to receive(:decoded).and_return(content_data)
      allow(mail_attachment).to receive(:filename).and_return(filename)
    end

    after do
      FileUtils.remove_entry(temp_dir) if Dir.exist?(temp_dir)
    end

    it 'saves file to directory with original filename' do
      result_path = attachment.save_to_dir(temp_dir)
      expected_path = File.join(temp_dir, filename)
      
      expect(result_path).to eq(expected_path)
      expect(File.read(expected_path)).to eq(content_data)
    end
  end

  describe '#summary' do
    before do
      allow(mail_attachment).to receive(:filename).and_return('test.pdf')
      allow(mail_attachment).to receive(:mime_type).and_return('application/pdf')
      allow(mail_attachment).to receive(:decoded).and_return('x' * 1024)
    end

    it 'returns hash with attachment details' do
      summary = attachment.summary
      
      expect(summary).to be_a(Hash)
      expect(summary[:filename]).to eq('test.pdf')
      expect(summary[:mime_type]).to eq('application/pdf')
      expect(summary[:size]).to eq(1024)
      expect(summary[:size_kb]).to eq(1.0)
      expect(summary[:size_mb]).to eq(0.0)
    end
  end

  describe '#to_s' do
    before do
      allow(mail_attachment).to receive(:filename).and_return('document.pdf')
      allow(mail_attachment).to receive(:mime_type).and_return('application/pdf')
      allow(mail_attachment).to receive(:decoded).and_return('x' * 2048)
    end

    it 'returns formatted string representation' do
      expect(attachment.to_s).to eq('document.pdf (application/pdf, 2.0 KB)')
    end
  end

  describe '#postacert?' do
    context 'when filename contains postacert.eml' do
      before { allow(mail_attachment).to receive(:filename).and_return('postacert.eml') }

      it 'returns true' do
        expect(attachment.postacert?).to be true
      end
    end

    context 'when filename ends with .eml and mime_type contains message' do
      before do
        allow(mail_attachment).to receive(:filename).and_return('forwarded.eml')
        allow(mail_attachment).to receive(:mime_type).and_return('message/rfc822')
      end

      it 'returns true' do
        expect(attachment.postacert?).to be true
      end
    end

    context 'when filename is regular attachment' do
      before do
        allow(mail_attachment).to receive(:filename).and_return('document.pdf')
        allow(mail_attachment).to receive(:mime_type).and_return('application/pdf')
      end

      it 'returns false' do
        expect(attachment.postacert?).to be false
      end
    end
  end

  describe '#as_postacert_message' do
    context 'when attachment is not a postacert' do
      before do
        allow(attachment).to receive(:postacert?).and_return(false)
      end

      it 'returns nil' do
        expect(attachment.as_postacert_message).to be_nil
      end
    end

    context 'when attachment is a postacert' do
      let(:email_content) { "From: sender@example.com\r\nTo: recipient@example.com\r\nSubject: Test\r\n\r\nBody content" }
      let(:nested_mail) { double('Mail') }

      before do
        allow(attachment).to receive(:postacert?).and_return(true)
        allow(mail_attachment).to receive(:decoded).and_return(email_content)
        allow(Mail).to receive(:read_from_string).with(email_content).and_return(nested_mail)
      end

      it 'returns a NestedPostacertMessage' do
        result = attachment.as_postacert_message
        expect(result).to be_a(PecRuby::NestedPostacertMessage)
        expect(result.mail).to eq(nested_mail)
      end
    end

    context 'when parsing fails' do
      before do
        allow(attachment).to receive(:postacert?).and_return(true)
        allow(mail_attachment).to receive(:decoded).and_raise(StandardError, "Parse error")
      end

      it 'raises PecRuby::Error' do
        expect { attachment.as_postacert_message }.to raise_error(PecRuby::Error, /Failed to parse nested postacert.eml/)
      end
    end
  end
end

RSpec.describe PecRuby::NestedPostacertMessage do
  let(:mail) { double('Mail') }
  let(:nested_message) { described_class.new(mail) }

  describe '#initialize' do
    it 'stores the mail object' do
      expect(nested_message.mail).to eq(mail)
    end
  end

  describe '#subject' do
    before { allow(mail).to receive(:subject).and_return('Test Subject') }

    it 'returns mail subject' do
      expect(nested_message.subject).to eq('Test Subject')
    end
  end

  describe '#from' do
    before { allow(mail).to receive(:from).and_return(['sender@example.com']) }

    it 'returns first from address' do
      expect(nested_message.from).to eq('sender@example.com')
    end
  end

  describe '#to' do
    before { allow(mail).to receive(:to).and_return(['recipient1@example.com', 'recipient2@example.com']) }

    it 'returns to addresses array' do
      expect(nested_message.to).to eq(['recipient1@example.com', 'recipient2@example.com'])
    end
  end

  describe '#date' do
    let(:date) { Time.now }
    before { allow(mail).to receive(:date).and_return(date) }

    it 'returns mail date' do
      expect(nested_message.date).to eq(date)
    end
  end

  describe '#attachments' do
    context 'when mail has no attachments' do
      before { allow(mail).to receive(:attachments).and_return(nil) }

      it 'returns empty array' do
        expect(nested_message.attachments).to eq([])
      end
    end

    context 'when mail has attachments' do
      let(:mail_attachment) { double('mail_attachment') }
      let(:attachment) { instance_double(PecRuby::Attachment) }

      before do
        allow(mail).to receive(:attachments).and_return([mail_attachment])
        allow(PecRuby::Attachment).to receive(:new).with(mail_attachment).and_return(attachment)
      end

      it 'returns array of Attachment objects' do
        expect(nested_message.attachments).to eq([attachment])
      end
    end
  end

  describe '#nested_postacerts' do
    let(:postacert_attachment) { instance_double(PecRuby::Attachment, postacert?: true) }
    let(:regular_attachment) { instance_double(PecRuby::Attachment, postacert?: false) }

    before do
      allow(nested_message).to receive(:attachments).and_return([postacert_attachment, regular_attachment])
    end

    it 'returns only postacert attachments' do
      expect(nested_message.nested_postacerts).to eq([postacert_attachment])
    end
  end

  describe '#has_nested_postacerts?' do
    context 'when has nested postacerts' do
      before { allow(nested_message).to receive(:nested_postacerts).and_return([double]) }

      it 'returns true' do
        expect(nested_message.has_nested_postacerts?).to be true
      end
    end

    context 'when has no nested postacerts' do
      before { allow(nested_message).to receive(:nested_postacerts).and_return([]) }

      it 'returns false' do
        expect(nested_message.has_nested_postacerts?).to be false
      end
    end
  end
end