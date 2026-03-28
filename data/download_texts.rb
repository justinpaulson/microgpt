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
  "Animals" => %w[Dog Cat Elephant Whale Dolphin Lion Eagle Shark Octopus Penguin
                   Horse Rabbit Spider Bee Ant Butterfly Wolf Bear Snake Turtle
                   Parrot Hamster Mouse Deer Zebra Giraffe Hippo Crocodile Kangaroo Koala],
  "Geography" => ["Africa", "Asia", "Europe", "North America", "South America",
                   "Australia", "Antarctica", "Pacific Ocean", "Atlantic Ocean",
                   "Mediterranean Sea", "Amazon River", "Nile", "Mississippi River",
                   "Mount Everest", "Grand Canyon", "Sahara", "Arctic",
                   "Great Wall of China", "Niagara Falls", "Great Barrier Reef"],
  "Countries" => ["United States", "United Kingdom", "France", "Germany", "Japan",
                   "China", "India", "Brazil", "Mexico", "Canada", "Italy", "Spain",
                   "Australia", "Russia", "Egypt"],
  "Science" => %w[Sun Moon Earth Water Light Gravity Atom Electricity Volcano Earthquake
                   DNA Cell Bacteria Virus Planet Mars Jupiter Saturn Venus Mercury
                   Neptune Comet Asteroid Fossil Mineral Crystal Magnet Battery Lens
                   Microscope Telescope],
  "Nature"  => %w[Ocean Mountain Forest River Desert Rain Snow Cloud Star],
  "History" => ["World War I", "World War II", "Renaissance", "Industrial Revolution",
                "Ancient Greece", "Ancient Rome", "Vikings", "Medieval",
                "Christopher Columbus", "Printing press", "Steam engine",
                "Wright brothers", "Neil Armstrong", "Martin Luther King Jr."],
  "People" => ["Albert Einstein", "Marie Curie", "Dinosaur"],
  "Technology" => %w[Robot Satellite] + ["Solar panel", "Windmill", "Bridge", "Dam",
                  "Railway", "Rapid transit", "Helicopter", "Rocket",
                  "International Space Station", "Radio", "Television", "Camera", "Printing"],
  "Food" => %w[Bread Rice Wheat Corn Potato Tomato Chocolate Coffee Tea Sugar Salt
               Cheese Milk Egg Honey],
  "Body/Health" => %w[Brain Heart Lung Blood Bone Muscle Skin Eye Ear Tooth Vitamin
                      Exercise Sleep Nutrition],
  "Arts" => %w[Painting Sculpture Music Dance Theater Poetry Novel Film Photography Architecture],
  "Sports" => ["Football", "Basketball", "Baseball", "Tennis", "Swimming", "Running",
               "Olympic Games", "Association football", "Cricket", "Chess"],
  "Things" => %w[Computer Internet Book Food House Car Airplane Telephone]
}

def fetch_wiki_article(title, max_chars = 3000)
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
  # Keep only first ~max_chars characters, breaking at a sentence boundary if possible
  if cleaned.length > max_chars
    cut = cleaned[0, max_chars + 200]
    last_period = cut.rindex(".")
    cleaned = last_period && last_period > (max_chars - 500) ? cut[0..last_period] : cut[0, max_chars]
  end

  cleaned
end

# ── Project Gutenberg books ─────────────────────────────────────────────────

GUTENBERG_BOOKS = {
  "Aesop's Fables"             => "https://www.gutenberg.org/cache/epub/11339/pg11339.txt",
  "Alice in Wonderland"        => "https://www.gutenberg.org/cache/epub/11/pg11.txt",
  "Peter Pan"                  => "https://www.gutenberg.org/cache/epub/16/pg16.txt",
  "The Wonderful Wizard of Oz" => "https://www.gutenberg.org/cache/epub/55/pg55.txt",
  "Grimm's Fairy Tales"        => "https://www.gutenberg.org/cache/epub/2591/pg2591.txt",
  "A Christmas Carol"          => "https://www.gutenberg.org/cache/epub/46/pg46.txt",
  "The Jungle Book"            => "https://www.gutenberg.org/cache/epub/236/pg236.txt",
  "Treasure Island"            => "https://www.gutenberg.org/cache/epub/120/pg120.txt",
  "The Wind in the Willows"    => "https://www.gutenberg.org/cache/epub/289/pg289.txt",
  "Anne of Green Gables"       => "https://www.gutenberg.org/cache/epub/45/pg45.txt",
  "Black Beauty"               => "https://www.gutenberg.org/cache/epub/271/pg271.txt",
  "Robinson Crusoe"            => "https://www.gutenberg.org/cache/epub/521/pg521.txt",
  "The Secret Garden"          => "https://www.gutenberg.org/cache/epub/113/pg113.txt",
  "Little Women"               => "https://www.gutenberg.org/cache/epub/514/pg514.txt",
  "The Adventures of Tom Sawyer" => "https://www.gutenberg.org/cache/epub/74/pg74.txt",
  "20000 Leagues Under the Sea" => "https://www.gutenberg.org/cache/epub/164/pg164.txt",
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

source_count = 0
failures = 0
bytes_written = 0

# Record initial file size
initial_size = File.exist?(OUTPUT_FILE) ? File.size(OUTPUT_FILE) : 0

puts "=" * 60
puts "Downloading training texts (APPEND mode)"
puts "Existing file size: #{initial_size} bytes (#{(initial_size / 1024.0).round(1)} KB)"
puts "=" * 60

# Open file in APPEND mode
outfile = File.open(OUTPUT_FILE, "a")

# Count total wiki topics for progress
total_wiki = WIKI_TOPICS.values.flatten.length
wiki_done = 0

# 1. Wikipedia
WIKI_TOPICS.each do |category, titles|
  puts "\n── Wikipedia: #{category} (#{titles.length} articles) ──"
  titles.each do |title|
    wiki_done += 1
    print "  [#{wiki_done}/#{total_wiki}] Fetching '#{title}'... "
    begin
      text = fetch_wiki_article(title, 3000)
      if text && !text.empty?
        chunk = "\n\n\n=== Wikipedia: #{title} ===\n\n#{text}"
        outfile.write(chunk)
        bytes_written += chunk.bytesize
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
puts "\n── Project Gutenberg Books (#{GUTENBERG_BOOKS.length} books) ──"
book_i = 0
GUTENBERG_BOOKS.each do |title, url|
  book_i += 1
  print "  [#{book_i}/#{GUTENBERG_BOOKS.length}] Fetching '#{title}'... "
  begin
    text = fetch_gutenberg_book(title, url)
    if text && !text.empty?
      chunk = "\n\n\n=== Book: #{title} ===\n\n#{text}"
      outfile.write(chunk)
      bytes_written += chunk.bytesize
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

outfile.close

# 3. Final stats
final_size = File.size(OUTPUT_FILE)
puts "\n" + "=" * 60
puts "Done!"
puts "  Sources downloaded: #{source_count}"
puts "  Failures/skipped:   #{failures}"
puts "  Bytes appended:     #{bytes_written} (#{(bytes_written / 1024.0).round(1)} KB)"
puts "  Output file:        #{OUTPUT_FILE}"
puts "  Previous size:      #{initial_size} bytes (#{(initial_size / 1024.0).round(1)} KB)"
puts "  Final file size:    #{final_size} bytes (#{(final_size / 1024.0 / 1024.0).round(2)} MB)"
puts "=" * 60
