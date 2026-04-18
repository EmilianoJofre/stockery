require "csv"
require "nokogiri"
require "open3"

module Products
  class ImportFileParser
    ParsedFile = Struct.new(:headers, :rows, keyword_init: true)

    HEADER_ALIASES = {
      "sku" => %w[sku],
      "name" => %w[name nombre],
      "description" => %w[description descripcion],
      "price" => %w[price precio],
      "low_stock_threshold" => %w[low_stock_threshold low_stock umbral threshold],
      "category" => %w[category categoria],
      "active" => %w[active activo]
    }.freeze

    def initialize(file:)
      @file = file
    end

    def call
      raise ImportError, "Debes adjuntar un archivo para importar." if file.blank?

      case extension
      when ".csv"
        parse_csv
      when ".xlsx"
        parse_xlsx
      else
        raise ImportError, "Formato no soportado. Usa un archivo .xlsx o .csv."
      end
    end

    private

    attr_reader :file

    def parse_csv
      csv = CSV.parse(read_source, headers: true, encoding: "bom|utf-8")
      headers = normalize_headers(csv.headers)

      ParsedFile.new(
        headers: headers,
        rows: csv.each_with_index.map do |row, index|
          {
            row_number: index + 2,
            data: build_row_hash(headers, row.fields)
          }
        end
      )
    rescue CSV::MalformedCSVError => e
      raise ImportError, "No se pudo leer el CSV: #{e.message}"
    ensure
      rewind_source
    end

    def parse_xlsx
      sheet_rows = workbook_rows
      header_row = sheet_rows.find { |row| row[:values].any?(&:present?) }
      raise ImportError, "El archivo no contiene encabezados." if header_row.blank?

      headers = normalize_headers(header_row[:values])
      data_rows = sheet_rows.drop_while { |row| row[:row_number] != header_row[:row_number] }.drop(1)

      ParsedFile.new(
        headers: headers,
        rows: data_rows.map do |row|
          {
            row_number: row[:row_number],
            data: build_row_hash(headers, row[:values])
          }
        end
      )
    end

    def workbook_rows
      shared_strings = parse_shared_strings(unzip_entry("xl/sharedStrings.xml", required: false))
      worksheet_path = first_worksheet_path
      worksheet_doc = xml_document(unzip_entry(worksheet_path))

      worksheet_doc.css("worksheet sheetData row").map do |row_node|
        values = []

        row_node.css("c").each do |cell|
          index = column_index(cell["r"])
          values[index] = cell_value(cell, shared_strings)
        end

        { row_number: row_node["r"].to_i, values: values }
      end
    end

    def first_worksheet_path
      workbook_doc = xml_document(unzip_entry("xl/workbook.xml"))
      rels_doc = xml_document(unzip_entry("xl/_rels/workbook.xml.rels"))

      first_sheet = workbook_doc.at_css("workbook sheets sheet")
      raise ImportError, "No se encontró ninguna hoja dentro del archivo Excel." if first_sheet.blank?

      relationship_id = first_sheet["id"]
      relationship = rels_doc.css("Relationships Relationship").find { |node| node["Id"] == relationship_id }
      raise ImportError, "No se pudo resolver la hoja principal del archivo Excel." if relationship.blank?

      target = relationship["Target"].to_s.sub(%r{\A/}, "")
      target.start_with?("xl/") ? target : "xl/#{target}"
    end

    def parse_shared_strings(xml)
      return [] if xml.blank?

      xml_document(xml).css("sst si").map(&:text)
    end

    def cell_value(cell, shared_strings)
      case cell["t"]
      when "s"
        shared_strings[cell.at_css("v")&.text.to_i]
      when "inlineStr"
        cell.at_css("is")&.text.to_s
      when "b"
        cell.at_css("v")&.text == "1" ? "true" : "false"
      else
        cell.at_css("v")&.text.to_s
      end
    end

    def column_index(reference)
      letters = reference.to_s[/[A-Z]+/i].to_s.upcase
      letters.chars.reduce(0) { |memo, char| (memo * 26) + char.ord - 64 } - 1
    end

    def normalize_headers(raw_headers)
      headers = Array(raw_headers).map { |header| canonical_header(header) }
      duplicates = headers.compact.tally.select { |_, count| count > 1 }.keys
      return headers if duplicates.empty?

      raise ImportError, "La plantilla contiene columnas duplicadas: #{duplicates.join(', ')}."
    end

    def canonical_header(value)
      normalized = normalize_text(value)
      return nil if normalized.blank?

      HEADER_ALIASES.find { |_, aliases| aliases.include?(normalized) }&.first || normalized
    end

    def build_row_hash(headers, fields)
      headers.each_with_index.each_with_object({}) do |(header, index), row|
        next if header.blank?

        row[header] = fields[index].to_s.strip
      end
    end

    def normalize_text(value)
      I18n.transliterate(value.to_s)
        .strip
        .downcase
        .gsub(/\s+/, "_")
        .gsub(/[^a-z0-9_]/, "")
    end

    def unzip_entry(entry, required: true)
      stdout, stderr, status = Open3.capture3("unzip", "-p", source_path, entry)
      return stdout if status.success? && stdout.present?
      return nil unless required

      message = stderr.to_s.strip.presence || "No se pudo leer el contenido del archivo."
      raise ImportError, "No se pudo procesar el archivo Excel: #{message}"
    rescue Errno::ENOENT
      raise ImportError, "El servidor no tiene soporte para archivos .xlsx."
    end

    def xml_document(xml)
      Nokogiri::XML(xml).tap(&:remove_namespaces!)
    end

    def extension
      File.extname(original_filename).downcase
    end

    def original_filename
      file.respond_to?(:original_filename) ? file.original_filename.to_s : ""
    end

    def source_path
      @source_path ||= if file.respond_to?(:tempfile)
        file.tempfile.path
      elsif file.respond_to?(:path)
        file.path
      else
        raise ImportError, "No se pudo acceder al archivo cargado."
      end
    end

    def read_source
      if file.respond_to?(:read)
        file.read.to_s
      else
        File.read(source_path)
      end
    end

    def rewind_source
      file.rewind if file.respond_to?(:rewind)
      file.tempfile.rewind if file.respond_to?(:tempfile) && file.tempfile.respond_to?(:rewind)
    rescue IOError
      nil
    end
  end
end
