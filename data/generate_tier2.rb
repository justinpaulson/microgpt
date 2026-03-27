#!/usr/bin/env ruby
# frozen_string_literal: true

# Tier 2 training data: stepping up from toddler to early reader level.
# More complex sentences, cause-and-effect, multi-turn conversations,
# basic reasoning, and longer (but still short) stories.
# Still constrained to 64-char lines for the model's context window.

srand(42)
segments = []

# ======================== Cause and Effect ========================

causes = [
  ["it was cold outside", "he put on a coat"],
  ["she was hungry", "she ate a sandwich"],
  ["the dog was hot", "it jumped in the water"],
  ["it started to rain", "they went inside"],
  ["the baby cried", "mom picked her up"],
  ["he was sleepy", "he went to bed"],
  ["the cat was bored", "it played with a ball"],
  ["she fell down", "she got back up"],
  ["the cup fell", "the water spilled"],
  ["the light went out", "it was dark"],
  ["the ball hit the window", "the window broke"],
  ["he ran fast", "he got tired"],
  ["she read a book", "she learned new words"],
  ["the bird was hungry", "it ate a worm"],
  ["the flower had no water", "it was sad"],
  ["he was kind", "he had many friends"],
  ["the ice cream was in the sun", "it melted"],
  ["the boy sang a song", "everyone was happy"],
  ["it was her birthday", "she got a cake"],
  ["the frog jumped in the pond", "splash!"],
]

causes.each do |cause, effect|
  15.times do
    segments << "#{cause}. so #{effect}."
    segments << "#{cause}. then #{effect}."
    segments << "You: why\nBot: because #{cause}!"
  end
end

# ======================== If/Then Patterns ========================

ifthen = [
  ["you are cold", "put on a coat"],
  ["you are hungry", "eat some food"],
  ["you are tired", "go to sleep"],
  ["you are sad", "talk to a friend"],
  ["you are lost", "ask for help"],
  ["it is raining", "use an umbrella"],
  ["it is dark", "turn on the light"],
  ["you want to learn", "read a book"],
  ["you see a fire", "tell a grown up"],
  ["you hear a loud sound", "do not be scared"],
  ["you find something", "give it back"],
  ["you make a mess", "clean it up"],
]

ifthen.each do |cond, action|
  10.times do
    segments << "if #{cond} then #{action}."
    segments << "when #{cond} you should #{action}."
  end
end

# ======================== Two-Sentence Stories ========================

subjects = %w[the\ cat the\ dog the\ bird the\ frog the\ fish
              the\ bear the\ fox the\ duck the\ pig the\ hen
              sam max ben mom dad]

actions = [
  ["went to the park", "had a good time"],
  ["found a ball", "played all day"],
  ["climbed a tree", "could see far away"],
  ["made a cake", "shared it with friends"],
  ["sang a song", "danced and danced"],
  ["went to the store", "got some food"],
  ["ran in the rain", "got all wet"],
  ["drew a picture", "it was pretty"],
  ["took a nap", "felt much better"],
  ["ate some pie", "it was yummy"],
  ["rode a bike", "went very fast"],
  ["read a book", "learned a lot"],
  ["went to bed", "had a nice dream"],
  ["played in the snow", "built a snowman"],
  ["saw a rainbow", "it was so pretty"],
]

subjects.each do |subj|
  actions.each do |act, result|
    5.times do
      segments << "#{subj} #{act}. #{subj} #{result}."
    end
  end
end

# ======================== Multi-Turn Conversations ========================

multi_turn = [
  # Greetings + followup
  ["You: hi\nBot: hello!\nYou: how are you\nBot: i am good! how are you?"] * 15,
  ["You: hello\nBot: hi there!\nYou: what is your name\nBot: i am bot!"] * 15,
  ["You: hey\nBot: hey! what is up?\nYou: not much\nBot: that is okay!"] * 10,

  # Story requests with followup
  ["You: tell me a story\nBot: once there was a cat.\nYou: what did the cat do\nBot: the cat played with a ball!"] * 10,
  ["You: tell me a story\nBot: once there was a dog.\nYou: was the dog nice\nBot: yes the dog was very nice!"] * 10,
  ["You: tell me a story\nBot: once there was a bird.\nYou: where did the bird go\nBot: the bird flew to a tree!"] * 10,
  ["You: tell me a story\nBot: once there was a fish.\nYou: what color was the fish\nBot: the fish was blue and shiny!"] * 10,
  ["You: tell me about dogs\nBot: dogs are fun! they like to play.\nYou: do dogs like water\nBot: yes many dogs love water!"] * 10,

  # Learning conversations
  ["You: what is one plus one\nBot: one plus one is two!\nYou: what is two plus two\nBot: two plus two is four!"] * 10,
  ["You: how many legs does a dog have\nBot: a dog has four legs!\nYou: how about a bird\nBot: a bird has two legs!"] * 10,
  ["You: what do cows eat\nBot: cows eat grass!\nYou: what do cats eat\nBot: cats eat cat food!"] * 10,
  ["You: is the sun hot\nBot: yes the sun is very hot!\nYou: is the moon hot\nBot: no the moon is cold!"] * 10,
  ["You: what is rain\nBot: rain is water from the sky!\nYou: do you like rain\nBot: yes rain helps flowers grow!"] * 10,

  # Feelings conversations
  ["You: i am sad today\nBot: oh no! what is wrong?\nYou: i miss my friend\nBot: i am sorry. you will see them soon!"] * 10,
  ["You: i am happy\nBot: yay! why are you happy?\nYou: i got a new toy\nBot: that is so cool!"] * 10,
  ["You: i am scared\nBot: it is okay. what are you scared of?\nYou: the dark\nBot: the dark is not so bad. you are safe!"] * 10,
].flatten

multi_turn.each { |mt| segments << mt }

# ======================== Simple Descriptions ========================

things = {
  "a ball" => ["round", "fun to throw", "can bounce"],
  "a tree" => ["tall", "has green leaves", "gives us shade"],
  "the moon" => ["bright at night", "round and white", "up in the sky"],
  "a flower" => ["pretty", "has petals", "needs water"],
  "a book" => ["has many pages", "full of words", "fun to read"],
  "a cloud" => ["white and fluffy", "up in the sky", "made of water"],
  "the ocean" => ["big and blue", "full of fish", "has waves"],
  "a house" => ["has a door", "has windows", "where we live"],
  "a star" => ["shiny", "far away", "comes out at night"],
  "a hat" => ["goes on your head", "keeps you warm", "comes in many colors"],
  "shoes" => ["go on your feet", "help you walk", "come in pairs"],
  "a bed" => ["soft", "for sleeping", "has a pillow"],
}

things.each do |thing, descs|
  descs.each do |desc|
    10.times do
      segments << "#{thing} is #{desc}."
      segments << "do you know what #{thing} is? it is #{desc}."
      segments << "You: what is #{thing}\nBot: #{thing} is #{desc}!"
    end
  end
end

# ======================== Comparative / Opposites ========================

comparisons = [
  ["the sun is big", "a bug is small"],
  ["a cat is soft", "a rock is hard"],
  ["fire is hot", "ice is cold"],
  ["the day is bright", "the night is dark"],
  ["a bird is fast", "a snail is slow"],
  ["a feather is light", "a stone is heavy"],
  ["sugar is sweet", "a lemon is sour"],
  ["summer is hot", "winter is cold"],
  ["an elephant is big", "a mouse is small"],
  ["a rabbit is fast", "a turtle is slow"],
  ["a pillow is soft", "a wall is hard"],
  ["water is wet", "sand is dry"],
]

comparisons.each do |a, b|
  10.times do
    segments << "#{a}. but #{b}."
    segments << "#{a} and #{b}."
    segments << "You: which is bigger\nBot: #{a.split.last(2).join(' ')}!"
  end
end

# ======================== Action Sequences ========================

routines = [
  "wake up. brush teeth. eat food. go play!",
  "put on shoes. open the door. go outside!",
  "get a cup. pour some water. take a drink!",
  "get a book. sit down. read the book!",
  "wash hands. sit at the table. eat dinner!",
  "take a bath. put on pajamas. go to bed!",
  "get a ball. go outside. throw the ball!",
  "get some paper. pick up a crayon. draw!",
  "pick up the toys. put them away. all clean!",
  "mix the batter. put it in the oven. yum cake!",
  "dig a hole. plant a seed. water it!",
  "open the box. look inside. what is it?",
]

routines.each { |r| 15.times { segments << r } }

# ======================== "Why" Q&A ========================

whys = {
  "why is the sky blue" => "because of how light works!",
  "why do birds fly" => "they have wings!",
  "why do fish swim" => "they live in water!",
  "why do we eat" => "to get energy and grow!",
  "why do we sleep" => "so our body can rest!",
  "why is grass green" => "because of a thing in it!",
  "why do dogs bark" => "to talk to us!",
  "why does it rain" => "water falls from the clouds!",
  "why is the sun hot" => "it is a big ball of fire!",
  "why do cats purr" => "it means they are happy!",
  "why do we have eyes" => "so we can see!",
  "why do we have ears" => "so we can hear!",
  "why do we have a nose" => "so we can smell!",
  "why is the night dark" => "the sun goes away!",
  "why do leaves fall" => "the trees rest in fall!",
}

whys.each do |q, a|
  10.times do
    segments << "You: #{q}\nBot: #{a}"
    segments << "You: #{q}?\nBot: #{a}"
  end
end

# ======================== Emotion Stories ========================

emotion_stories = [
  "sam was happy. he smiled big. he sang a song.",
  "the dog was scared. it hid under the bed. it was okay.",
  "mom was proud. ben did a good job. she gave him a hug.",
  "the cat was mad. someone took its toy. then it got it back.",
  "dad was tired. he sat in his chair. then he took a nap.",
  "the bird was lost. it could not find home. then it saw the tree!",
  "max was brave. he was not scared of the dark. good job max!",
  "the fish was lonely. then it found a friend. now it was happy.",
  "the frog was cold. it sat in the sun. now it was warm.",
  "ben was shy. he did not want to talk. that is okay!",
  "sam was kind. he shared his food. his friend was happy.",
  "the duck was funny. it made everyone laugh. ha ha ha!",
]

emotion_stories.each { |s| 15.times { segments << s } }

# ======================== What Comes Next ========================

sequences = [
  "first we wake up. then we eat. then we play.",
  "first you wash. then you dry. then you are clean!",
  "first we plant. then we water. then it grows!",
  "first crack the egg. then stir it. then cook it!",
  "first we crawl. then we walk. then we run!",
  "first it rains. then the sun comes. then a rainbow!",
  "first it is morning. then it is day. then it is night.",
  "first the egg hatches. then the bird grows. then it flies!",
  "first the seed is small. then it grows. then it is a tree!",
  "first you learn the letters. then the words. then you read!",
]

sequences.each { |s| 15.times { segments << s } }

# ======================== Polite Conversation ========================

polite = [
  "You: can i have some water please\nBot: yes of course! here you go!",
  "You: thank you so much\nBot: you are welcome! i am happy to help!",
  "You: i am sorry\nBot: that is okay! do not worry!",
  "You: excuse me\nBot: yes? how can i help you?",
  "You: please tell me a story\nBot: sure! once there was a little duck.",
  "You: may i ask you something\nBot: of course! go ahead!",
  "You: that was very nice of you\nBot: thank you! you are nice too!",
  "You: you are so smart\nBot: thank you! i try my best!",
  "You: i had a bad day\nBot: i am sorry. do you want to talk?",
  "You: you make me happy\nBot: that makes me happy too!",
  "You: will you be my friend\nBot: yes! i would love to be your friend!",
  "You: i do not understand\nBot: that is okay! i can try to help!",
]

polite.each { |p| 15.times { segments << p } }

# ======================== Rhyming Pairs ========================

rhymes = [
  "the cat in the hat sat on a mat.",
  "a bug on a rug gave me a hug.",
  "the dog and the frog sat on a log.",
  "a bee in a tree is happy and free.",
  "the fox in a box ate bagels and lox.",
  "a goat in a boat wore a big coat.",
  "a bear over there sat in a chair.",
  "a snake by the lake ate a piece of cake.",
  "a mouse in the house found a little blouse.",
  "the pig did a jig and danced a jig.",
  "the hen in the den picked up a pen.",
  "a snail on the trail got some mail.",
]

rhymes.each { |r| 20.times { segments << r } }

# ======================== "I Wonder" Questions ========================

wonders = [
  "You: i wonder why the sky is blue\nBot: that is a great question!",
  "You: i wonder what fish dream about\nBot: maybe they dream about the sea!",
  "You: i wonder how birds know where to go\nBot: they just know! it is amazing!",
  "You: i wonder how big the ocean is\nBot: it is very very big!",
  "You: i wonder what is on the moon\nBot: rocks and dust and craters!",
  "You: i wonder if animals can talk\nBot: they talk in their own way!",
  "You: i wonder how many stars there are\nBot: there are so many! too many to count!",
  "You: i wonder what happens when i sleep\nBot: your body rests and you dream!",
  "You: what do you wonder about\nBot: i wonder about lots of things!",
  "You: do you ever get curious\nBot: yes! i love to learn new things!",
]

wonders.each { |w| 10.times { segments << w } }

# ======================== Mini Dialogues with Context ========================

mini_dialogues = [
  "You: i saw a dog today\nBot: oh cool! what did the dog look like?\nYou: it was big and brown\nBot: that sounds like a nice dog!",
  "You: i went to the park\nBot: that sounds fun! what did you do?\nYou: i played on the swings\nBot: swings are so fun!",
  "You: i made a picture\nBot: wow! what did you draw?\nYou: a big red house\nBot: that sounds really pretty!",
  "You: i ate an apple\nBot: yum! was it good?\nYou: yes it was sweet\nBot: apples are yummy!",
  "You: i found a bug\nBot: oh wow! what kind of bug?\nYou: a little green one\nBot: bugs are so cool!",
  "You: i learned a new word\nBot: that is great! what word?\nYou: the word is brave\nBot: brave is a good word!",
  "You: my mom read me a story\nBot: that is nice! what was it about?\nYou: a little bear\nBot: i love bear stories!",
  "You: i helped clean up today\nBot: that is very kind of you!\nYou: it was easy\nBot: you are a good helper!",
  "You: i can count to ten\nBot: wow! show me!\nYou: one two three four five six seven eight nine ten\nBot: great job! you are so smart!",
  "You: do you want to play\nBot: yes! what should we play?\nYou: lets play a game\nBot: okay that sounds fun!",
]

mini_dialogues.each { |d| 10.times { segments << d } }

# ======================== Teaching Right from Wrong ========================

lessons = [
  "it is good to share. sharing makes others happy.",
  "it is good to be kind. kind words make people smile.",
  "it is good to help. helping is a nice thing to do.",
  "it is good to listen. we learn when we listen.",
  "it is good to try. even if it is hard. do not give up!",
  "it is good to say sorry. everyone makes mistakes.",
  "it is good to say thank you. it shows you care.",
  "it is good to be brave. you can do hard things!",
  "it is good to tell the truth. the truth is important.",
  "it is good to be a friend. friends make life fun.",
  "it is not nice to hit. use your words instead.",
  "it is not nice to yell. talk in a calm voice.",
  "we should take turns. everyone gets a chance.",
  "we should clean up after we play. put toys away.",
  "we should wash our hands before we eat.",
  "we should be gentle with animals. they have feelings.",
]

lessons.each { |l| 15.times { segments << l } }

# ======================== Shuffle and Write ========================

segments.shuffle!

out_path = File.join(__dir__, 'tier2.txt')
File.write(out_path, segments.join("\n"))

# Verify line lengths
lines = File.readlines(out_path).map(&:chomp)
long_lines = lines.select { |l| l.length > 64 }

puts "Generated #{segments.length} segments"
puts "Lines: #{lines.length}"
puts "Output: #{out_path} (#{File.size(out_path)} bytes)"
puts "Lines over 64 chars: #{long_lines.length}"
if long_lines.any?
  puts "Examples of long lines:"
  long_lines.first(5).each { |l| puts "  [#{l.length}] #{l}" }
end
puts "\nSamples:"
segments.first(10).each { |s| puts "  #{s.split("\n").first}" }
