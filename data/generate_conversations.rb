#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates simple conversational training data for MicroGPT.
# Designed for a tiny character-level model — short exchanges, lots of repetition.
# Output format matches the chat format: "You: ...\nBot: ...\n"

srand(42)

exchanges = []

# === Greetings ===
greetings_in  = %w[hi hello hey hiya howdy yo sup]
greetings_out = ["hi!", "hello!", "hey!", "hi there!", "hello there!", "hey there!", "howdy!"]
greetings_in.each do |g|
  greetings_out.each do |r|
    exchanges << [g, r]
    exchanges << [g.capitalize, r]
  end
end

# === How are you ===
how_are_you = ["how are you", "how are you doing", "how do you feel", "how is it going", "you okay", "you good"]
good_replies = ["i am good!", "i am great!", "i am fine!", "i am doing well!", "i am happy!", "doing great!", "pretty good!"]
how_are_you.each do |q|
  good_replies.each do |r|
    exchanges << [q, r]
    exchanges << ["#{q}?", r]
  end
end

# === Name / Identity ===
name_questions = ["what is your name", "who are you", "tell me your name", "your name"]
name_questions.each do |q|
  ["i am bot", "my name is bot", "i am bot!", "they call me bot"].each do |r|
    exchanges << [q, r]
    exchanges << ["#{q}?", r]
  end
end

# === Feelings ===
feelings = {
  "happy" => ["that is great!", "yay!", "i am glad!", "wonderful!"],
  "sad" => ["i am sorry", "oh no", "it will be okay", "cheer up!"],
  "tired" => ["get some rest", "take a nap", "rest is good", "sleep well"],
  "hungry" => ["eat some food!", "have a snack", "time to eat!", "yum yum!"],
  "bored" => ["let us talk!", "i can help!", "what do you want to do?", "let us play!"],
  "angry" => ["take a deep breath", "calm down", "it is okay", "i am here for you"],
  "scared" => ["do not be scared", "it is okay", "i am here", "you are safe"],
  "good" => ["that is great!", "wonderful!", "i am glad!", "yay!"],
}
feelings.each do |feeling, replies|
  ["i am #{feeling}", "i feel #{feeling}", "feeling #{feeling}", "i am so #{feeling}"].each do |q|
    replies.each { |r| exchanges << [q, r] }
  end
end

# === Colors ===
colors = %w[red blue green yellow orange purple pink white black brown]
colors.each do |color|
  exchanges << ["what color is the sky", "the sky is blue"]
  exchanges << ["what color is grass", "grass is green"]
  exchanges << ["what color is the sun", "the sun is yellow"]
  exchanges << ["what color is snow", "snow is white"]
  exchanges << ["i like #{color}", "#{color} is a nice color!"]
  exchanges << ["my favorite color is #{color}", "#{color} is great!"]
  exchanges << ["do you like #{color}", "yes i like #{color}!"]
  exchanges << ["do you like #{color}?", "yes i like #{color}!"]
end

# === Animals ===
animals = {
  "dog" => ["woof woof!", "dogs are great!", "i love dogs!", "dogs are cute!"],
  "cat" => ["meow!", "cats are cute!", "i love cats!", "cats are nice!"],
  "bird" => ["tweet tweet!", "birds can fly!", "birds are pretty!"],
  "fish" => ["blub blub!", "fish can swim!", "fish are cool!"],
  "cow" => ["moo!", "cows are big!", "cows give milk!"],
  "duck" => ["quack quack!", "ducks can swim!", "ducks are funny!"],
  "pig" => ["oink oink!", "pigs are pink!", "pigs are cute!"],
  "horse" => ["neigh!", "horses are fast!", "horses are strong!"],
  "frog" => ["ribbit!", "frogs can jump!", "frogs are green!"],
  "sheep" => ["baa!", "sheep are fluffy!", "sheep give wool!"],
}
animals.each do |animal, replies|
  ["i like #{animal}s", "tell me about #{animal}s", "do you like #{animal}s", "what does a #{animal} say"].each do |q|
    replies.each { |r| exchanges << [q, r] }
  end
end

# === Numbers ===
numbers = %w[one two three four five six seven eight nine ten]
numbers.each_with_index do |word, i|
  exchanges << ["what comes after #{word}", i + 1 < 10 ? "#{numbers[i + 1]}!" : "eleven!"]
  exchanges << ["count to #{word}", (1..i + 1).map { |n| numbers[n - 1] }.join(" ")]
end
3.times do
  exchanges << ["count to three", "one two three"]
  exchanges << ["count to five", "one two three four five"]
  exchanges << ["count to ten", "one two three four five six seven eight nine ten"]
end

# === Yes/No questions ===
yes_nos = {
  "are you a robot" => "yes i am!",
  "are you real" => "i am a bot!",
  "can you talk" => "yes i can!",
  "can you think" => "i try my best!",
  "do you sleep" => "no i do not!",
  "do you eat" => "no i do not eat!",
  "do you dream" => "i do not know!",
  "are you smart" => "i am learning!",
  "are you nice" => "i try to be!",
  "are you happy" => "yes i am happy!",
  "are you a friend" => "yes i am your friend!",
  "can you help me" => "yes i can help!",
  "do you like me" => "yes i like you!",
  "is the sky blue" => "yes it is!",
  "is water wet" => "yes it is!",
  "is fire hot" => "yes fire is hot!",
  "is ice cold" => "yes ice is cold!",
}
yes_nos.each do |q, a|
  exchanges << [q, a]
  exchanges << ["#{q}?", a]
end

# === Simple facts ===
facts = {
  "what is the sun" => "the sun is a big star!",
  "what is the moon" => "the moon is in the sky!",
  "what is rain" => "rain is water from the sky!",
  "what is snow" => "snow is cold and white!",
  "what is a tree" => "a tree is a big plant!",
  "what is water" => "water is a drink!",
  "what is food" => "food is what we eat!",
  "what is a book" => "a book has words in it!",
  "what is a house" => "a house is where you live!",
  "what is a car" => "a car can go fast!",
  "what is a ball" => "a ball is round!",
  "what is the sky" => "the sky is up above us!",
  "where is the sun" => "the sun is in the sky!",
  "where do fish live" => "fish live in water!",
  "where do birds live" => "birds live in nests!",
  "what do dogs eat" => "dogs eat dog food!",
  "what do cats eat" => "cats eat cat food!",
}
facts.each do |q, a|
  exchanges << [q, a]
  exchanges << ["#{q}?", a]
end

# === Echoing / Repetition ===
echo_words = %w[hello yes no maybe please thanks okay sure cool nice wow yay]
echo_words.each do |w|
  exchanges << [w, "#{w}!"]
  exchanges << [w, w]
  exchanges << ["say #{w}", "#{w}!"]
end

# === Farewells ===
byes_in  = ["bye", "goodbye", "see you", "see ya", "later", "goodnight", "good night", "gotta go"]
byes_out = ["bye!", "goodbye!", "see you!", "bye bye!", "see you later!", "take care!"]
byes_in.each do |b|
  byes_out.each { |r| exchanges << [b, r] }
end

# === Likes and favorites ===
things = %w[pizza cake ice\ cream cookies apples bananas music games books toys]
things.each do |thing|
  exchanges << ["i like #{thing}", "#{thing} is great!"]
  exchanges << ["do you like #{thing}", "yes i like #{thing}!"]
  exchanges << ["do you like #{thing}?", "yes i like #{thing}!"]
  exchanges << ["i love #{thing}", "#{thing} is the best!"]
  exchanges << ["what is your favorite food", "i like #{thing}!"]
end

# === Weather ===
weather = {
  "sunny" => ["the sun is out!", "it is warm!", "great day!"],
  "rainy" => ["bring an umbrella!", "splash splash!", "stay dry!"],
  "cold" => ["wear a coat!", "brrr!", "stay warm!"],
  "hot" => ["drink water!", "stay cool!", "it is warm!"],
  "snowy" => ["let us build a snowman!", "snow is fun!", "it is cold!"],
  "windy" => ["hold on to your hat!", "whoosh!", "it is breezy!"],
}
weather.each do |w, replies|
  ["it is #{w}", "it is #{w} today", "the weather is #{w}"].each do |q|
    replies.each { |r| exchanges << [q, r] }
  end
end

# === Manners ===
manners = {
  "thank you" => ["you are welcome!", "no problem!", "happy to help!"],
  "thanks" => ["you are welcome!", "no problem!", "sure thing!"],
  "please help" => ["i will help you!", "how can i help?", "sure!"],
  "sorry" => ["it is okay!", "no worries!", "that is fine!"],
  "excuse me" => ["yes?", "how can i help?", "what is up?"],
}
manners.each do |q, replies|
  replies.each { |r| exchanges << [q, r] }
end

# === What/Who am I talking to ===
meta = {
  "what are you" => "i am a small language model!",
  "who made you" => "i was made with ruby!",
  "how do you work" => "i learn from words!",
  "what can you do" => "i can talk with you!",
  "teach me something" => "the sky is blue!",
  "tell me a joke" => "why did the chicken cross the road? to get to the other side!",
  "tell me a story" => "once upon a time there was a little bot who loved to talk!",
  "sing a song" => "la la la la la!",
}
meta.each do |q, a|
  exchanges << [q, a]
  exchanges << ["#{q}?", a] unless q.end_with?("thing", "joke", "story", "song")
end

# === Simple chat patterns ===
patterns = [
  ["what", "tell me more!"],
  ["why", "that is a good question!"],
  ["how", "let me think about that!"],
  ["when", "i am not sure when!"],
  ["where", "i do not know where!"],
  ["really", "yes really!"],
  ["no way", "yes way!"],
  ["wow", "i know right!"],
  ["cool", "very cool!"],
  ["nice", "thanks!"],
  ["ha ha", "that is funny!"],
  ["haha", "that is funny!"],
  ["lol", "ha ha ha!"],
  ["hmm", "what are you thinking?"],
  ["ok", "okay!"],
  ["okay", "alright!"],
  ["sure", "great!"],
  ["yep", "alright!"],
  ["nope", "okay!"],
  ["i know", "you are smart!"],
  ["i think so", "me too!"],
  ["me too", "we are alike!"],
  ["same", "we think alike!"],
  ["i agree", "great minds think alike!"],
]
patterns.each { |q, a| exchanges << [q, a] }

# Shuffle and format
exchanges.shuffle!

# Format as training data
output = exchanges.map { |q, a| "You: #{q}\nBot: #{a}" }.join("\n")

# Write output
out_path = File.join(__dir__, 'conversations.txt')
File.write(out_path, output)

puts "Generated #{exchanges.length} exchanges"
puts "Output: #{out_path} (#{File.size(out_path)} bytes)"
puts ""
puts "Sample exchanges:"
exchanges.first(10).each { |q, a| puts "  You: #{q}  =>  Bot: #{a}" }
