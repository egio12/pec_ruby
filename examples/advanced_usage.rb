#!/usr/bin/env ruby
# frozen_string_literal: true

# Advanced usage examples for PecDecoder gem

require_relative '../lib/pec_ruby'

# Configuration
HOST = 'imaps.pec.aruba.it'
USERNAME = 'your@domain.pec.it'
PASSWORD = 'password'

def example_error_handling
  puts "=== Error Handling Example ==="
  
  begin
    # Intentionally wrong credentials
    client = PecRuby::Client.new(
      host: HOST,
      username: 'wrong@email.com',
      password: 'wrongpassword'
    )
    client.connect
  rescue PecRuby::AuthenticationError => e
    puts "Authentication failed: #{e.message}"
  rescue PecRuby::ConnectionError => e
    puts "Connection failed: #{e.message}"
  rescue PecRuby::Error => e
    puts "General PEC error: #{e.message}"
  end
end

def example_message_filtering
  puts "\n=== Message Filtering Example ==="
  
  client = PecRuby::Client.new(
    host: HOST,
    username: USERNAME,
    password: PASSWORD
  )
  
  begin
    client.connect
    
    # Get all messages (not just PEC)
    all_messages = client.messages(limit: 20)
    pec_messages = client.pec_messages(limit: 20)
    
    puts "Total messages: #{all_messages.size}"
    puts "PEC messages (with postacert.eml): #{pec_messages.size}"
    puts "Non-PEC messages: #{all_messages.size - pec_messages.size}"
    
    # Filter by subject
    filtered = pec_messages.select do |msg|
      msg.original_subject&.downcase&.include?('invoice') ||
      msg.original_subject&.downcase&.include?('fattura')
    end
    
    puts "Messages with 'invoice/fattura' in subject: #{filtered.size}"
    
  ensure
    client&.disconnect
  end
end

def example_attachment_processing
  puts "\n=== Attachment Processing Example ==="
  
  client = PecRuby::Client.new(
    host: HOST,
    username: USERNAME,
    password: PASSWORD
  )
  
  begin
    client.connect
    pec_messages = client.pec_messages(limit: 10)
    
    # Statistics about attachments
    total_attachments = 0
    total_size = 0
    attachment_types = Hash.new(0)
    
    pec_messages.each do |message|
      attachments = message.original_attachments
      total_attachments += attachments.size
      
      attachments.each do |att|
        total_size += att.size
        extension = File.extname(att.filename).downcase
        attachment_types[extension] += 1
      end
    end
    
    puts "Attachment Statistics:"
    puts "  Total attachments: #{total_attachments}"
    puts "  Total size: #{(total_size / 1024.0 / 1024.0).round(2)} MB"
    puts "  Types distribution:"
    attachment_types.each do |ext, count|
      puts "    #{ext.empty? ? '(no extension)' : ext}: #{count}"
    end
    
    # Download only PDF files
    pdf_count = 0
    pec_messages.each do |message|
      message.original_attachments.each do |att|
        if att.filename.downcase.end_with?('.pdf')
          # Create organized directory structure
          date_dir = message.original_date&.strftime('%Y-%m') || 'unknown'
          download_dir = "./downloads/pdfs/#{date_dir}"
          
          require 'fileutils'
          FileUtils.mkdir_p(download_dir)
          
          file_path = att.save_to_dir(download_dir)
          puts "Downloaded PDF: #{file_path}"
          pdf_count += 1
        end
      end
    end
    
    puts "Downloaded #{pdf_count} PDF files"
    
  ensure
    client&.disconnect
  end
end

def example_message_analysis
  puts "\n=== Message Analysis Example ==="
  
  client = PecRuby::Client.new(
    host: HOST,
    username: USERNAME,
    password: PASSWORD
  )
  
  begin
    client.connect
    pec_messages = client.pec_messages(limit: 50)
    
    # Analyze senders
    senders = Hash.new(0)
    pec_messages.each do |msg|
      sender = msg.original_from
      senders[sender] += 1 if sender
    end
    
    puts "Top senders:"
    senders.sort_by { |_sender, count| -count }.first(5).each do |sender, count|
      puts "  #{sender}: #{count} messages"
    end
    
    # Analyze by month
    monthly_stats = Hash.new(0)
    pec_messages.each do |msg|
      if msg.original_date
        month_key = msg.original_date.strftime('%Y-%m')
        monthly_stats[month_key] += 1
      end
    end
    
    puts "\nMessages by month:"
    monthly_stats.sort.each do |month, count|
      puts "  #{month}: #{count} messages"
    end
    
    # Find messages with most attachments
    max_attachments = pec_messages.max_by { |msg| msg.original_attachments.size }
    if max_attachments
      puts "\nMessage with most attachments:"
      puts "  Subject: #{max_attachments.original_subject}"
      puts "  Attachments: #{max_attachments.original_attachments.size}"
    end
    
  ensure
    client&.disconnect
  end
end

def example_batch_download
  puts "\n=== Batch Download Example ==="
  
  client = PecRuby::Client.new(
    host: HOST,
    username: USERNAME,
    password: PASSWORD
  )
  
  begin
    client.connect
    pec_messages = client.pec_messages(limit: 20)
    
    # Create organized directory structure
    base_dir = "./downloads/batch_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
    
    pec_messages.each_with_index do |message, i|
      message_dir = File.join(base_dir, sprintf("%03d_%s", i + 1, 
        message.original_subject&.gsub(/[^a-zA-Z0-9\-_]/, '_')&.[](0..50) || 'no_subject'))
      
      require 'fileutils'
      FileUtils.mkdir_p(message_dir)
      
      # Save message info
      info_file = File.join(message_dir, 'message_info.txt')
      File.open(info_file, 'w') do |f|
        f.puts "Subject: #{message.original_subject}"
        f.puts "From: #{message.original_from}"
        f.puts "To: #{message.original_to.join(', ')}"
        f.puts "Date: #{message.original_date}"
        f.puts "Attachments: #{message.original_attachments.size}"
        f.puts "\n--- Body ---"
        f.puts message.original_body if message.original_body
      end
      
      # Download attachments
      message.original_attachments.each do |att|
        att.save_to_dir(message_dir)
      end
      
      puts "Processed message #{i + 1}: #{message.original_subject}"
    end
    
    puts "Batch download completed in: #{base_dir}"
    
  ensure
    client&.disconnect
  end
end

# Run examples
if __FILE__ == $0
  puts "PecDecoder Advanced Usage Examples"
  puts "=" * 50
  
  # Uncomment the examples you want to run:
  
  example_error_handling
  
  # example_message_filtering
  # example_attachment_processing  
  # example_message_analysis
  # example_batch_download
  
  puts "\nAll examples completed!"
end