# frozen_string_literal: true

RSpec.describe PecRuby do
  it "has a version number" do
    expect(PecRuby::VERSION).not_to be nil
  end

  describe "error classes" do
    it "defines Error as base error class" do
      expect(PecRuby::Error).to be < StandardError
    end

    it "defines ConnectionError" do
      expect(PecRuby::ConnectionError).to be < PecRuby::Error
    end

    it "defines AuthenticationError" do
      expect(PecRuby::AuthenticationError).to be < PecRuby::Error
    end

    it "defines MessageNotFoundError" do
      expect(PecRuby::MessageNotFoundError).to be < PecRuby::Error
    end

    it "defines PostacertNotFoundError" do
      expect(PecRuby::PostacertNotFoundError).to be < PecRuby::Error
    end
  end
end