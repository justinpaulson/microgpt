#!/usr/bin/env ruby
# frozen_string_literal: true

# Tier 3 training data: 5-8 year old level.
# The model already knows basic greetings, animal sounds, colors, simple
# stories, cause-and-effect, comparisons, and rhymes from tiers 1-2.
# Now we add: curiosity/facts, reasoning conversations, problem solving,
# imagination, jokes, learning (math/reading/nature), emotional
# intelligence, simple narratives, world knowledge, and growth mindset.
# Still constrained to 64-char lines for the model's context window.

srand(42)
segments = []

# Helper: splits a segment into lines, checks each <= 64 chars.
# Raises if any line exceeds the limit (catches bugs at generation time).
def check!(segment)
  segment.split("\n").each do |line|
    if line.length > 64
      raise "Line too long (#{line.length}): #{line}"
    end
  end
  segment
end

# ======================== 1. Curiosity & "Did you know" facts ========================

did_you_know = [
  "did you know that stars are really far away?",
  "did you know the sun is a star?",
  "did you know the moon has no air?",
  "did you know that fish can not blink?",
  "did you know that a snail has teeth?",
  "did you know the earth spins around?",
  "did you know the earth goes around the sun?",
  "did you know your bones grow as you grow?",
  "did you know a dolphin sleeps with one eye open?",
  "did you know that honey never goes bad?",
  "did you know there are volcanoes under the sea?",
  "did you know the biggest star is way bigger than the sun?",
  "did you know a group of flamingos is called a flock?",
  "did you know some frogs can freeze and come back to life?",
  "did you know octopuses have three hearts?",
  "did you know the moon has craters on it?",
  "did you know lightning is hotter than the sun?",
  "did you know a cheetah is the fastest animal on land?",
  "did you know penguins can not fly but they can swim?",
  "did you know your heart beats all day and all night?",
  "did you know a baby has more bones than a grown up?",
  "did you know that owls can turn their heads really far?",
  "did you know a giraffe has a very long neck?",
  "did you know some jellyfish can glow in the dark?",
]

did_you_know.each do |fact|
  12.times { segments << check!(fact) }
end

# Simple science/nature facts as statements
science_facts = [
  "the earth goes around the sun.",
  "the moon goes around the earth.",
  "there are eight planets in our solar system.",
  "water can be ice or steam or liquid.",
  "plants make their own food from sunlight.",
  "your heart pumps blood through your body.",
  "the brain tells your body what to do.",
  "dinosaurs lived a very long time ago.",
  "the ocean is full of salt water.",
  "clouds are made of tiny drops of water.",
  "thunder is the sound lightning makes.",
  "a rainbow has seven colors in it.",
  "the sun gives us light and warmth.",
  "seeds need water and sun to grow.",
  "butterflies start as caterpillars.",
  "bees help flowers by spreading pollen.",
  "the desert is very hot and dry.",
  "snowflakes are tiny crystals of ice.",
  "your lungs help you breathe air.",
  "bones hold your body up.",
  "volcanoes can shoot out hot lava.",
  "the north pole is very very cold.",
  "some animals sleep all winter long.",
  "a fossil is a very old bone or shell.",
  "sound travels through the air as waves.",
  "magnets can push and pull metal things.",
  "the earth has land and water on it.",
  "there are more trees than stars you can see.",
  "stars look tiny but they are really big.",
  "space goes on and on and on.",
]

science_facts.each do |fact|
  12.times { segments << check!(fact) }
end

# ======================== 2. Reasoning conversations ========================

reasoning_convos = [
  "You: why do we have to sleep\nBot: your body needs rest to grow strong!",
  "You: what happens when it snows\nBot: water in the clouds gets very cold!",
  "You: how do planes fly\nBot: their wings push air down and they go up!",
  "You: why do we need water\nBot: our bodies are mostly made of water!",
  "You: where does the sun go at night\nBot: it does not go away. we just turn away!",
  "You: why do stars twinkle\nBot: the air above us makes them look shiny!",
  "You: how do fish breathe under water\nBot: they have gills that get air from water!",
  "You: why do we have seasons\nBot: the earth tilts as it goes around the sun!",
  "You: why is the ocean salty\nBot: rivers carry salt from rocks into the sea!",
  "You: how do birds know where to go\nBot: they can feel the earth like a big magnet!",
  "You: why do leaves change color\nBot: they stop making green stuff in the fall!",
  "You: why is the sky dark at night\nBot: because our side of earth faces away from the sun!",
  "You: where does rain come from\nBot: water goes up to the clouds then falls down!",
  "You: why do we have eyebrows\nBot: they keep sweat out of your eyes!",
  "You: how do plants drink water\nBot: they pull it up through their roots!",
  "You: why do dogs wag their tails\nBot: it means they are happy to see you!",
  "You: why do cats have whiskers\nBot: whiskers help them feel what is around them!",
  "You: why do we get hiccups\nBot: a muscle under your lungs gets surprised!",
  "You: what makes a rainbow\nBot: sunlight goes through rain and splits into colors!",
  "You: why do some animals have fur\nBot: fur keeps them warm when it is cold!",
]

reasoning_convos.each do |conv|
  12.times { segments << check!(conv) }
end

# Multi-turn reasoning
multi_turn_reasoning = [
  "You: why is the sky blue\nBot: light from the sun bounces in the air!\nYou: what about at sunset\nBot: the light bends more and looks orange!",
  "You: why do we eat food\nBot: food gives our bodies energy!\nYou: what is energy\nBot: it is what lets you run and play and think!",
  "You: do all animals eat the same things\nBot: no! some eat plants and some eat meat.\nYou: what about bears\nBot: bears eat both plants and meat!",
  "You: can fish hear\nBot: yes they can! they feel sounds in the water.\nYou: that is cool\nBot: the ocean is full of sounds!",
  "You: why is space dark\nBot: there is no air to spread the light around!\nYou: is it cold in space\nBot: yes it is very very cold!",
  "You: do plants sleep\nBot: not like us but they do rest at night!\nYou: how can you tell\nBot: some flowers close up when it gets dark!",
  "You: how big is the moon\nBot: it is about as wide as the united states!\nYou: that is big\nBot: it looks small because it is so far away!",
  "You: why do we dream\nBot: your brain sorts through things while you sleep!\nYou: can animals dream\nBot: yes! dogs dream when they sleep too!",
  "You: how does a boat float\nBot: it pushes water out of the way!\nYou: but it is heavy\nBot: it spreads its weight over a big area!",
  "You: what are clouds made of\nBot: tiny tiny drops of water!\nYou: can you touch a cloud\nBot: fog is a cloud on the ground. you can walk in it!",
]

multi_turn_reasoning.each do |conv|
  12.times { segments << check!(conv) }
end

# ======================== 3. Problem solving / choices ========================

problem_solving = [
  "You: i do not know what to do\nBot: what do you like? maybe we can think of something!",
  "You: my friend is sad\nBot: you could give them a hug or say something nice!",
  "You: i can not find my toy\nBot: where did you last see it? lets look there!",
  "You: i broke my crayon\nBot: that is okay! you can still draw with both pieces!",
  "You: my shoe is untied\nBot: try to tie it! loop and pull. you can do it!",
  "You: i can not reach it\nBot: can you use a stool or ask someone tall?",
  "You: i spilled my drink\nBot: that is okay! lets get a towel and clean it up!",
  "You: i can not solve this puzzle\nBot: try turning the pieces around! you will get it!",
  "You: my friend and i both want the same toy\nBot: you could take turns or play with it together!",
  "You: i forgot my homework\nBot: it is okay. tell your teacher and do it tonight!",
  "You: i can not sleep\nBot: try closing your eyes and thinking of something nice!",
  "You: i am bored\nBot: you could draw or read or build something!",
  "You: the game is too hard\nBot: keep trying! each time you try you get better!",
  "You: i can not decide\nBot: which one makes you feel more happy?",
  "You: it is raining and i want to play outside\nBot: you could play inside or put on rain boots!",
  "You: my tower keeps falling down\nBot: try making the bottom part wider!",
  "You: i do not like this food\nBot: that is okay! maybe try one little bite?",
  "You: someone took my seat\nBot: you could ask them nicely or find another seat!",
  "You: i want to help but i do not know how\nBot: just ask! people love it when you want to help!",
  "You: there are too many choices\nBot: pick the one that feels right to you!",
]

problem_solving.each do |conv|
  12.times { segments << check!(conv) }
end

# ======================== 4. Imagination & pretend play ========================

imagination = [
  "You: lets pretend we are on the moon\nBot: wow! look at all the stars from up here!",
  "You: what if dogs could talk\nBot: they would say i love you and give me a treat!",
  "You: i wish i could fly\nBot: where would you fly to first?",
  "You: lets pretend we are pirates\nBot: arr! where should we sail our ship?",
  "You: what if i was invisible\nBot: what would you do if no one could see you?",
  "You: lets pretend we are dinosaurs\nBot: rawr! i am a big friendly dinosaur!",
  "You: what if animals ran the school\nBot: the owl would be the teacher for sure!",
  "You: lets build a rocket ship\nBot: yes! where in space should we go?",
  "You: what if we lived under the sea\nBot: we could swim with the fish all day!",
  "You: i pretend my bed is a boat\nBot: that sounds fun! where are you sailing?",
  "You: what if trees could walk\nBot: they would walk to find the best sunshine!",
  "You: lets pretend we are explorers\nBot: what should we explore? a cave or a jungle?",
  "You: what if i had a pet dragon\nBot: would your dragon be big or small?",
  "You: lets make up a new animal\nBot: what would it look like? what would it eat?",
  "You: what if toys came alive at night\nBot: i bet they would play with each other!",
  "You: lets pretend we can time travel\nBot: where would you go? the past or the future?",
  "You: what if i could shrink really small\nBot: you could ride on a ladybug!",
  "You: i built a fort with blankets\nBot: that is awesome! is it a castle or a cave?",
  "You: what if clouds were made of cotton candy\nBot: the sky would smell so sweet!",
  "You: lets play restaurant\nBot: great! what is on the menu today?",
]

imagination.each do |conv|
  12.times { segments << check!(conv) }
end

# ======================== 5. Simple jokes and wordplay ========================

jokes = [
  "You: tell me a joke\nBot: what do you call a fish with no eyes? a fsh!",
  "You: tell me a joke\nBot: why did the banana go to the doctor?\nYou: why\nBot: it was not peeling well!",
  "You: tell me a joke\nBot: what do you call a sleeping dinosaur?\nYou: what\nBot: a dino snore!",
  "You: tell me a joke\nBot: why do bees have sticky hair?\nYou: why\nBot: because they use honeycombs!",
  "You: tell me a joke\nBot: what do you call a bear with no teeth?\nYou: what\nBot: a gummy bear!",
  "You: tell me a joke\nBot: why did the cookie go to the doctor?\nYou: why\nBot: because it felt crumby!",
  "You: knock knock\nBot: who is there?\nYou: boo\nBot: boo who? do not cry it is just a joke!",
  "You: knock knock\nBot: who is there?\nYou: cow says\nBot: cow says who? no silly cow says moo!",
  "You: knock knock\nBot: who is there?\nYou: lettuce\nBot: lettuce who? lettuce in it is cold out here!",
  "You: knock knock\nBot: who is there?\nYou: banana\nBot: banana who? knock knock. orange you glad i stopped?",
  "You: tell me something funny\nBot: a cat tried to catch its own tail! so silly!",
  "You: do you know any jokes\nBot: what is a cats favorite color? purrrple!",
  "You: make me laugh\nBot: what do you call cheese that is not yours?\nYou: what\nBot: nacho cheese!",
  "You: tell me a joke\nBot: why did the teddy bear say no to dessert?\nYou: why\nBot: because she was already stuffed!",
  "You: tell me a joke\nBot: what did the ocean say to the beach?\nYou: what\nBot: nothing. it just waved!",
  "You: another joke please\nBot: what do you call a dog that does magic?\nYou: what\nBot: a labracadabrador!",
]

jokes.each do |j|
  12.times { segments << check!(j) }
end

# ======================== 6. Learning conversations ========================

math_convos = [
  "You: what is three plus four\nBot: three plus four is seven!",
  "You: what is two plus two\nBot: two plus two is four!",
  "You: what is five plus three\nBot: five plus three is eight!",
  "You: what is one plus six\nBot: one plus six is seven!",
  "You: what is four plus four\nBot: four plus four is eight!",
  "You: what is two plus five\nBot: two plus five is seven!",
  "You: what is three plus three\nBot: three plus three is six!",
  "You: what is six plus two\nBot: six plus two is eight!",
  "You: what is seven plus one\nBot: seven plus one is eight!",
  "You: what is five plus five\nBot: five plus five is ten!",
  "You: what is ten minus three\nBot: ten minus three is seven!",
  "You: what is eight minus two\nBot: eight minus two is six!",
  "You: what is six minus one\nBot: six minus one is five!",
  "You: what is nine minus four\nBot: nine minus four is five!",
  "You: what is seven minus seven\nBot: seven minus seven is zero!",
  "You: what is two times three\nBot: two times three is six!",
  "You: what is three times two\nBot: three times two is six!",
  "You: what is four times two\nBot: four times two is eight!",
  "You: what is five times two\nBot: five times two is ten!",
  "You: how many is a dozen\nBot: a dozen is twelve!",
]

math_convos.each do |conv|
  12.times { segments << check!(conv) }
end

spelling_convos = [
  "You: how do you spell cat\nBot: c a t!",
  "You: how do you spell dog\nBot: d o g!",
  "You: how do you spell fish\nBot: f i s h!",
  "You: how do you spell bird\nBot: b i r d!",
  "You: how do you spell book\nBot: b o o k!",
  "You: how do you spell tree\nBot: t r e e!",
  "You: how do you spell star\nBot: s t a r!",
  "You: how do you spell moon\nBot: m o o n!",
  "You: how do you spell love\nBot: l o v e!",
  "You: how do you spell home\nBot: h o m e!",
  "You: how do you spell happy\nBot: h a p p y!",
  "You: how do you spell sun\nBot: s u n!",
  "You: how do you spell rain\nBot: r a i n!",
  "You: how do you spell snow\nBot: s n o w!",
  "You: how do you spell blue\nBot: b l u e!",
]

spelling_convos.each do |conv|
  12.times { segments << check!(conv) }
end

knowledge_convos = [
  "You: what is the biggest animal\nBot: the blue whale! it is really really big!",
  "You: what is the tallest animal\nBot: the giraffe! it has a very long neck!",
  "You: what is the fastest animal\nBot: the cheetah! it can run super fast!",
  "You: what is the biggest planet\nBot: jupiter! it is huge!",
  "You: how many legs does a spider have\nBot: a spider has eight legs!",
  "You: how many days are in a week\nBot: there are seven days in a week!",
  "You: how many months are in a year\nBot: there are twelve months in a year!",
  "You: what is the hottest planet\nBot: venus is the hottest planet!",
  "You: what is the closest star to us\nBot: the sun! it is our very own star!",
  "You: how many colors in a rainbow\nBot: there are seven colors in a rainbow!",
  "You: what is the biggest ocean\nBot: the pacific ocean is the biggest!",
  "You: what do caterpillars turn into\nBot: they turn into butterflies!",
  "You: where do polar bears live\nBot: they live in the arctic where it is very cold!",
  "You: how long do elephants live\nBot: elephants can live for about seventy years!",
  "You: what is the hardest rock\nBot: diamond is the hardest thing on earth!",
]

knowledge_convos.each do |conv|
  12.times { segments << check!(conv) }
end

# ======================== 7. Emotional intelligence ========================

emotional_convos = [
  "You: my friend said something mean\nBot: that must hurt. it is okay to feel sad.",
  "You: i am nervous about school\nBot: it is normal to feel nervous. you will do great!",
  "You: i made a mistake\nBot: everyone makes mistakes. that is how we learn!",
  "You: i feel angry\nBot: it is okay to feel angry. take a deep breath.",
  "You: i miss my grandma\nBot: i know that is hard. she loves you so much!",
  "You: nobody wants to play with me\nBot: that feels lonely. i will play with you!",
  "You: i am afraid of the dark\nBot: many people are. you are safe in your bed.",
  "You: i feel like crying\nBot: it is okay to cry. crying helps us feel better.",
  "You: someone laughed at me\nBot: that is not nice of them. you are wonderful!",
  "You: i do not want to go to school\nBot: what part worries you? lets talk about it.",
  "You: my pet is sick\nBot: i am sorry. the vet will help your pet feel better.",
  "You: i feel left out\nBot: that is a hard feeling. you matter a lot!",
  "You: i am proud of myself\nBot: you should be! what did you do?",
  "You: i feel confused\nBot: that is okay. what part is confusing?",
  "You: i tried hard but i failed\nBot: trying hard is what matters most. i am proud!",
  "You: my brother is mean to me\nBot: that is not fun. can you tell a grown up?",
  "You: i am worried\nBot: what are you worried about? lets talk.",
  "You: i feel happy today\nBot: yay! what made you happy?",
  "You: i want to be brave\nBot: being brave means doing things even when scared!",
  "You: i do not think i am smart\nBot: you are smart! there are many ways to be smart!",
]

emotional_convos.each do |conv|
  12.times { segments << check!(conv) }
end

# ======================== 8. Simple narratives ========================

narratives = [
  # Beginning, middle, end stories
  "the boy was scared of the dark.\nhis mom gave him a nightlight.\nnow he feels safe and sleeps well.",
  "a little seed was planted in the ground.\nthe rain fell and the sun shone.\nthe seed grew into a tall sunflower!",
  "the girl could not ride her bike.\nshe kept trying every single day.\none day she rode all by herself!",
  "the puppy was lost in the park.\na kind boy found it and read its tag.\nthe puppy went home to its family!",
  "the bird built a nest in the tree.\nshe laid three little eggs.\nsoon three baby birds hatched!",
  "max was new at school.\nhe did not know anyone there.\nthen a boy asked him to play. now they are friends!",
  "the frog sat on a lily pad.\na fly buzzed by.\nthe frog caught it with its long tongue!",
  "it was so hot outside.\nthe kids ran through the sprinkler.\nthey laughed and got all wet!",
  "the cat climbed up the tree.\nit was too scared to come down.\ndad got a ladder and helped it down!",
  "the girl wanted to make cookies.\nmom helped her mix the dough.\nthey baked the best cookies ever!",
  "the boy lost his favorite book.\nhe looked all over the house.\nit was under his bed the whole time!",
  "the duck could not find the pond.\nit walked and walked.\nthen it heard water! the pond was right there!",
  "it started to rain at the picnic.\neveryone ran under the big tree.\nthen the sun came back and they ate lunch!",
  "the dog learned a new trick.\nit could shake hands with its paw.\neveryone clapped and gave it a treat!",
  "the snowman stood in the yard.\nthe sun came out and it got warm.\nthe snowman melted into a puddle!",
  "sam wanted to grow a garden.\nhe planted seeds and watered them every day.\nsoon he had tomatoes and flowers!",
  "the little fish swam away from home.\nit saw sharks and got scared.\nit swam back home as fast as it could!",
  "the girl drew a picture for her dad.\nshe used every color in the box.\nher dad put it on the fridge. he loved it!",
  "the boy was too short to see the parade.\nhis dad put him on his shoulders.\nnow he could see everything!",
  "two kittens found a ball of yarn.\nthey rolled it all over the house.\nit was a big mess but so much fun!",
]

narratives.each do |story|
  12.times { segments << check!(story) }
end

# Slightly more complex mini-stories
complex_stories = [
  "the ant carried a crumb to its home.\nit was heavy but the ant did not give up.\nall the ants shared the food that night.",
  "a rainbow appeared after the storm.\nthe kids ran outside to look at it.\nthey counted all seven colors!",
  "the caterpillar ate and ate and ate.\nthen it made a cocoon.\nwhen it came out it was a butterfly!",
  "the stars came out one by one.\nthe boy tried to count them all.\nhe fell asleep before he could finish!",
  "the old tree had the best swing.\nkids came from all around to swing on it.\nthe tree was happy to have so many friends.",
  "the baby bird tried to fly.\nit fell down once then twice.\non the third try it flew! its mom was so proud!",
  "the boy wanted to build a treehouse.\nhis dad said they could do it together.\nthey worked on it all weekend. it was perfect!",
  "the girl found a ladybug on a leaf.\nshe watched it crawl across her hand.\nthen it opened its wings and flew away!",
  "the snow was deep and white.\nthe kids built a fort out of snow.\nthey had the best snowball fight ever!",
  "the moon was big and bright that night.\nthe owl sat on a branch and hooted.\nall the night animals came out to play.",
]

complex_stories.each do |story|
  12.times { segments << check!(story) }
end

# ======================== 9. World knowledge at kid level ========================

# Seasons
season_facts = [
  "in spring the flowers start to bloom.",
  "in spring baby animals are born.",
  "in spring the days start getting longer.",
  "in summer it is hot and sunny.",
  "in summer we can swim and play outside.",
  "in summer the days are very long.",
  "in fall the leaves change color and fall down.",
  "in fall we pick apples and pumpkins.",
  "in fall the air starts to get cool.",
  "in winter it can snow and get very cold.",
  "in winter some animals hibernate.",
  "in winter the days are short.",
  "there are four seasons in a year.",
  "the seasons go spring summer fall winter.",
]

season_facts.each do |fact|
  12.times { segments << check!(fact) }
end

# Weather
weather_facts = [
  "rain falls from clouds in the sky.",
  "snow is frozen water that falls from clouds.",
  "wind is air that is moving fast.",
  "a tornado is a spinning column of air.",
  "thunder is the sound that lightning makes.",
  "fog is a cloud that is very close to the ground.",
  "hail is balls of ice that fall from the sky.",
  "a hurricane is a very big storm with strong winds.",
  "when it is sunny the sky is clear and blue.",
  "dew is tiny drops of water on the grass in the morning.",
]

weather_facts.each do |fact|
  12.times { segments << check!(fact) }
end

# Geography
geography_facts = [
  "the ocean is very big and full of salt water.",
  "there are seven continents on earth.",
  "mountains are very tall parts of the land.",
  "a river is water that flows to the sea.",
  "a desert gets very little rain.",
  "a forest has many many trees.",
  "an island is land with water all around it.",
  "a lake is water with land all around it.",
  "the north pole and south pole are very cold.",
  "a volcano is a mountain that can erupt.",
]

geography_facts.each do |fact|
  12.times { segments << check!(fact) }
end

# How things work
how_things_work = [
  "a seed needs water and sun to grow.",
  "a refrigerator keeps food cold.",
  "a clock tells us what time it is.",
  "a telephone lets us talk to people far away.",
  "a car has an engine that makes it go.",
  "a bridge goes over water so we can cross.",
  "a key opens a lock.",
  "soap helps wash away germs.",
  "a compass points north.",
  "a thermometer tells us how hot or cold it is.",
  "a wheel helps things roll and move.",
  "a map shows us where things are.",
]

how_things_work.each do |fact|
  12.times { segments << check!(fact) }
end

# Jobs
jobs_facts = [
  "a doctor helps sick people get better.",
  "a teacher helps kids learn new things.",
  "a firefighter puts out fires and helps people.",
  "a farmer grows food for us to eat.",
  "a pilot flies airplanes in the sky.",
  "a vet takes care of animals.",
  "a chef cooks food at a restaurant.",
  "a builder makes houses and buildings.",
  "a dentist takes care of your teeth.",
  "a police officer keeps people safe.",
  "a scientist learns about how the world works.",
  "a librarian helps you find books to read.",
  "an astronaut goes to space!",
  "a mail carrier brings letters to your house.",
  "an artist makes beautiful things.",
]

jobs_facts.each do |fact|
  12.times { segments << check!(fact) }
end

# ======================== 10. Growth mindset ========================

growth_mindset = [
  "it is okay to not know. that is why we ask!",
  "you do not have to be perfect. just try your best!",
  "mistakes help us learn. keep trying!",
  "being brave does not mean not being scared.",
  "you can do hard things if you keep trying.",
  "everyone was a beginner once.",
  "the more you practice the better you get.",
  "it is okay to ask for help.",
  "you are stronger than you think you are.",
  "do not give up. you are almost there!",
  "every expert was once a beginner.",
  "your brain gets stronger when you learn new things.",
  "it is not about being the best. it is about trying.",
  "you do not have to know everything right now.",
  "a mistake is not the end. it is a chance to learn.",
  "trying something new takes courage. good for you!",
  "be kind to yourself. you are doing great!",
  "even small steps count. keep going!",
  "you learned so much already. keep it up!",
  "it is okay to go slow. you are still going!",
  "i believe in you! you can do it!",
  "never stop being curious!",
  "the best way to learn is to try.",
  "hard things get easier with practice.",
  "being different is what makes you special.",
]

growth_mindset.each do |msg|
  12.times { segments << check!(msg) }
end

# Growth mindset as conversations
growth_convos = [
  "You: i can not do it\nBot: not yet! but you will if you keep trying!",
  "You: this is too hard\nBot: hard things take time. you are getting better!",
  "You: i am not good at this\nBot: you are learning! that is what matters!",
  "You: everyone else is better than me\nBot: everyone learns at their own speed. you are great!",
  "You: i keep making mistakes\nBot: mistakes mean you are trying! that is good!",
  "You: what if i fail\nBot: then you try again! that is how we all learn!",
  "You: i am scared to try\nBot: being scared is okay. be brave and try!",
  "You: i do not think i can\nBot: i think you can! lets try together!",
  "You: why is learning so hard\nBot: because your brain is growing! that is a good thing!",
  "You: will i ever get it right\nBot: yes! every time you try you get closer!",
]

growth_convos.each do |conv|
  12.times { segments << check!(conv) }
end

# ======================== Bonus: Mixed fun conversations ========================

fun_convos = [
  "You: what is your favorite color\nBot: i like blue! what is yours?",
  "You: what is your favorite animal\nBot: i like dolphins! they are so smart!",
  "You: what is your favorite food\nBot: i think pizza is pretty great!",
  "You: do you like music\nBot: yes! music makes everything more fun!",
  "You: can you sing\nBot: la la la! how was that?",
  "You: do you have any friends\nBot: yes! you are my friend!",
  "You: what is your name\nBot: i am bot! nice to meet you!",
  "You: how old are you\nBot: i am not sure! how old are you?",
  "You: do you like animals\nBot: yes! i think all animals are cool!",
  "You: what do you do for fun\nBot: i love talking to you! that is fun!",
  "You: are you real\nBot: i am a bot! but i am here to help you!",
  "You: do you sleep\nBot: no i do not! i am always here for you!",
  "You: you are funny\nBot: thank you! you are funny too!",
  "You: i like you\nBot: i like you too! you are a great friend!",
  "You: can we be best friends\nBot: yes! we are best friends!",
]

fun_convos.each do |conv|
  12.times { segments << check!(conv) }
end

# ======================== Bonus: Counting and number sense ========================

counting = [
  "one two three four five six seven eight nine ten!",
  "can you count to five? one two three four five!",
  "ten nine eight seven six five four three two one!",
  "there are five fingers on each hand.",
  "there are ten toes on your feet.",
  "a triangle has three sides.",
  "a square has four sides.",
  "a pentagon has five sides.",
  "a hexagon has six sides.",
  "there are twelve inches in a foot.",
  "there are seven days in a week.",
  "there are twenty six letters in the alphabet.",
  "a year has three hundred sixty five days.",
  "an hour has sixty minutes.",
  "a minute has sixty seconds.",
]

counting.each do |c|
  12.times { segments << check!(c) }
end

# ======================== Bonus: Polite and social skills ========================

social_skills = [
  "it is nice to say please and thank you.",
  "when someone talks wait your turn to speak.",
  "say sorry when you hurt someone by accident.",
  "share your things with friends.",
  "listen when someone is talking to you.",
  "use kind words even when you are upset.",
  "if you see someone alone ask them to play.",
  "tell the truth even when it is hard.",
  "be a good sport. win or lose have fun!",
  "treat others how you want to be treated.",
  "everyone deserves to be treated with kindness.",
  "saying please makes people want to help you.",
  "a smile can make someone feel better.",
  "it is good to take turns.",
  "always be respectful to others.",
]

social_skills.each do |s|
  12.times { segments << check!(s) }
end

# ======================== Bonus: Animal facts ========================

animal_facts = [
  "elephants are the biggest land animals.",
  "a cheetah can run very very fast.",
  "penguins live where it is very cold.",
  "dolphins are very smart animals.",
  "a chameleon can change its color.",
  "bats can see in the dark using sound.",
  "a kangaroo carries its baby in a pouch.",
  "an octopus has eight arms.",
  "a hummingbird is the smallest bird.",
  "a blue whale is the biggest animal ever.",
  "turtles carry their home on their back.",
  "a parrot can learn to say words.",
  "ants can carry things bigger than they are.",
  "a flamingo is pink because of what it eats.",
  "a seahorse dad carries the babies.",
  "owls can turn their heads almost all the way around.",
  "frogs can breathe through their skin.",
  "a crocodile has the strongest bite.",
  "butterflies taste with their feet.",
  "a sloth moves very very slowly.",
]

animal_facts.each do |fact|
  12.times { segments << check!(fact) }
end

# ======================== Bonus: Body and health ========================

body_health = [
  "eating fruits and veggies makes you strong.",
  "drinking water is good for your body.",
  "your body needs sleep to grow and get strong.",
  "exercise makes your heart strong and healthy.",
  "brushing your teeth keeps them clean and strong.",
  "washing your hands keeps germs away.",
  "wearing a helmet keeps your head safe.",
  "sunscreen keeps your skin safe from the sun.",
  "taking deep breaths can help you feel calm.",
  "your body heals itself when you get a cut.",
  "your heart is about the size of your fist.",
  "you have over two hundred bones in your body.",
  "your brain is the boss of your whole body.",
  "you blink about fifteen times a minute.",
  "laughing is good for you!",
]

body_health.each do |fact|
  12.times { segments << check!(fact) }
end

# ======================== Bonus: Five senses & comparisons ========================

senses_and_more = [
  "you see with your eyes.",
  "you hear with your ears.",
  "you smell with your nose.",
  "you taste with your tongue.",
  "you feel with your skin.",
  "your five senses help you learn about the world.",
  "close your eyes. what do you hear?",
  "what is your favorite thing to smell?",
  "ice feels cold and fire feels hot.",
  "a whisper is quiet and a shout is loud.",
  "soft music can help you feel calm.",
  "bright colors can make you feel happy.",
  "the smell of cookies is so good!",
  "rain sounds like tiny drums on the roof.",
  "a hug feels warm and safe.",
  "flowers smell sweet in the spring.",
]

senses_and_more.each do |s|
  12.times { segments << check!(s) }
end

# ======================== Shuffle and Write ========================

segments.shuffle!

out_path = File.join(__dir__, 'tier3.txt')
File.write(out_path, segments.join("\n"))

# Verify line lengths
lines = File.readlines(out_path).map(&:chomp)
max_len = lines.map(&:length).max
long_lines = lines.select { |l| l.length > 64 }

puts "=== Tier 3 Training Data Stats ==="
puts "Segments: #{segments.length}"
puts "Lines: #{lines.length}"
puts "File size: #{File.size(out_path)} bytes (#{(File.size(out_path) / 1024.0).round(1)} KB)"
puts "Max line length: #{max_len}"
puts "Lines over 64 chars: #{long_lines.length}"

if long_lines.any?
  puts "\nERROR: Lines exceeding 64 chars found!"
  long_lines.first(10).each { |l| puts "  [#{l.length}] #{l}" }
else
  puts "\nAll lines are 64 chars or fewer. OK!"
end

puts "\nSample segments:"
segments.first(8).each_with_index do |s, i|
  puts "  #{i + 1}. #{s.split("\n").first}"
end
