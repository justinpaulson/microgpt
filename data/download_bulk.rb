#!/usr/bin/env ruby
# download_bulk.rb — Downloads bulk free text data from Wikipedia and Project Gutenberg

require 'open-uri'
require 'json'
require 'net/http'
require 'uri'

OUTPUT_FILE = File.join(__dir__, 'bulk_texts.txt')
WIKI_API = 'https://simple.wikipedia.org/w/api.php'

stats = { wiki_ok: 0, wiki_fail: 0, gutenberg_ok: 0, gutenberg_fail: 0 }

def wiki_get(params)
  uri = URI(WIKI_API)
  uri.query = URI.encode_www_form(params)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 15
  http.read_timeout = 30
  req = Net::HTTP::Get.new(uri)
  req['User-Agent'] = 'MicroGPT-BulkDownloader/1.0 (educational project; ruby script)'
  resp = http.request(req)
  JSON.parse(resp.body)
end

def gutenberg_get(id)
  url = "https://www.gutenberg.org/cache/epub/#{id}/pg#{id}.txt"
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 15
  http.read_timeout = 30
  req = Net::HTTP::Get.new(uri)
  req['User-Agent'] = 'MicroGPT-BulkDownloader/1.0 (educational project; ruby script)'
  resp = http.request(req)
  raise "HTTP #{resp.code}" unless resp.code == '200'
  resp.body.force_encoding('UTF-8')
end

# ── Phase 1: Collect Wikipedia article titles ──

puts "=== Phase 1: Collecting Simple English Wikipedia article titles ==="

all_titles = []
apcontinue = nil
5.times do |page|
  begin
    params = {
      'action'      => 'query',
      'list'        => 'allpages',
      'aplimit'     => '500',
      'apnamespace' => '0',
      'format'      => 'json'
    }
    params['apcontinue'] = apcontinue if apcontinue

    data = wiki_get(params)
    pages = data.dig('query', 'allpages') || []
    titles = pages.map { |p| p['title'] }
    all_titles.concat(titles)
    puts "  Page #{page + 1}: got #{titles.size} titles (total: #{all_titles.size})"

    apcontinue = data.dig('continue', 'apcontinue')
    break unless apcontinue
    sleep 0.3
  rescue => e
    puts "  WARNING: Failed to fetch title page #{page + 1}: #{e.message}"
    break
  end
end

puts "Collected #{all_titles.size} article titles."

# ── Phase 2: Fetch Wikipedia article extracts ──

puts "\n=== Phase 2: Fetching Wikipedia article extracts ==="

File.open(OUTPUT_FILE, 'w:UTF-8') do |out|
  batches = all_titles.each_slice(20).to_a
  batches.each_with_index do |batch, idx|
    begin
      joined = batch.join('|')
      params = {
        'action'       => 'query',
        'titles'       => joined,
        'prop'         => 'extracts',
        'explaintext'  => '1',
        'exlimit'      => '20',
        'format'       => 'json'
      }

      data = wiki_get(params)
      pages = data.dig('query', 'pages') || {}

      pages.each do |_id, page|
        title = page['title']
        extract = (page['extract'] || '').strip
        next if extract.empty? || extract.length < 100

        text = extract.length > 5000 ? extract[0, 5000] : extract
        out.puts "=== Wikipedia: #{title} ==="
        out.puts text
        out.puts
        stats[:wiki_ok] += 1
      end

      done = [((idx + 1).to_f / batches.size * 100).round(1), 100.0].min
      puts "  Batch #{idx + 1}/#{batches.size} (#{done}%) — #{stats[:wiki_ok]} articles written" if (idx + 1) % 10 == 0 || idx == batches.size - 1
      sleep 0.5
    rescue => e
      stats[:wiki_fail] += batch.size
      puts "  WARNING: Batch #{idx + 1} failed: #{e.message}"
      sleep 1
    end
  end

  # ── Phase 3: Project Gutenberg books ──

  puts "\n=== Phase 3: Downloading Project Gutenberg books ==="

  gutenberg_ids = [
    1, 2, 5, 11, 16, 23, 25, 27, 28, 30, 31, 33, 35, 36, 37, 41, 42, 43, 44, 45,
    46, 55, 58, 62, 64, 65, 67, 74, 76, 78, 79, 81, 82, 84, 86, 98, 100, 103, 104,
    105, 107, 108, 110, 113, 114, 120, 126, 132, 135, 140, 145, 153, 155, 158, 160,
    161, 164, 174, 175, 176, 189, 193, 195, 203, 205, 209, 215, 219, 236, 244, 271,
    289, 308, 312, 345, 349, 375, 389, 408, 421, 432, 451, 470, 514, 521, 524, 526,
    527, 541, 580, 600, 612, 620, 622, 644, 652, 674, 700, 730, 766, 768, 779, 829,
    844, 863, 880, 883, 884, 902, 910, 932, 940, 960, 996, 1023, 1080, 1155, 1184,
    1213, 1232, 1250, 1257, 1260, 1322, 1342, 1399, 1400, 1497, 1513, 1524, 1580,
    1597, 1600, 1661, 1727, 1952, 1998, 2000, 2009, 2097, 2148, 2160, 2500, 2542,
    2591, 2600, 2701, 2814, 2852, 3207, 3296, 3600, 4217, 4300, 5200, 6130, 7370,
    8800, 11339, 16328, 19942, 21279, 23042, 25344, 28054
  ]

  gutenberg_ids.each_with_index do |id, idx|
    begin
      raw = gutenberg_get(id)

      # Strip Gutenberg header/footer
      start_marker = raw.index('*** START')
      end_marker   = raw.index('*** END')

      if start_marker
        # Find the end of the START marker line
        newline_after_start = raw.index("\n", start_marker)
        text = newline_after_start ? raw[(newline_after_start + 1)..] : raw[(start_marker + 30)..]
      else
        text = raw
      end

      if end_marker
        text = text[0, text.index('*** END')] if text.index('*** END')
      end

      text = text.strip
      next if text.empty? || text.length < 200

      # Try to extract a title from the first few lines before the START marker
      title = "Unknown"
      header = start_marker ? raw[0, start_marker] : raw[0, 500]
      if header =~ /Title:\s*(.+)/
        title = $1.strip
      end

      out.puts "=== Gutenberg: #{title} (#{id}) ==="
      out.puts text
      out.puts
      stats[:gutenberg_ok] += 1

      puts "  [#{idx + 1}/#{gutenberg_ids.size}] Downloaded: #{title} (ID #{id}) — #{text.length} chars" if (idx + 1) % 10 == 0 || idx == gutenberg_ids.size - 1 || (idx + 1) <= 3
      sleep 1
    rescue => e
      stats[:gutenberg_fail] += 1
      puts "  [#{idx + 1}/#{gutenberg_ids.size}] FAILED ID #{id}: #{e.message}"
      sleep 0.5
    end
  end
end

# ── Final stats ──

file_size = File.size(OUTPUT_FILE)
size_mb = (file_size / 1_048_576.0).round(2)

puts "\n#{'=' * 60}"
puts "DOWNLOAD COMPLETE"
puts "#{'=' * 60}"
puts "Wikipedia articles: #{stats[:wiki_ok]} downloaded, #{stats[:wiki_fail]} failed"
puts "Gutenberg books:    #{stats[:gutenberg_ok]} downloaded, #{stats[:gutenberg_fail]} failed"
puts "Total sources:      #{stats[:wiki_ok] + stats[:gutenberg_ok]}"
puts "Output file:        #{OUTPUT_FILE}"
puts "File size:          #{size_mb} MB (#{file_size} bytes)"
puts "#{'=' * 60}"
