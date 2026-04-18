require "fileutils"
require "nokogiri"
require "open3"
require "securerandom"
require "tmpdir"

module Products
  class ImportTemplate
    SAMPLE_ROWS = [
      {
        "sku" => "SKU-001",
        "name" => "Café de grano 250g",
        "description" => "Bolsa tostado medio",
        "price" => "5490",
        "low_stock_threshold" => "12",
        "category" => nil,
        "active" => "true"
      },
      {
        "sku" => "SKU-002",
        "name" => "Té verde caja x20",
        "description" => "Caja con 20 bolsitas",
        "price" => "3290",
        "low_stock_threshold" => "8",
        "category" => nil,
        "active" => "true"
      }
    ].freeze

    def initialize(company:)
      @company = company
    end

    def filename
      "plantilla_importacion_productos.xlsx"
    end

    def content_type
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    end

    def to_xlsx
      Dir.mktmpdir("stockify-product-template") do |dir|
        write_package(dir)
        archive_path = File.join(Dir.tmpdir, "stockify-product-template-#{SecureRandom.hex(8)}.xlsx")

        stdout, stderr, status = Open3.capture3("zip", "-qr", archive_path, ".", chdir: dir)
        raise ImportError, zip_error_message(stdout, stderr) unless status.success? && File.exist?(archive_path)

        File.binread(archive_path)
      ensure
        FileUtils.rm_f(archive_path) if archive_path
      end
    end

    private

    attr_reader :company

    def template_rows
      category_name = company.product_categories.active.order(:name).pick(:name)

      SAMPLE_ROWS.each_with_index.map do |row, index|
        Products::Importer::TEMPLATE_HEADERS.map do |header|
          next category_name if header == "category" && index.zero?

          row[header]
        end
      end
    end

    def write_package(dir)
      write_file(dir, "[Content_Types].xml", content_types_xml)
      write_file(dir, "_rels/.rels", package_relationships_xml)
      write_file(dir, "docProps/app.xml", app_properties_xml)
      write_file(dir, "docProps/core.xml", core_properties_xml)
      write_file(dir, "xl/workbook.xml", workbook_xml)
      write_file(dir, "xl/_rels/workbook.xml.rels", workbook_relationships_xml)
      write_file(dir, "xl/worksheets/sheet1.xml", worksheet_xml)
    end

    def write_file(dir, relative_path, content)
      full_path = File.join(dir, relative_path)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.binwrite(full_path, content)
    end

    def content_types_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
          <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        </Types>
      XML
    end

    def package_relationships_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
          <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
        </Relationships>
      XML
    end

    def app_properties_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
                    xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
          <Application>Stockery</Application>
        </Properties>
      XML
    end

    def core_properties_xml
      created_at = Time.current.utc.iso8601

      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
                           xmlns:dc="http://purl.org/dc/elements/1.1/"
                           xmlns:dcterms="http://purl.org/dc/terms/"
                           xmlns:dcmitype="http://purl.org/dc/dcmitype/"
                           xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <dc:title>Plantilla de importación de productos</dc:title>
          <dc:creator>Stockery</dc:creator>
          <cp:lastModifiedBy>Stockery</cp:lastModifiedBy>
          <dcterms:created xsi:type="dcterms:W3CDTF">#{created_at}</dcterms:created>
          <dcterms:modified xsi:type="dcterms:W3CDTF">#{created_at}</dcterms:modified>
        </cp:coreProperties>
      XML
    end

    def workbook_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            <sheet name="Productos" sheetId="1" r:id="rId1"/>
          </sheets>
        </workbook>
      XML
    end

    def workbook_relationships_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        </Relationships>
      XML
    end

    def worksheet_xml
      rows = [Products::Importer::TEMPLATE_HEADERS] + template_rows

      builder = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
        xml.worksheet("xmlns" => "http://schemas.openxmlformats.org/spreadsheetml/2006/main") do
          xml.sheetViews do
            xml.sheetView(workbookViewId: "0")
          end
          xml.sheetFormatPr(defaultRowHeight: "18")
          xml.cols do
            Products::Importer::TEMPLATE_HEADERS.each_index do |index|
              width = index == 2 ? 32 : 20
              xml.col(min: index + 1, max: index + 1, width: width, customWidth: "1")
            end
          end
          xml.sheetData do
            rows.each_with_index do |row, row_index|
              xml.row(r: row_index + 1) do
                row.each_with_index do |value, column_index|
                  xml.c(r: "#{excel_column(column_index)}#{row_index + 1}", t: "inlineStr") do
                    xml.is do
                      xml.t(value.to_s)
                    end
                  end
                end
              end
            end
          end
        end
      end

      builder.to_xml
    end

    def excel_column(index)
      value = index + 1
      result = +""

      while value.positive?
        value -= 1
        result.prepend((65 + (value % 26)).chr)
        value /= 26
      end

      result
    end

    def zip_error_message(stdout, stderr)
      detail = stderr.to_s.strip.presence || stdout.to_s.strip.presence || "No se pudo empaquetar la plantilla."
      "No se pudo generar la plantilla Excel: #{detail}"
    end
  end
end
