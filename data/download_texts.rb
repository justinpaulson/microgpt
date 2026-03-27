#!/usr/bin/env ruby
# download_texts.rb — Download free-use texts for language model training
# Uses only Ruby stdlib (open-uri, json, net/http, uri)

require 'open-uri'
require 'json'
require 'net/http'
require 'uri'

OUTPUT_FILE = File.join(__dir__, "real_texts.txt")

# ── Wikipedia articles via Simple English Wikipedia ──────────────────────────

WIKI_TOPICS = {
  "Animals" => %w[Dog Cat Elephant Whale Dolphin Lion Eagle Shark Octopus Penguin],
  "Science" => %w[Sun Moon Earth Water Light Gravity Atom Electricity Volcano Earthquake],
  "Nature"  => %w[Ocean Mountain Forest River Desert Rain Snow Cloud Star Planet],
  "People/History" => ["Albert Einstein", "Marie Curie", "Ancient Egypt", "Roman Empire", "Dinosaur"],
  "Things"  => %w[Computer Internet Book Music Food House Car Airplane Telephone Telescope]
}

def fetch_wiki_article(title)
  encoded = URI.encode_www_form_component(title)
  url = "https://simple.wikipedia.org/w/api.php?action=query&titles=#{encoded}&prop=extracts&explaintext&format=json"

  uri = URI(url)
  response = Net::HTTP.get(uri)
  data = JSON.parse(response)

  pages = data.dig("query", "pages") || {}
  page = pages.values.first
  return nil if page.nil? || page.key?("missing")

  text = page["extract"].to_s.strip
  return nil if text.empty?

  # Filter out lines that are just section headers or very short (< 20 chars)
  lines = text.split("\n").reject { |l|
    stripped = l.strip
    stripped.empty? ||
    stripped.match?(/\A={2,}.*={2,}\z/) ||    # == Header ==
    (stripped.length < 20 && !stripped.end_with?("."))
  }

  cleaned = lines.join("\n").strip
  # Keep only first ~2000 characters, breaking at a sentence boundary if possible
  if cleaned.length > 2000
    cut = cleaned[0, 2200]
    last_period = cut.rindex(".")
    cleaned = last_period && last_period > 1500 ? cut[0..last_period] : cut[0, 2000]
  end

  cleaned
end

# ── Project Gutenberg books ─────────────────────────────────────────────────

GUTENBERG_BOOKS = {
  "Aesop's Fables"           => "https://www.gutenberg.org/cache/epub/11339/pg11339.txt",
  "Alice in Wonderland"      => "https://www.gutenberg.org/cache/epub/11/pg11.txt",
  "Peter Pan"                => "https://www.gutenberg.org/cache/epub/16/pg16.txt",
  "The Wonderful Wizard of Oz" => "https://www.gutenberg.org/cache/epub/55/pg55.txt",
  "Grimm's Fairy Tales"      => "https://www.gutenberg.org/cache/epub/2591/pg2591.txt",
  "A Christmas Carol"        => "https://www.gutenberg.org/cache/epub/46/pg46.txt",
}

def fetch_gutenberg_book(title, url)
  uri = URI(url)
  raw = Net::HTTP.get(uri)
  # Force to UTF-8, replacing invalid bytes
  raw = raw.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")

  # Strip Project Gutenberg header and footer
  start_marker = raw.index("*** START")
  end_marker   = raw.index("*** END")

  if start_marker
    # Move past the marker line
    newline_after_start = raw.index("\n", start_marker)
    raw = raw[(newline_after_start + 1)..]  if newline_after_start
  end

  if end_marker
    raw = raw[0...end_marker]
  end

  raw.strip
end

# ── Main ────────────────────────────────────────────────────────────────────

all_text = []
source_count = 0
failures = 0

puts "=" * 60
puts "Downloading training texts"
puts "=" * 60

# 1. Wikipedia
WIKI_TOPICS.each do |category, titles|
  puts "\n── Wikipedia: #{category} ──"
  titles.each do |title|
    print "  Fetching '#{title}'... "
    begin
      text = fetch_wiki_article(title)
      if text && !text.empty?
        all_text << "=== Wikipedia: #{title} ===\n\n#{text}"
        source_count += 1
        puts "OK (#{text.length} chars)"
      else
        puts "EMPTY (skipped)"
        failures += 1
      end
    rescue => e
      puts "ERROR: #{e.message}"
      failures += 1
    end
    sleep 1  # polite delay between API calls
  end
end

# 2. Gutenberg
puts "\n── Project Gutenberg Books ──"
GUTENBERG_BOOKS.each do |title, url|
  print "  Fetching '#{title}'... "
  begin
    text = fetch_gutenberg_book(title, url)
    if text && !text.empty?
      all_text << "=== Book: #{title} ===\n\n#{text}"
      source_count += 1
      puts "OK (#{text.length} chars)"
    else
      puts "EMPTY (skipped)"
      failures += 1
    end
  rescue => e
    puts "ERROR: #{e.message}"
    failures += 1
  end
  sleep 1
end

# 3. Write output
puts "\n" + "=" * 60
puts "Writing to #{OUTPUT_FILE}..."

combined = all_text.join("\n\n\n")
File.write(OUTPUT_FILE, combined)

file_size = File.size(OUTPUT_FILE)
puts "\nDone!"
puts "  Sources downloaded: #{source_count}"
puts "  Failures/skipped:   #{failures}"
puts "  Output file:        #{OUTPUT_FILE}"
puts "  File size:          #{file_size} bytes (#{(file_size / 1024.0).round(1)} KB)"
puts "=" * 60
