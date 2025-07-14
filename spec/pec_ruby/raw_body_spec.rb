require 'spec_helper'

RSpec.describe "PecRuby::Message Raw Body Methods" do
  let(:client) { double("client") }
  let(:envelope) { double("envelope") }
  let(:bodystructure) { double("bodystructure") }
  let(:fetch_data) { double("fetch_data", attr: { "UID" => 123, "ENVELOPE" => envelope, "BODYSTRUCTURE" => bodystructure }) }
  let(:message) { PecRuby::Message.new(client, fetch_data) }

  describe "raw_body methods" do
    context "when message has postacert.eml" do
      before do
        allow(message).to receive(:has_postacert?).and_return(true)
        allow(message).to receive(:postacert_body).and_return({content: "postacert body", content_type: "text/plain", charset: "UTF-8"})
        allow(message).to receive(:postacert_body_text).and_return("postacert text")
        allow(message).to receive(:postacert_body_html).and_return("postacert html")
      end

      it "raw_body returns postacert_body" do
        expect(message.raw_body).to eq(message.postacert_body)
      end

      it "raw_body_text returns postacert_body_text" do
        expect(message.raw_body_text).to eq(message.postacert_body_text)
      end

      it "raw_body_html returns postacert_body_html" do
        expect(message.raw_body_html).to eq(message.postacert_body_html)
      end
    end

    context "when message has no postacert.eml" do
      let(:mail) { double("mail") }
      let(:text_part) { double("text_part", body: double(decoded: "direct text"), mime_type: "text/plain", charset: "UTF-8", content_type_parameters: nil) }
      let(:html_part) { double("html_part", body: double(decoded: "direct html"), mime_type: "text/html", charset: "UTF-8", content_type_parameters: nil) }

      before do
        allow(message).to receive(:has_postacert?).and_return(false)
        allow(client).to receive(:fetch_body_part).with(123, "").and_return("raw message data")
        allow(Mail).to receive(:read_from_string).with("raw message data").and_return(mail)
        allow(message).to receive(:extract_text_part).with(mail, "text/plain").and_return(text_part)
        allow(message).to receive(:extract_text_part).with(mail, "text/html").and_return(html_part)
      end

      it "raw_body returns direct message body" do
        result = message.raw_body
        expect(result).to eq({
          content: "direct text",
          content_type: "text/plain",
          charset: "UTF-8"
        })
      end

      it "raw_body_text returns direct message text" do
        expect(message.raw_body_text).to eq("direct text")
      end

      it "raw_body_html returns direct message html" do
        expect(message.raw_body_html).to eq("direct html")
      end
    end
  end

  describe "direct message methods" do
    let(:mail) { double("mail") }
    let(:text_part) { double("text_part", body: double(decoded: "direct text"), mime_type: "text/plain", charset: "UTF-8", content_type_parameters: nil) }

    before do
      allow(client).to receive(:fetch_body_part).with(123, "").and_return("raw message data")
      allow(Mail).to receive(:read_from_string).with("raw message data").and_return(mail)
      allow(message).to receive(:extract_text_part).with(mail, "text/plain").and_return(text_part)
      allow(message).to receive(:extract_text_part).with(mail, "text/html").and_return(nil)
    end

    it "direct_message_body returns parsed body" do
      result = message.send(:direct_message_body)
      expect(result).to eq({
        content: "direct text",
        content_type: "text/plain",
        charset: "UTF-8"
      })
    end

    it "direct_message_body_text returns text content" do
      result = message.send(:direct_message_body_text)
      expect(result).to eq("direct text")
    end

    it "direct_message_mail is memoized" do
      expect(client).to receive(:fetch_body_part).once.and_return("raw message data")
      expect(Mail).to receive(:read_from_string).once.and_return(mail)
      
      # First call
      message.send(:direct_message_mail)
      # Second call should use memoized result
      message.send(:direct_message_mail)
    end
  end
end