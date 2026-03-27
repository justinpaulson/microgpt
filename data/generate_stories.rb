#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates simple training data for a tiny character-level language model.
# Designed for 64-char context window, 138K params.
# Produces very short, repetitive, simple text — stories, facts, chat, patterns.

srand(42)

segments = []

# ============================================================================
# WORD BANKS
# ============================================================================

animals       = %w[cat dog bird fish frog duck cow pig hen bee ant fox rat bat owl]
colors        = %w[red blue green big small soft warm cold fast slow happy sad old new]
adjectives    = %w[happy sad big small soft warm cold fast slow nice good bad old new pretty cute fun]
names         = %w[sam tom max ben joe kim sue ann meg pat dan mom dad nan pop]
foods         = %w[apple cake pie egg milk rice soup nut jam fig plum corn bean pea bun]
places        = %w[park home lake hill farm pond barn cave den nest town path road]
body_parts    = %w[nose eyes ears head hand foot arm leg back toes face chin lips]
toys          = %w[ball doll drum kite top bear car boat hat cup box bell]
actions       = %w[ran sat ate saw hid dug jumped played slept sang danced walked]
weather_words = %w[sun rain snow wind fog ice hail dew mist]
shapes        = %w[round flat long thin wide tall]

# ============================================================================
# 1. VERY SHORT TODDLER STORIES (3-5 sentences each)
# ============================================================================

# --- Animal stories ---
animals.each do |a|
  adjectives.sample(6).each do |adj|
    segments << "the #{a} sat down. the #{a} was #{adj}. the end."
    segments << "i see a #{a}. the #{a} is #{adj}. i like the #{a}."
  end

  segments << "the #{a} went for a walk. it was fun. the end."
  segments << "the #{a} was lost. then it got home. the end."
  segments << "the #{a} was sleepy. it took a nap. sleep well!"
  segments << "the #{a} was hungry. it ate food. yum! the end."
  segments << "the #{a} played all day. time to rest. good night!"
  segments << "a little #{a} sat in the sun. it was warm and nice."
  segments << "the #{a} ran fast. it ran and ran. then it sat down to rest."
  segments << "the #{a} saw a bug. the bug was small. the #{a} liked the bug."
  segments << "the #{a} had a friend. they played all day. they were happy."
  segments << "one #{a}. two #{a}s. three #{a}s. so many #{a}s!"
end

# --- Daily routine stories ---
routines = [
  "it was morning. the sun came up. time to wake up!",
  "it was time to eat. the food was good. yum yum!",
  "it was bath time. the water was warm. splash splash!",
  "it was time for bed. the moon was out. good night!",
  "it was time to play. the toys were fun. what a good day!",
  "it was time to go. put on your shoes. off we go!",
  "it was lunch time. we had soup. it was yummy!",
  "it was nap time. close your eyes. sleep well.",
  "it was morning. time to get up. the sun is out!",
  "it was night. the stars came out. so pretty!",
]
# Repeat routines many times
10.times { routines.each { |r| segments << r } }

# --- Simple adventure stories ---
animals.each do |a|
  places.each do |p|
    segments << "the #{a} went to the #{p}. it was fun. the #{a} came home."
    segments << "the #{a} ran to the #{p}. it saw a bug. then it came back."
  end
end

# --- Weather / nature stories ---
weather_stories = [
  "it was raining. the flowers were happy. rain is good.",
  "the sun was out. it was warm. what a nice day!",
  "it was snowing. the snow was white. so cold!",
  "the wind blew hard. hold on to your hat! what a windy day.",
  "the sky was blue. the clouds were white. a pretty day.",
  "it was foggy out. i could not see far. the fog was thick.",
  "the rain stopped. the sun came out. i see a rainbow!",
  "it was a cold day. time to stay warm. put on a coat.",
  "it was a hot day. time to swim. the water was cool.",
  "the leaves fell down. it was fall. the leaves were red and gold.",
]
15.times { weather_stories.each { |w| segments << w } }

# --- Food / eating stories ---
foods.each do |f|
  segments << "the boy ate a #{f}. it was yummy! he wanted more."
  segments << "the girl ate a #{f}. it was so good! she smiled."
  segments << "mom made #{f}. it was hot. we all ate #{f}. yum!"
  segments << "i like #{f}. #{f} is good. i want more #{f}."
  segments << "do you like #{f}? i love #{f}! #{f} is the best."
  segments << "time to eat! we have #{f}. eat up!"
end

# --- Bedtime stories ---
bedtime = [
  "it was night time. the moon was bright. good night!",
  "time for bed. close your eyes. sweet dreams!",
  "the stars came out. the night was calm. good night.",
  "the sun went down. it was dark now. time to sleep.",
  "good night moon. good night stars. good night world.",
  "hush now. it is time to rest. close your eyes.",
  "the day is done. time to sleep. see you in the morning.",
  "the owl said hoo. the night was still. sleep well.",
  "one more story. then we sleep. good night little one.",
  "the moon is up. the world is quiet. dream big!",
]
15.times { bedtime.each { |b| segments << b } }

# ============================================================================
# 2. SIMPLE FACTUAL STATEMENTS
# ============================================================================

# --- Colors ---
color_facts = {
  "sky" => "blue", "grass" => "green", "sun" => "yellow",
  "snow" => "white", "coal" => "black", "fire" => "red",
  "milk" => "white", "dirt" => "brown", "gold" => "gold",
  "night" => "dark", "day" => "bright", "sea" => "blue",
}
color_facts.each do |thing, color|
  5.times do
    segments << "the #{thing} is #{color}."
    segments << "#{thing} is #{color}."
  end
end

# --- Animal sounds ---
sounds = {
  "dog" => "woof", "cat" => "meow", "cow" => "moo",
  "duck" => "quack", "pig" => "oink", "hen" => "cluck",
  "bee" => "buzz", "owl" => "hoo", "frog" => "ribbit",
  "bird" => "tweet", "sheep" => "baa", "horse" => "neigh",
}
sounds.each do |animal, sound|
  5.times do
    segments << "the #{animal} says #{sound}."
    segments << "#{animal}s say #{sound}."
    segments << "#{sound} #{sound}! said the #{animal}."
  end
end

# --- Where animals live ---
habitats = {
  "fish" => "water", "bird" => "a nest", "bear" => "a cave",
  "dog" => "a house", "fox" => "a den", "bee" => "a hive",
  "ant" => "a hill", "frog" => "a pond", "bat" => "a cave",
  "owl" => "a tree", "hen" => "a coop", "pig" => "a pen",
}
habitats.each do |animal, place|
  5.times do
    segments << "the #{animal} lives in #{place}."
    segments << "#{animal}s live in #{place}."
  end
end

# --- Simple math ---
math_words = %w[zero one two three four five six seven eight nine ten]
10.times do
  (0..5).each do |a|
    (0..5).each do |b|
      sum = a + b
      next if sum > 10
      segments << "#{math_words[a]} and #{math_words[b]} is #{math_words[sum]}."
    end
  end
end

# --- Counting ---
8.times do
  segments << "one. two. three."
  segments << "one. two. three. four. five."
  segments << "one two three four five six seven eight nine ten."
  segments << "count with me. one. two. three. four. five!"
end

# --- Body parts ---
5.times do
  body_parts.each do |part|
    segments << "i have a #{part}. you have a #{part} too."
    segments << "this is my #{part}."
  end
end

# --- Shapes ---
things_with_shapes = { "ball" => "round", "box" => "flat", "rope" => "long",
                       "stick" => "long", "rock" => "hard", "leaf" => "thin" }
things_with_shapes.each do |thing, shape|
  5.times do
    segments << "the #{thing} is #{shape}."
    segments << "a #{thing} is #{shape}."
  end
end

# --- Family ---
family = %w[mom dad sis bro nan pop]
5.times do
  family.each do |f|
    segments << "i love #{f}. #{f} is the best."
    segments << "#{f} is kind. i love #{f}."
    segments << "#{f} loves me. i love #{f} too."
  end
end

# --- Opposites ---
opposites = [
  %w[big small], %w[hot cold], %w[fast slow], %w[up down],
  %w[in out], %w[on off], %w[yes no], %w[day night],
  %w[old new], %w[good bad], %w[hard soft], %w[wet dry],
  %w[tall short], %w[long thin], %w[dark light], %w[open shut],
]
5.times do
  opposites.each do |a, b|
    segments << "#{a} and #{b}. #{b} and #{a}."
    segments << "not #{a} but #{b}."
  end
end

# --- Days of the week ---
days = %w[monday tuesday wednesday thursday friday saturday sunday]
5.times do
  segments << "today is #{days.sample}."
  days.each do |d|
    segments << "today is #{d}. tomorrow is #{days[(days.index(d) + 1) % 7]}."
  end
end

# --- Seasons ---
seasons_text = [
  "spring is warm. flowers grow in spring.",
  "summer is hot. we swim in summer.",
  "fall is cool. leaves fall in fall.",
  "winter is cold. snow falls in winter.",
]
10.times { seasons_text.each { |s| segments << s } }

# ============================================================================
# 3. CONVERSATIONAL EXCHANGES (You: / Bot: format)
# ============================================================================

chats = []

# --- Story requests ---
animals.each do |a|
  adjectives.sample(3).each do |adj|
    chats << ["tell me a story", "once there was a #{adj} #{a}. the #{a} was #{adj}. the end!"]
    chats << ["tell me about a #{a}", "the #{a} is #{adj}. i like #{a}s!"]
  end
  chats << ["tell me a story about a #{a}", "the #{a} went for a walk. it was fun. the end!"]
end

# --- Question and answer about facts ---
color_facts.each do |thing, color|
  chats << ["what color is the #{thing}", "the #{thing} is #{color}!"]
  chats << ["what color is #{thing}", "#{thing} is #{color}!"]
end

sounds.each do |animal, sound|
  chats << ["what does a #{animal} say", "a #{animal} says #{sound}!"]
  chats << ["what sound does a #{animal} make", "#{sound} #{sound}!"]
end

habitats.each do |animal, place|
  chats << ["where does a #{animal} live", "a #{animal} lives in #{place}!"]
  chats << ["where do #{animal}s live", "#{animal}s live in #{place}!"]
end

# --- Simple Q&A ---
simple_qa = [
  ["what is your name", "i am bot!"],
  ["who are you", "i am a little bot!"],
  ["how are you", "i am good!"],
  ["are you happy", "yes i am happy!"],
  ["do you like me", "yes i like you!"],
  ["what do you do", "i talk to you!"],
  ["can you help me", "yes i can help!"],
  ["are you smart", "i am learning!"],
  ["are you real", "i am a bot!"],
  ["what can you do", "i can talk with you!"],
  ["tell me a joke", "why did the hen cross the road? to get to the other side!"],
  ["say hi", "hi!"],
  ["say hello", "hello!"],
  ["say bye", "bye bye!"],
]
5.times { simple_qa.each { |q, a| chats << [q, a] } }

# --- Greetings ---
greet_in = %w[hi hello hey hiya howdy]
greet_out = ["hi!", "hello!", "hey!", "hi there!", "hello!"]
5.times do
  greet_in.each_with_index do |g, i|
    chats << [g, greet_out[i % greet_out.length]]
  end
end

# --- Farewells ---
bye_in = ["bye", "goodbye", "see you", "good night", "later"]
bye_out = ["bye!", "goodbye!", "see you!", "good night!", "bye bye!"]
5.times do
  bye_in.each_with_index do |b, i|
    chats << [b, bye_out[i % bye_out.length]]
  end
end

# --- Feelings ---
5.times do
  chats << ["i am happy", "that is great!"]
  chats << ["i am sad", "oh no! it will be okay."]
  chats << ["i am tired", "get some rest!"]
  chats << ["i am hungry", "time to eat!"]
  chats << ["i am bored", "let us talk!"]
  chats << ["i am scared", "it is okay. you are safe."]
  chats << ["i am cold", "put on a coat!"]
  chats << ["i am hot", "drink some water!"]
end

# --- What is ... ---
what_is = {
  "the sun" => "the sun is a big star!",
  "the moon" => "the moon is in the sky!",
  "rain" => "rain is water from the sky!",
  "snow" => "snow is cold and white!",
  "a tree" => "a tree is a big plant!",
  "water" => "water is what we drink!",
  "food" => "food is what we eat!",
  "a book" => "a book has words in it!",
  "a ball" => "a ball is round!",
  "a house" => "a house is where you live!",
  "a car" => "a car can go fast!",
  "fire" => "fire is hot!",
  "ice" => "ice is cold!",
}
3.times do
  what_is.each do |thing, answer|
    chats << ["what is #{thing}", answer]
  end
end

# --- Likes ---
foods.each do |f|
  chats << ["i like #{f}", "#{f} is yummy!"]
  chats << ["do you like #{f}", "yes i like #{f}!"]
end

# --- Colors ---
color_names = %w[red blue green yellow pink purple orange white black brown]
color_names.each do |c|
  chats << ["i like #{c}", "#{c} is a nice color!"]
  chats << ["my favorite color is #{c}", "#{c} is great!"]
  chats << ["do you like #{c}", "yes i like #{c}!"]
end

# --- Thank you / manners ---
5.times do
  chats << ["thank you", "you are welcome!"]
  chats << ["thanks", "no problem!"]
  chats << ["sorry", "it is okay!"]
  chats << ["please help", "how can i help?"]
  chats << ["please", "what can i do?"]
end

# --- Weather chat ---
3.times do
  chats << ["is it sunny", "yes the sun is out!"]
  chats << ["is it raining", "i do not know! look outside."]
  chats << ["is it cold", "put on a coat just in case!"]
  chats << ["is it hot", "drink some water!"]
  chats << ["what is the weather", "i hope it is nice out!"]
end

# --- Numbers / counting ---
3.times do
  chats << ["count to three", "one two three!"]
  chats << ["count to five", "one two three four five!"]
  chats << ["count to ten", "one two three four five six seven eight nine ten!"]
  chats << ["what is one and one", "one and one is two!"]
  chats << ["what is two and two", "two and two is four!"]
  chats << ["what is two and three", "two and three is five!"]
end

# Format chat segments
chats.each do |q, a|
  segments << "You: #{q}\nBot: #{a}"
end

# ============================================================================
# 4. REPETITIVE PATTERNS (crucial for small model learning)
# ============================================================================

# --- "i see a [animal]. the [animal] is [adjective]." ---
animals.each do |a|
  adjectives.each do |adj|
    segments << "i see a #{a}. the #{a} is #{adj}."
  end
end

# --- "the [color] [thing] is [adjective]." ---
color_names_adj = %w[red blue green big small old new]
thing_nouns = %w[ball box cup hat bag car bus van rug bed mat pot pan jar lid]
color_names_adj.each do |c|
  thing_nouns.each do |t|
    adjectives.sample(3).each do |adj|
      segments << "the #{c} #{t} is #{adj}."
    end
  end
end

# --- "[name] has a [pet]. [name] loves the [pet]." ---
pets = %w[cat dog bird fish frog duck]
names.each do |name|
  pets.each do |pet|
    segments << "#{name} has a #{pet}. #{name} loves the #{pet}."
    segments << "#{name} saw a #{pet}. the #{pet} was cute."
    segments << "#{name} and the #{pet} played. they had fun."
  end
end

# --- "one [thing]. two [things]. three [things]." ---
count_things = {
  "cat" => "cats", "dog" => "dogs", "bird" => "birds",
  "ball" => "balls", "cup" => "cups", "hat" => "hats",
  "egg" => "eggs", "bug" => "bugs", "star" => "stars",
  "fish" => "fish", "box" => "boxes", "fox" => "foxes",
}
3.times do
  count_things.each do |s, p|
    segments << "one #{s}. two #{p}. three #{p}."
    segments << "one #{s}. two #{p}. three #{p}. four #{p}. five #{p}."
    segments << "i have one #{s}. you have two #{p}."
  end
end

# --- "the [animal] can [verb]." ---
can_do = {
  "cat" => %w[run jump purr sit nap],
  "dog" => %w[run jump bark sit dig],
  "bird" => %w[fly sing hop sit],
  "fish" => %w[swim dive hide],
  "frog" => %w[jump swim hop sit],
  "duck" => %w[swim fly quack waddle],
  "cow" => %w[moo walk eat run],
  "pig" => %w[oink dig eat run],
  "hen" => %w[cluck peck sit lay],
  "bee" => %w[buzz fly sting hum],
}
3.times do
  can_do.each do |animal, verbs|
    verbs.each do |verb|
      segments << "the #{animal} can #{verb}. #{verb} #{animal} #{verb}!"
      segments << "can the #{animal} #{verb}? yes it can!"
    end
  end
end

# --- "[thing] is [adjective]. i like [thing]." ---
simple_things = %w[sun moon rain snow wind day night sky sea land]
3.times do
  simple_things.each do |thing|
    adjectives.sample(4).each do |adj|
      segments << "the #{thing} is #{adj}. i like the #{thing}."
    end
  end
end

# --- "i like [thing]. do you like [thing]?" ---
like_things = %w[cats dogs birds fish rain sun snow moon stars toys games books cake pie milk]
5.times do
  like_things.each do |thing|
    segments << "i like #{thing}. do you like #{thing}?"
    segments << "i love #{thing}. #{thing} are the best!"
  end
end

# --- Action patterns ---
5.times do
  names.each do |name|
    actions.each do |act|
      segments << "#{name} #{act}. it was fun."
    end
  end
end

# --- More "once upon a time" micro-stories ---
animals.each do |a|
  adjectives.sample(4).each do |adj|
    segments << "once upon a time there was a #{adj} #{a}. the end."
    segments << "once there was a #{a}. the #{a} was #{adj}. the end."
  end
end

# --- Rhyme-like patterns ---
rhymes = [
  "the cat sat on the mat.",
  "the dog sat on the log.",
  "the hen sat in the den.",
  "the bug sat on the rug.",
  "the fox hid in the box.",
  "the bee sat in the tree.",
  "the pig did a jig.",
  "the bat sat on the hat.",
  "the rat sat on the mat.",
  "the ant ran to the plant.",
  "the snail went on the trail.",
  "the pup drank from the cup.",
  "the man ran and ran.",
]
15.times { rhymes.each { |r| segments << r } }

# --- Yes/no patterns ---
5.times do
  animals.each do |a|
    segments << "is it a #{a}? yes it is a #{a}!"
    segments << "is it a #{a}? no it is not a #{a}."
    segments << "do you see a #{a}? yes i see a #{a}!"
  end
end

# --- This is / that is patterns ---
3.times do
  animals.each do |a|
    segments << "this is a #{a}. that is a #{a} too."
    segments << "look! a #{a}! the #{a} is here."
  end
  foods.each do |f|
    segments << "this is #{f}. i like #{f}."
  end
  toys.each do |t|
    segments << "this is a #{t}. the #{t} is fun."
    segments << "i have a #{t}. do you have a #{t}?"
  end
end

# --- Where is patterns ---
3.times do
  animals.each do |a|
    places.each_slice(3) do |ps|
      p = ps.sample
      segments << "where is the #{a}? the #{a} is at the #{p}."
    end
  end
end

# --- Color + animal patterns ---
color_names.each do |c|
  animals.each do |a|
    segments << "the #{c} #{a}. i see a #{c} #{a}."
    segments << "look at the #{c} #{a}! it is so #{c}!"
  end
end

# --- Alphabet / letters ---
5.times do
  segments << "a b c d e f g."
  segments << "h i j k l m n o p."
  segments << "q r s t u v w."
  segments << "x y z."
  segments << "a b c d e f g h i j k l m n o p q r s t u v w x y z."
  ('a'..'z').each do |letter|
    segments << "#{letter} is a letter."
  end
end

# --- "I am" patterns ---
5.times do
  adjectives.each do |adj|
    segments << "i am #{adj}. are you #{adj} too?"
    segments << "i am #{adj}. you are #{adj} too."
  end
end

# --- Question word patterns ---
q_patterns = [
  "who is that? it is a friend.",
  "what is that? it is a toy.",
  "where is it? it is here.",
  "when is it? it is now.",
  "why is that? i do not know.",
  "how is that? it is good.",
  "who did it? i did it!",
  "what did you do? i played!",
  "where did you go? i went to the park.",
  "when did you go? i went today.",
]
10.times { q_patterns.each { |q| segments << q } }

# --- Emotion patterns ---
emotions = %w[happy sad glad mad shy brave kind mean calm wild]
5.times do
  emotions.each do |e|
    segments << "i feel #{e}. it is okay to feel #{e}."
    segments << "the boy is #{e}. the girl is #{e} too."
    segments << "are you #{e}? yes i am #{e}."
  end
end

# --- More action stories ---
verbs = %w[ran jumped played ate slept sang danced clapped walked sat]
5.times do
  names.each do |name|
    verbs.sample(4).each do |verb|
      segments << "#{name} #{verb}. it was fun."
    end
  end
end

# --- Possession patterns ---
3.times do
  names.each do |name|
    toys.each do |toy|
      segments << "#{name} has a #{toy}. the #{toy} is #{adjectives.sample}."
    end
  end
end

# --- Time patterns ---
times_of_day = ["morning", "noon", "night", "bedtime", "daytime"]
5.times do
  times_of_day.each do |t|
    segments << "it is #{t}. what do we do at #{t}?"
    segments << "it is #{t} now."
  end
end

# --- More short declarative facts ---
extra_facts = [
  "the sky is up. the ground is down.",
  "water is wet. fire is hot.",
  "ice is cold. the sun is warm.",
  "trees are tall. bugs are small.",
  "dogs are pets. cats are pets too.",
  "fish can swim. birds can fly.",
  "we eat food. we drink water.",
  "we sleep at night. we play in the day.",
  "the moon is out at night.",
  "the sun is out in the day.",
  "i have two eyes. i have two ears.",
  "i have one nose. i have one mouth.",
  "i have ten toes. i have ten fingers.",
  "milk is white. the sky is blue.",
  "apples are red. bananas are yellow.",
  "grass is green. dirt is brown.",
  "we walk with our feet.",
  "we see with our eyes.",
  "we hear with our ears.",
  "books have words. words have letters.",
]
15.times { extra_facts.each { |f| segments << f } }

# ============================================================================
# SHUFFLE AND WRITE
# ============================================================================

segments.shuffle!

out_path = File.join(__dir__, "stories.txt")
File.write(out_path, segments.join("\n") + "\n")

puts "Generated #{segments.length} text segments"
puts "Output: #{out_path} (#{File.size(out_path)} bytes / #{(File.size(out_path) / 1024.0).round(1)} KB)"
puts ""
puts "Sample segments:"
segments.first(15).each { |s| puts "  #{s}" }
