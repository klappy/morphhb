class HebrewBibleParser
  require 'json'
  require 'pry'
  require 'unicode_utils'
  require 'open-uri'
  require 'nokogiri'

  attr :bible, :apparatus, :book_names, :book_names_full, :path
  def initialize(params={path: '../wlc'})
    @bible = {}
    @apparatus = {}
    @book_names = ["Gen","Exod","Lev","Num", "Deut", "Josh", "Judg", "Ruth","1Sam","2Sam","1Kgs","2Kgs","1Chr","2Chr","Ezra","Neh","Esth","Job","Ps","Prov","Eccl","Song","Isa","Jer","Lam","Ezek","Dan","Hos","Joel","Amos","Obad","Jonah","Mic","Nah","Hab","Zeph","Hag","Zech","Mal"]
    @book_names_full = ["Genesis","Exodus","Leviticus","Numbers","Deuteronomy","Joshua","Judges","Ruth","1 Samuel","2 Samuel","1 Kings","2 Kings","1 Chronicles","2 Chronicles","Ezra","Nehemiah","Esther","Job","Psalms","Proverbs","Ecclesiastes","Song of Solomon","Isaiah","Jeremiah","Lamentations","Ezekiel","Daniel","Hosea","Joel","Amos","Obadiah","Jonah","Micah","Nahum","Habakkuk","Zephaniah","Haggai","Zechariah","Malachi"]
    @path = params[:path]
    bible_parse
    write_json
    write_html
  end

  def bible_parse
    Dir.glob("#{path}/*.xml").each do |filename|
      unless filename[/VerseMap/]
        osis = Nokogiri::XML(File.open(filename))
        osis.css('verse').each do |verseNode|
          reference = parseReference(verseNode['osisID'])
          parse_apparatus(verseNode.css('note'), reference)
          text = verseNode.text.gsub(/\s+/,' ')
          add_verse(reference, text)
        end
      end
    end
  end

  def parseReference(osisID)
    book, chapter, verse = osisID.split('.')
    reference = {book: book, chapter: chapter, verse: verse}
  end

  def parse_apparatus(noteNodes, reference)
    if noteNodes.count > 0
      build_apparatus(reference)
      noteNodes.each_with_index do |node, index|
        @apparatus[reference[:book]][reference[:chapter]][reference[:verse]] << node.text
        node.content = "<sup class='apparatus_marker'>#{reference[:verse]}.#{index+1}</sup>"
      end
    end
  end

  def build_apparatus(reference)
    @apparatus[reference[:book]] ||= {}
    @apparatus[reference[:book]][reference[:chapter]] ||= {}
    @apparatus[reference[:book]][reference[:chapter]][reference[:verse]] ||= []
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

  def book_template(book_name)
    book_data = bible[book_name]
    chapters_html = ''
    book_data.each do |chapter, chapter_data|
      chapter_html = "\n\t\t\t<div class='orphan'>\n\t\t\t\t<h2 dir='ltr'>Chapter #{chapter}</h2>"
      chapter_data.each do |verse, text|
        verse_html = "\n\t\t\t\t<p><sup class='verse_marker'>#{verse}</sup> #{text}\n\t\t\t\t</p>"
        if verse.to_i == 1
          verse_html << "\n\t\t\t</div>"
        end
        chapter_html << verse_html
      end
      chapter_apparatus_html = ''
      apparatus[book_name][chapter].each do |verse, apparatus_array|
        chapter_apparatus_html << apparatus_array.map.with_index do |text, index|
          "\n\t\t\t\t<p dir='ltr'><sup class='apparatus_marker'>#{verse}.#{index+1}</sup> #{text}\n\t\t\t\t</p>"
        end.join
      end if apparatus[book_name][chapter]
      chapter_html << "\n\t\t\t<hr/>\n\t\t\t<div class='apparatus'>#{chapter_apparatus_html}\n\t\t\t</div>"
      chapters_html << "\n\t\t<div class='chapter'>#{chapter_html}\n\t\t</div>"
    end rescue binding.pry
    book_html = "\n<div class='book'><h1 class='book_name'>#{book_names_full[book_names.index(book_name)]}</h1>\n\t<div class='chapters' dir='rtl'>#{chapters_html}\n\t</div>\n</div>"
  end

  def html_template(body)
return %Q{<!DOCTYPE html>
<html>
  <head>
    <meta charset='utf-8'/>
    <style>
      #cover {
        font-family: arial; 
      }
      h1, h2, h3, #cover {
        text-align: center;
      }
      .icon img {
        width: 144px;
      }
      p {
        text-align: justify;
      }
      .chapter p {
        margin: 0.3em 0;
      }
      .apparatus {
        -webkit-columns: auto 2; /* Chrome, Safari, Opera */
        -moz-columns: auto 2; /* Firefox */
        columns: auto 2;
      }
      .apparatus p {
        margin: 0;
      }
      .verse_marker, .apparatus_marker {
        font-size: 0.8em;
      }
      .apparatus_marker {
        font-style: italic;
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
        @page:left {
          margin-left: 1in;
        }
        @page:right {
          margin-right: 1in;
        }
        body {
          font-size: 75%;
        }
        div#cover {
          padding-top: 33%;
          page-break-after: always;
        }
        h1.book_name {
          page-break-before: always;
        }
        .apparatus p {
          font-size: 0.9em;
        }
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
        span.footnote {
          float: footnote;
        }
      }
    </style>
  </head>
  <body>
    #{body}
  </body>
</html>
}
  end

  def file_write(name, content)
    html_file = "../wlc/html/#{name}.html"
    File.open(html_file, 'w') do |file|
      file.puts(content)
    end
    # for pdf conversion, clone https://github.com/klappy/electron-pdf.git into this directory before running
    # once PR for fix is merged into electron-pdf, code will be updated.
    pdf_file = "../wlc/pdf/#{name}.pdf"
    `node ./electron-pdf/cli.js #{html_file} #{pdf_file}`
  end

  def write_html
    bible_html = File.open('../wlc/html/0FirstPage.html', 'r') { |file| file.read }
    book_names.reject{|book_name| book_name == 'nil'}.each do |book_name|
      book_html = book_template(book_name)
      bible_html << book_html
      file_write(book_name, html_template(book_html))
    end
    file_write('OldTestament', html_template(bible_html))
  end
end
# https://www.smashingmagazine.com/2015/01/designing-for-print-with-css/
hb = HebrewBibleParser.new()