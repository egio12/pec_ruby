# frozen_string_literal: true

begin
  require 'tty-prompt'
  require 'awesome_print'
rescue LoadError => e
  raise LoadError, "CLI dependencies not available. Install with: gem install tty-prompt awesome_print"
end

module PecRuby
  class CLI
    def initialize
      @client = nil
      @prompt = TTY::Prompt.new
    end

    def run
      puts banner
      
      loop do
        case main_menu
        when :connect
          connect_to_server
        when :list_messages
          list_and_select_messages if connected?
        when :disconnect
          disconnect_from_server
        when :exit
          disconnect_from_server if connected?
          puts "\nArrivederci!"
          break
        end
      end
    end

    private

    def banner
      <<~BANNER
        
        ╔═══════════════════════════════════════════════════════════════╗
        ║                       PEC Decoder CLI                        ║
        ║               Decodificatore PEC per Ruby                     ║
        ╚═══════════════════════════════════════════════════════════════╝
        
      BANNER
    end

    def main_menu
      choices = []
      
      if connected?
        choices << { name: "Lista e analizza messaggi PEC", value: :list_messages }
        choices << { name: "Disconnetti dal server", value: :disconnect }
      else
        choices << { name: "Connetti al server PEC", value: :connect }
      end
      
      choices << { name: "Esci", value: :exit }

      @prompt.select("Seleziona un'azione:", choices)
    end

    def connect_to_server
      return if connected?

      puts "\nCONNESSIONE AL SERVER PEC"
      puts "─" * 40

      host = @prompt.ask("Host IMAP:", default: "imaps.pec.aruba.it")
      username = @prompt.ask("Username/Email:")
      password = @prompt.mask("Password:")

      print "Connessione in corso..."
      
      begin
        @client = Client.new(host: host, username: username, password: password)
        @client.connect
        puts " Connesso!"
        puts "Connesso come: #{@client.username}"
      rescue PecRuby::Error => e
        puts " Errore!"
        puts "ATTENZIONE: #{e.message}"
        @client = nil
      end
    end

    def connected?
      @client&.connected?
    end

    def disconnect_from_server
      return unless connected?
      
      @client.disconnect
      @client = nil
      puts "Disconnesso dal server"
    end

    def list_and_select_messages
      puts "\nCaricamento messaggi..."
      
      begin
        messages = @client.pec_messages(limit: 50, reverse: false)
        # Sort by date in descending order (newest first)
        messages = messages.sort_by { |msg| msg.date || Time.at(0) }.reverse
        
        if messages.empty?
          puts "Nessun messaggio PEC trovato"
          return
        end

        choices = messages.map do |msg|
          label = format_message_label(msg)
          [label, msg]
        end

        puts "\n" + "─" * 120
        puts "MESSAGGI PEC RICEVUTI (più recenti in alto)"
        puts "─" * 120
        
        selected_message = @prompt.select("Seleziona un messaggio:", choices.to_h, per_page: 15, cycle: true)
        display_message(selected_message)
        
      rescue PecRuby::Error => e
        puts "Errore nel recupero messaggi: #{e.message}"
      end
    end

    def format_message_label(message)
      subject = message.subject || "(nessun oggetto)"
      from = message.from || "(mittente sconosciuto)"
      date = message.date ? message.date.strftime("%d/%m %H:%M") : "N/A"
      
      short_subject = subject.length > 60 ? "#{subject[0..56]}..." : subject
      
      sprintf("%-60s | %-25s | %s", 
             short_subject, 
             from.to_s[0..24], 
             date)
    end

    def display_message(message)
      puts "\n" + "="*80
      puts "MESSAGGIO PEC DECODIFICATO"
      puts "="*80

      # Informazioni base PEC
      puts "\nINFORMAZIONI CONTENITORE PEC"
      puts "─"*50
      puts sprintf("Oggetto PEC: %s", message.subject || "(nessun oggetto)")
      puts sprintf("From PEC:    %s", message.from || "(sconosciuto)")
      puts sprintf("Data PEC:    %s", message.date ? message.date.strftime("%d/%m/%Y %H:%M") : "(sconosciuta)")

      # Informazioni messaggio originale
      if message.has_postacert?
        puts "\nMESSAGGIO ORIGINALE (da postacert.eml)"
        puts "─"*50
        puts sprintf("Oggetto:     %s", message.original_subject || "(nessun oggetto)")
        puts sprintf("Mittente:    %s", message.original_from || "(sconosciuto)")
        puts sprintf("Destinatari: %s", message.original_to.join(', '))
        puts sprintf("Data:        %s", message.original_date ? message.original_date.strftime("%d/%m/%Y %H:%M") : "(sconosciuta)")

        # Corpo del messaggio
        body = message.original_body
        if body && body[:content] && !body[:content].strip.empty?
          puts "\nCORPO DEL MESSAGGIO"
          puts "─"*50
          
          # Format the body for better readability
          content = body[:content].strip
          
          # Clean up common formatting issues
          content = content.gsub(/\r\n/, "\n")  # Normalize line endings
          content = content.gsub(/\u0093|\u0094/, '"')  # Replace smart quotes
          content = content.gsub(/\u0092/, "'")  # Replace smart apostrophes
          
          puts content
        end

        # Allegati
        attachments = message.original_attachments
        puts "\nALLEGATI"
        puts "─"*50
        if attachments.any?
          attachments.each_with_index do |att, i|
            puts sprintf("%d. %-30s | %s | %.1f KB", 
                        i+1, 
                        att.filename, 
                        att.mime_type,
                        att.size_kb)
          end
          
          if @prompt.yes?("\nVuoi scaricare gli allegati?")
            download_attachments(attachments)
          end
        else
          puts "   Nessun allegato presente"
        end
      else
        puts "\nATTENZIONE: Questo messaggio non contiene postacert.eml"
      end
      
      puts "\n" + "="*80
      @prompt.keypress("\nPremi un tasto per continuare...")
    end

    def download_attachments(attachments)
      download_dir = @prompt.ask("Directory di download:", default: "./downloads")
      
      begin
        require 'fileutils'
        FileUtils.mkdir_p(download_dir)
        
        attachments.each do |attachment|
          file_path = attachment.save_to_dir(download_dir)
          puts "Salvato: #{file_path}"
        end
        
        puts "Tutti gli allegati sono stati salvati in #{download_dir}"
      rescue => e
        puts "Errore nel salvataggio: #{e.message}"
      end
    end
  end
end