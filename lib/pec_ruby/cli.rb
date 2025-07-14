# frozen_string_literal: true

begin
  require 'tty-prompt'
  require 'tty-screen'
  require 'awesome_print'
rescue LoadError => e
  raise LoadError, 'CLI dependencies not available. Install with: gem install tty-prompt tty-screen awesome_print'
end

module PecRuby
  class CLI
    def initialize
      @client = nil
      @prompt = TTY::Prompt.new
      @screen_height = TTY::Screen.height
      @screen_width = TTY::Screen.width
    end

    def run
      loop do
        clear_screen
        show_header
        show_status
        
        case main_menu
        when :connect
          connect_to_server
        when :select_folder
          select_folder_menu if connected?
        when :list_messages
          list_and_select_messages if connected?
        when :disconnect
          disconnect_from_server
        when :exit
          disconnect_from_server if connected?
          clear_screen
          puts center_text('Arrivederci!')
          break
        end
      end
    end

    private

    def clear_screen
      print "\033[2J\033[H"
    end

    def center_text(text)
      padding = (@screen_width - text.length) / 2
      ' ' * [padding, 0].max + text
    end

    def show_header
      puts banner
    end

    def show_status
      if connected?
        status = "CONNESSO: #{@client.username}"
        folder = @client.current_folder ? " | FOLDER: #{@client.current_folder}" : ""
        puts center_text("#{status}#{folder}")
      else
        puts center_text("NON CONNESSO")
      end
      puts "─" * @screen_width
      puts
    end

    def banner
      <<~BANNER
        ██████╗ ███████╗ ██████╗    ██████╗ ██╗   ██╗██████╗ ██╗   ██╗
        ██╔══██╗██╔════╝██╔════╝    ██╔══██╗██║   ██║██╔══██╗╚██╗ ██╔╝
        ██████╔╝█████╗  ██║         ██████╔╝██║   ██║██████╔╝ ╚████╔╝
        ██╔═══╝ ██╔══╝  ██║         ██╔══██╗██║   ██║██╔══██╗  ╚██╔╝
        ██║     ███████╗╚██████╗    ██║  ██║╚██████╔╝██████╔╝   ██║
        ╚═╝     ╚══════╝ ╚═════╝    ╚═╝  ╚═╝ ╚═════╝ ╚═════╝    ╚═╝

        PEC Ruby CLI v#{PecRuby::VERSION} | Italian PEC Email Manager
      BANNER
    end

    def main_menu
      choices = []

      if connected?
        choices << { name: 'Seleziona folder', value: :select_folder }
        choices << { name: 'Lista e analizza messaggi', value: :list_messages }
        choices << { name: 'Disconnetti dal server', value: :disconnect }
      else
        choices << { name: 'Connetti al server PEC', value: :connect }
      end

      choices << { name: 'Esci', value: :exit }

      @prompt.select("Seleziona un'azione:", choices)
    end

    def connect_to_server
      return if connected?

      clear_screen
      show_header
      puts
      puts center_text("CONNESSIONE AL SERVER PEC")
      puts "─" * @screen_width
      puts

      host = @prompt.ask('Host IMAP:', default: 'imaps.pec.aruba.it')
      username = @prompt.ask('Username/Email:')
      password = @prompt.mask('Password:')

      puts
      puts center_text('[*] Connessione in corso...')

      begin
        @client = Client.new(host: host, username: username, password: password)
        @client.connect
        
        puts center_text('[+] Connesso con successo!')
        puts center_text("Utente: #{@client.username}")
        puts center_text("Folder: INBOX")
        
        @prompt.keypress("\n#{center_text('Premi un tasto per continuare...')}", echo: false)
      rescue PecRuby::Error => e
        puts center_text('[-] Errore di connessione!')
        puts center_text("Dettagli: #{e.message}")
        @client = nil
        
        @prompt.keypress("\n#{center_text('Premi un tasto per continuare...')}", echo: false)
      end
    end

    def connected?
      @client&.connected?
    end

    def disconnect_from_server
      return unless connected?

      clear_screen
      show_header
      puts
      puts center_text('[*] Disconnessione in corso...')
      
      @client.disconnect
      @client = nil
      
      puts center_text('[+] Disconnesso dal server')
      
      @prompt.keypress("\n#{center_text('Premi un tasto per continuare...')}", echo: false)
    end

    def list_and_select_messages
      current_folder = @client.current_folder || 'INBOX'
      
      clear_screen
      show_header
      show_status
      puts center_text("MESSAGGI DA #{current_folder.upcase}")
      puts "─" * @screen_width
      puts center_text("[*] Caricamento messaggi...")

      begin
        # Get messages in reverse order (newest first) directly from server
        start_time = Time.now
        messages = @client.messages(limit: 50, reverse: true)
        load_time = Time.now - start_time

        if messages.empty?
          puts center_text("[-] Nessun messaggio trovato in #{current_folder}")
          @prompt.keypress("\n#{center_text('Premi un tasto per continuare...')}", echo: false)
          return
        end

        choices = messages.map do |msg|
          label = format_message_label(msg)
          [label, msg]
        end

        puts center_text("[+] Trovati #{messages.size} messaggi (caricati in #{load_time.round(2)}s)")
        puts

        selected_message = @prompt.select('Seleziona un messaggio:', choices.to_h, per_page: 15, cycle: true)
        display_message(selected_message)
      rescue PecRuby::Error => e
        puts center_text("[-] Errore nel recupero messaggi: #{e.message}")
        @prompt.keypress("\n#{center_text('Premi un tasto per continuare...')}", echo: false)
      rescue StandardError => e
        puts center_text("[-] Errore imprevisto: #{e.message}")
        puts center_text("Dettagli: #{e.class}")
        @prompt.keypress("\n#{center_text('Premi un tasto per continuare...')}", echo: false)
      end
    end

    def format_message_label(message)
      # Use only original (envelope) data for performance - no postacert fetching
      subject = message.original_subject || '(nessun oggetto)'
      from = message.original_from || '(mittente sconosciuto)'
      date = message.original_date ? message.original_date.strftime('%d/%m %H:%M') : 'N/A'

      short_subject = subject.length > 60 ? "#{subject[0..56]}..." : subject

      format('%-60s | %-25s | %s',
             short_subject,
             from.to_s[0..24],
             date)
    end

    def display_message(message)
      loop do
        clear_screen
        show_header
        show_status
        
        # Message header with visual separator
        puts center_text("DETTAGLIO MESSAGGIO")
        puts "═" * @screen_width
        puts
        
        # Message info in organized sections
        display_message_info(message)
        display_message_body(message, truncate: true)
        display_message_attachments(message, show_download_option: false)
        
        puts
        puts "═" * @screen_width
        
        # Show message menu
        action = show_message_menu(message)
        case action
        when :full_body
          display_full_body(message)
        when :download_attachments
          download_attachments(message.attachments) if message.attachments.any?
        when :back
          break
        end
      end
    end

    def show_message_menu(message)
      choices = []
      
      # Add body option if message has body
      body = message.raw_body
      if body && body[:content] && !body[:content].strip.empty?
        choices << { name: "Visualizza corpo completo", value: :full_body }
      end
      
      # Add attachments option if message has attachments
      if message.attachments.any?
        choices << { name: "Scarica allegati (#{message.attachments.size})", value: :download_attachments }
      end
      
      choices << { name: "← Torna alla lista", value: :back }
      
      @prompt.select("Seleziona un'azione:", choices)
    end

    def display_full_body(message)
      clear_screen
      show_header
      
      puts center_text("CORPO COMPLETO DEL MESSAGGIO")
      puts "═" * @screen_width
      puts
      
      body = message.raw_body
      if body && body[:content] && !body[:content].strip.empty?
        content = body[:content].strip
        content = content.gsub(/\r\n/, "\n")
        content = content.gsub(/\u0093|\u0094/, '"')
        content = content.gsub(/\u0092/, "'")
        
        puts content
      else
        puts center_text("Nessun contenuto disponibile")
      end
      
      puts
      puts "═" * @screen_width
      @prompt.keypress(center_text("Premi un tasto per continuare..."), echo: false)
    end

    def display_message_info(message)
      # Main information section
      puts "[INFORMAZIONI PRINCIPALI]"
      puts "─" * (@screen_width - 20)
      
      info_lines = [
        ["Oggetto", message.subject || "(nessun oggetto)"],
        ["Mittente", message.from || "(sconosciuto)"],
        ["Destinatari", message.to.join(", ")],
        ["Data", message.date ? message.date.strftime("%d/%m/%Y %H:%M") : "(sconosciuta)"]
      ]
      
      display_info_table(info_lines)
      puts
      
      # PEC container information
      puts "[INFORMAZIONI CONTENITORE PEC]"
      puts "─" * (@screen_width - 20)
      
      pec_lines = [
        ["Oggetto PEC", message.original_subject || "(nessun oggetto)"],
        ["From PEC", message.original_from || "(sconosciuto)"],
        ["Data PEC", message.original_date ? message.original_date.strftime("%d/%m/%Y %H:%M") : "(sconosciuta)"]
      ]
      
      display_info_table(pec_lines)
      puts
    end

    def display_message_body(message, truncate: false)
      body = message.raw_body
      return unless body && body[:content] && !body[:content].strip.empty?
      
      puts "[CORPO DEL MESSAGGIO]"
      puts "─" * (@screen_width - 20)
      
      # Format the body for better readability
      content = body[:content].strip
      content = content.gsub(/\r\n/, "\n")
      content = content.gsub(/\u0093|\u0094/, '"')
      content = content.gsub(/\u0092/, "'")
      
      if truncate
        # Truncate long messages for overview
        max_lines = 10
        lines = content.split("\n")
        
        if lines.length > max_lines
          puts lines.first(max_lines).join("\n")
          puts
          puts center_text("... (messaggio troncato, #{lines.length - max_lines} righe rimanenti)")
        else
          puts content
        end
      else
        puts content
      end
      puts
    end

    def display_message_attachments(message, show_download_option: true)
      attachments = message.attachments
      puts "[ALLEGATI - #{attachments.size}]"
      puts "─" * (@screen_width - 20)
      
      if attachments.any?
        attachments.each_with_index do |att, i|
          status = att.filename.include?('postacert') ? '[PEC]' : '[ATT]'
          puts format("%s %2d. %-35s | %-20s | %8.1f KB",
                      status,
                      i + 1,
                      truncate_text(att.filename, 35),
                      truncate_text(att.mime_type, 20),
                      att.size_kb)
        end
        
        if show_download_option
          puts
          download_attachments(attachments) if @prompt.yes?("Vuoi scaricare gli allegati?")
        end
      else
        puts center_text("Nessun allegato presente")
      end
    end

    def display_info_table(lines)
      max_label_width = lines.map { |line| line[0].length }.max
      
      lines.each do |label, value|
        formatted_label = label.ljust(max_label_width)
        puts "  #{formatted_label} : #{value}"
      end
    end

    def truncate_text(text, max_length)
      text.length > max_length ? "#{text[0..max_length-4]}..." : text
    end

    def select_folder_menu
      clear_screen
      show_header
      show_status
      puts center_text("SELEZIONE FOLDER")
      puts "─" * @screen_width
      puts

      begin
        folders = @client.available_folders

        if folders.empty?
          puts center_text('[-] Nessuna folder disponibile')
          @prompt.keypress("\n#{center_text('Premi un tasto per continuare...')}", echo: false)
          return
        end

        current_folder = @client.current_folder || 'INBOX'
        puts center_text("Folder corrente: #{current_folder}")
        puts

        folder_choices = folders.map { |folder| { name: "#{folder == current_folder ? '[*]' : '   '} #{folder}", value: folder } }
        folder_choices << { name: '← Torna al menu principale', value: :back }

        selected_folder = @prompt.select('Seleziona una folder:', folder_choices)

        return if selected_folder == :back

        if selected_folder != current_folder
          puts center_text("[*] Selezione folder #{selected_folder}...")
          @client.select_folder(selected_folder)
          puts center_text('[+] Folder selezionata con successo!')
          puts center_text("Folder attiva: #{selected_folder}")
        else
          puts center_text("[*] Folder #{selected_folder} già selezionata")
        end
        
        @prompt.keypress("\n#{center_text('Premi un tasto per continuare...')}", echo: false)
      rescue PecRuby::Error => e
        puts center_text("[-] Errore nella selezione folder: #{e.message}")
        @prompt.keypress("\n#{center_text('Premi un tasto per continuare...')}", echo: false)
      end
    end

    def download_attachments(attachments)
      clear_screen
      show_header
      show_status
      
      puts center_text("DOWNLOAD ALLEGATI")
      puts "═" * @screen_width
      puts
      
      download_dir = @prompt.ask('Directory di download:', default: './downloads')
      
      puts center_text("[*] Creazione directory...")
      
      begin
        require 'fileutils'
        FileUtils.mkdir_p(download_dir)
        
        puts center_text("[+] Directory creata: #{download_dir}")
        puts
        
        attachments.each_with_index do |attachment, i|
          puts center_text("[*] Salvando #{i+1}/#{attachments.size}: #{attachment.filename}")
          file_path = attachment.save_to_dir(download_dir)
          puts center_text("[+] Salvato: #{file_path}")
        end
        
        puts
        puts center_text("[+] Tutti gli allegati sono stati salvati!")
        puts center_text("Directory: #{download_dir}")
        
      rescue StandardError => e
        puts center_text("[-] Errore nel salvataggio: #{e.message}")
      end
      
      puts
      puts "═" * @screen_width
      @prompt.keypress(center_text("Premi un tasto per continuare..."), echo: false)
    end
  end
end
