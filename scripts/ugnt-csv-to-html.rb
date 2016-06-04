class GNTParser
  require 'json'
  require 'pry'
  require 'unicode_utils'
  require 'open-uri'
  require 'csv'

  attr :bible, :book_names, :path
  def initialize(params={path: '../data/UGNT ver 0.txt'})
    @bible = {}
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
      File.open("../data/json/#{book}.json", 'w') do |file|
        file.puts(json)
      end
    end
  end

  def write_html
    bible.each do |book, book_data|
      book_html = ''
      book_data.each do |chapter, chapter_data|
        chapter_html = "\n\t\t\t<div class='orphan'>\n\t\t\t\t<h2>Chapter #{chapter}</h2>"
        chapter_data.each do |verse, text|
          verse_html = "\n\t\t\t\t<p><sup>#{verse}</sup> #{text}\n\t\t\t\t</p>"
          if verse.to_i == 1
            verse_html << "\n\t\t\t</div>"
          end
          chapter_html << verse_html
        end
        book_html << "\n\t\t<div class='chapter'>#{chapter_html}\n\t\t</div>"
      end
      body = "\n\t<h1>#{book}</h1>\n\t<div class='chapters'>#{book_html}\n\t</div>\n"
      html = "<!DOCTYPE html>
      <html>
        <head>
          <meta charset='utf-8'/>
          <style>
            h1, h2 {
              text-align: center;
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
      html_file = "../data/html/#{book}.html"
      File.open(html_file, 'w') do |file|
        file.puts(html)
      end
      # for pdf conversion, clone https://github.com/klappy/electron-pdf.git into this directory before running
      # once PR for fix is merged into electron-pdf, code will be updated.
      pdf_file = "../data/pdf/#{book}.pdf"
      `node ./electron-pdf/cli.js #{html_file} #{pdf_file}`
    end
  end

end

gnt = GNTParser.new()