class GNTParser
  require 'json'
  require 'pry'
  require 'unicode_utils'
  require 'open-uri'
  require 'nokogiri'

  attr :bible, :path
  def initialize(params={path: '../wlc'})
    @bible = {}
    @path = params[:path]
    bible_parse
    write_json
    write_html
  end

  def bible_parse
    Dir.glob("#{path}/*.xml").each do |filename|
      return nil if filename[/VerseMap/]
      osis = Nokogiri::XML(File.open(filename))
      osis.css('verse').each do |verseNode|
        reference = parseReference(verseNode['osisID'])
        verseNode.css('note').each(&:remove)
        text = verseNode.text.gsub(/\s+/,' ')
        add_verse(reference, text)
      end
    end
  end

  def parseReference(osisID)
    book, chapter, verse = osisID.split('.')
    reference = {book: book, chapter: chapter, verse: verse}
  end

  def add_verse(reference, verse, _book=reference[:book], _chapter=reference[:chapter], _verse=reference[:verse])
      bible_build(reference)
      @bible[_book][_chapter][_verse] = verse 
  end

  def bible_build(reference)
    @bible[reference[:book]] ||= {}
    @bible[reference[:book]][reference[:chapter]] ||= {}
    @bible[reference[:book]][reference[:chapter]][reference[:verse]] ||= {}
  end

  def write_json
    bible.each do |book, data|
      json = JSON.pretty_generate({ "#{book}" => data })
      File.open("../wlc/json/#{book}.json", 'w') do |file|
        file.puts(json)
      end
    end
  end

  def write_html
    bible.each do |book, book_data|
      book_html = ''
      book_data.each do |chapter, chapter_data|
        chapter_html = "\n\t\t\t<div class='orphan'>\n\t\t\t\t<h2 dir='ltr'>Chapter #{chapter}</h2>"
        chapter_data.each do |verse, text|
          verse_html = "\n\t\t\t\t<p><sup>#{verse}</sup> #{text}\n\t\t\t\t</p>"
          if verse.to_i == 1
            verse_html << "\n\t\t\t</div>"
          end
          chapter_html << verse_html
        end
        book_html << "\n\t\t<div class='chapter'>#{chapter_html}\n\t\t</div>"
      end
      body = "\n\t<h1>#{book}</h1>\n\t<div class='chapters' dir='rtl'>#{book_html}\n\t</div>\n"
      html = "<!DOCTYPE html>
      <html>
        <head>
          <meta charset='utf-8'/>
          <style>
            @page {
              counter-increment: page;

              @top-center {
                content: '#{book}';
              }

              @bottom-center {
                counter-increment: page;
                content: 'Page ' counter(page);
              }
            }
            h1, h2 {
              text-align: center;
            }
            p {
              text-align: justify;
            }
            @media screen {
              div.chapter {
                margin-bottom: 3em;
                -webkit-columns: auto 2; /* Chrome, Safari, Opera */
                -moz-columns: auto 2; /* Firefox */
                columns: auto 2;
              }
              p {
                -webkit-column-break-inside: avoid;
                page-break-inside: avoid;
                break-inside: avoid;
              }
            }
            @media print {
              div.chapters {
                -webkit-columns: auto 2; /* Chrome, Safari, Opera */
                -moz-columns: auto 2; /* Firefox */
                columns: auto 2;
                widows: 3;
                orphans: 3;
              }
              p { page-break-inside: avoid; }
              div.orphan {
                -webkit-column-break-inside: avoid;
                page-break-inside: avoid;
                break-inside: avoid; 
              }
            }
          </style>
        </head>
        <body>
          #{body}
        </body>
      </html>"
      html_file = "../wlc/html/#{book}.html"
      File.open(html_file, 'w') do |file|
        file.puts(html)
      end
      # for pdf conversion, clone https://github.com/klappy/electron-pdf.git into this directory before running
      # to handle dependencies, if node.js is installed, cd into dir and run npm install
      # once PR for fix is merged into electron-pdf, code will be updated.
      pdf_file = "../wlc/pdf/#{book}.pdf"
      `node ./electron-pdf/cli.js #{html_file} #{pdf_file}`
    end
  end

end
# https://www.smashingmagazine.com/2015/01/designing-for-print-with-css/
gnt = GNTParser.new()