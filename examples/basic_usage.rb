#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic usage example of PecDecoder gem

require_relative '../lib/pec_ruby'

# Configuration (modify with your data)
HOST = 'imaps.pec.aruba.it'
USERNAME = 'your@domain.pec.it'
PASSWORD = 'password'

begin
  puts "Connecting to PEC server..."
  
  # Create and connect client
  client = PecRuby::Client.new(
    host: HOST,
    username: USERNAME,
    password: PASSWORD
  )
  client.connect
  
  puts "Connected as: #{client.username}"
  
  # Retrieve last 5 PEC messages
  puts "\nRetrieving PEC messages..."
  pec_messages = client.pec_messages(limit: 5)
  
  puts "Found #{pec_messages.size} PEC messages\n"
  
  pec_messages.each_with_index do |message, i|
    puts "─" * 60
    puts "MESSAGE #{i + 1}"
    puts "─" * 60
    
    # PEC container information
    puts "PEC Container:"
    puts "   Subject: #{message.subject}"
    puts "   From: #{message.from}"
    puts "   Date: #{message.date&.strftime('%d/%m/%Y %H:%M')}"
    
    # Original message information
    if message.has_postacert?
      puts "\nOriginal message:"
      puts "   Subject: #{message.original_subject}"
      puts "   From: #{message.original_from}"
      puts "   To: #{message.original_to.join(', ')}"
      puts "   Date: #{message.original_date&.strftime('%d/%m/%Y %H:%M')}"
      
      # Message body (first 200 characters)
      body = message.original_body
      if body && !body.strip.empty?
        preview = body.strip[0..200]
        preview += "..." if body.length > 200
        puts "\nBody preview:"
        puts "   #{preview.gsub("\n", "\n   ")}"
      end
      
      # Attachments
      attachments = message.original_attachments
      if attachments.any?
        puts "\nAttachments (#{attachments.size}):"
        attachments.each do |att|
          puts "   - #{att.filename} (#{att.size_kb} KB)"
        end
      end
    else
      puts "\nWARNING: No postacert.eml found"
    end
    
    puts
  end
  
  # Example: download attachments from first message
  if pec_messages.any? && pec_messages.first.original_attachments.any?
    puts "\nExample: downloading attachments from first message..."
    
    message = pec_messages.first
    download_dir = "./downloads"
    
    require 'fileutils'
    FileUtils.mkdir_p(download_dir)
    
    message.original_attachments.each do |attachment|
      file_path = attachment.save_to_dir(download_dir)
      puts "Saved: #{file_path}"
    end
  end
  
rescue PecRuby::Error => e
  puts "PEC error: #{e.message}"
rescue => e
  puts "Generic error: #{e.message}"
ensure
  # Always disconnect
  if client
    client.disconnect
    puts "\nDisconnected from server"
  end
end

puts "\nExample completed!"