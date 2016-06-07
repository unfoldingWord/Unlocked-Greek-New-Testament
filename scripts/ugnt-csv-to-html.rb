class GNTParser
  require 'json'
  require 'pry'
  require 'unicode_utils'
  require 'open-uri'
  require 'csv'

  attr :bible, :apparatus, :book_names, :path
  def initialize(params={path: '../data/UGNT ver 0.txt'})
    @bible = {}
    @apparatus = {}
    @book_names = %w(nil Matthew Mark Luke John Acts Romans 1Corinthians 2Corinthians Galatians Ephesians Philippians Colossians 1Thessalonians 2Thessalonians 1Timothy 2Timothy Titus Philemon Hebrews James 1Peter 2Peter 1John 2John 3John Jude Revelation)
    @path = params[:path]
    bible_parse
    write_html
  end

  def bible_parse
    CSV.new(open(path), col_sep: "\t").each do |record|
      _book, chapter, verse, sub, order, text = record
      book = parse_book(_book)
      unless book == nil
        reference = {book: book, chapter: chapter, verse: verse}
        add_verse(reference, text)
      end
    end
  end

  def parse_book(id)
    book = book_names[id.to_i - 39]
  end

  def parse_apparatus(text, reference, _text=text.dup)
    footnote_regex = /\{.+?\}/
    if _text[footnote_regex]
      build_apparatus(reference)
      _text.scan(footnote_regex) do |match|
        @apparatus[reference[:book]][reference[:chapter]][reference[:verse]] << match.gsub(/[\{\}]/,'')
        count = @apparatus[reference[:book]][reference[:chapter]][reference[:verse]].count
        text.gsub!(match, "<sup class='apparatus_marker'>#{reference[:verse]}.#{count}</sup>")
      end
    end
    text
  end

  def add_verse(reference, _text, _book=reference[:book], _chapter=reference[:chapter], _verse=reference[:verse])
    build_bible(reference)
    text = _text ? parse_apparatus(_text, reference) : _text
    @bible[_book][_chapter][_verse] = text 
  end

  def build_bible(reference)
    @bible[reference[:book]] ||= {}
    @bible[reference[:book]][reference[:chapter]] ||= {}
    @bible[reference[:book]][reference[:chapter]][reference[:verse]] ||= ''
  end

  def build_apparatus(reference)
    @apparatus[reference[:book]] ||= {}
    @apparatus[reference[:book]][reference[:chapter]] ||= {}
    @apparatus[reference[:book]][reference[:chapter]][reference[:verse]] ||= []
  end

  def write_json
    bible.each do |book, data|
      json = JSON.pretty_generate({ "#{book}" => data })
      File.open("../data/json/#{book}.json", 'w') do |file|
        file.puts(json)
      end
    end
  end

  def book_template(book_name)
    book_data = bible[book_name]
    chapters_html = ''
    book_data.each do |chapter, chapter_data|
      chapter_html = "\n\t\t\t<div class='orphan'>\n\t\t\t\t<h2>Chapter #{chapter}</h2>"
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
          "\n\t\t\t\t<p><sup class='apparatus_marker'>#{verse}.#{index+1}</sup> #{text}\n\t\t\t\t</p>"
        end.join
      end if apparatus[book_name][chapter]
      chapter_html << "\n\t\t\t<hr/>\n\t\t\t<div class='apparatus'>#{chapter_apparatus_html}\n\t\t\t</div>"
      chapters_html << "\n\t\t<div class='chapter'>#{chapter_html}\n\t\t</div>"
    end
    book_html = "\n<div class='book'><h1 class='book_name'>#{book_name}</h1>\n\t<div class='chapters'>#{chapters_html}\n\t</div>\n</div>"
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
        @page:right {
          margin-left: 1in;
        }
        @page:left {
          margin-right: 1in;
        }
        body {
          font-size: 80%;
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
    html_file = "../data/html/#{name}.html"
    File.open(html_file, 'w') do |file|
      file.puts(content)
    end
    # for pdf conversion, clone https://github.com/klappy/electron-pdf.git into this directory before running
    # once PR for fix is merged into electron-pdf, code will be updated.
    pdf_file = "../data/pdf/#{name}.pdf"
    `node ./electron-pdf/cli.js #{html_file} #{pdf_file}`
  end

  def write_html
    bible_html = File.open('../data/html/0FirstPage.html', 'r') { |file| file.read }
    book_names.reject{|book_name| book_name == 'nil'}.each do |book_name|
      book_html = book_template(book_name)
      bible_html << book_html
      file_write(book_name, html_template(book_html))
    end
    file_write('NewTestament', html_template(bible_html))
  end

end

gnt = GNTParser.new()