#!/usr/bin/env ruby
# frozen_string_literal: true

# Tier 4 training data: middle-school level (ages 10-14).
# The model already knows basic greetings, animal sounds, colors, simple
# stories, cause-and-effect, comparisons, rhymes, curiosity facts, reasoning,
# problem solving, imagination, jokes, learning, emotional intelligence,
# simple narratives, world knowledge, and growth mindset from tiers 1-3.
#
# Now we add: science explanations, multi-turn deep conversations, reading
# comprehension, opinion/reasoning, problem solving/advice, history/world
# knowledge, definitions, creative/hypothetical thinking, everyday knowledge,
# and well-formed prose passages.
#
# Context window upgraded to 128 bytes — every line must be <= 128 chars.

srand(42)
segments = []

# Helper: splits a segment into lines, checks each <= 128 chars.
# Raises if any line exceeds the limit (catches bugs at generation time).
def check!(segment)
  segment.split("\n").each do |line|
    if line.length > 128
      raise "Line too long (#{line.length}): #{line}"
    end
  end
  segment
end

# ======================== 1. Science & Nature Explanations ========================

science_explanations = [
  # Solar system
  "the moon does not make its own light. it reflects light from the sun.",
  "the sun is a star. it is the closest star to earth and gives us light and heat.",
  "the planets in our solar system orbit the sun because of gravity.",
  "mercury is the closest planet to the sun but venus is the hottest because of its thick atmosphere.",
  "mars is called the red planet because its soil contains iron oxide which is basically rust.",
  "jupiter is the largest planet in our solar system. it is mostly made of gas.",
  "saturn has beautiful rings made of ice and rock that orbit around it.",
  "a year on earth is the time it takes to go around the sun once. that is about 365 days.",
  "the earth rotates on its axis once every 24 hours. that is what gives us day and night.",
  "neptune is the farthest planet from the sun and it takes 165 years to orbit once.",
  "asteroids are rocky objects that orbit the sun. most are found between mars and jupiter.",
  "a comet is a ball of ice and dust that develops a glowing tail when it gets close to the sun.",

  # Weather
  "clouds form when water vapor in the air cools down and turns into tiny water droplets.",
  "lightning is a giant spark of electricity that happens during a thunderstorm.",
  "a tornado forms when warm air and cold air meet and start spinning very fast.",
  "hurricanes form over warm ocean water and get their energy from the heat of the sea.",
  "snow forms when water vapor freezes into ice crystals high up in the clouds.",
  "fog is basically a cloud that forms at ground level when the air is cool and moist.",
  "the water cycle is how water moves from the ocean to the sky and back again.",
  "rain happens when water droplets in clouds get too heavy and fall to the ground.",

  # Ecosystems
  "an ecosystem is all the living and nonliving things in an area working together.",
  "in a food chain energy passes from plants to plant eaters to meat eaters.",
  "decomposers like fungi and bacteria break down dead things and return nutrients to the soil.",
  "a habitat is the natural home of an animal or plant where it can find food and shelter.",
  "coral reefs are underwater ecosystems built by tiny animals called coral polyps.",
  "wetlands filter water and provide homes for many birds, fish, and amphibians.",
  "the rainforest has more types of plants and animals than any other ecosystem on earth.",

  # Human body
  "your heart beats about 100,000 times every day pumping blood through your whole body.",
  "your brain has about 86 billion neurons that send signals to control everything you do.",
  "red blood cells carry oxygen from your lungs to every part of your body.",
  "white blood cells are part of your immune system and they fight off germs and infections.",
  "your stomach uses acids to break down the food you eat into nutrients your body can use.",
  "bones are living tissue. they can grow and heal themselves when they break.",
  "muscles work in pairs. when one tightens the other relaxes to move your bones.",
  "your skin is your largest organ. it protects you from germs and helps control body temperature.",
  "your lungs take in oxygen and release carbon dioxide every time you breathe.",
  "the small intestine is where most of the nutrients from food are absorbed into your blood.",

  # Basic chemistry
  "everything around us is made of tiny particles called atoms.",
  "water is made of two hydrogen atoms and one oxygen atom. its formula is H2O.",
  "when you mix baking soda and vinegar they react and produce carbon dioxide gas. that makes bubbles.",
  "salt dissolves in water because water molecules pull apart the sodium and chloride ions.",
  "ice floats on water because water expands when it freezes making it less dense.",
  "rust forms when iron reacts with oxygen and water. that is why metal left in rain gets rusty.",
  "there are three states of matter: solid, liquid, and gas. temperature changes which state things are in.",
  "an element is a pure substance made of only one type of atom. gold and oxygen are elements.",

  # Geology
  "the earth has layers: the crust, mantle, outer core, and inner core.",
  "tectonic plates are huge pieces of the earth's crust that slowly move over time.",
  "earthquakes happen when tectonic plates push against each other and suddenly slip.",
  "volcanoes form where hot melted rock called magma pushes up through the earth's surface.",
  "fossils form when the remains of living things are buried and slowly replaced by minerals.",
  "mountains form when tectonic plates collide and push the land upward over millions of years.",
  "the grand canyon was carved by the colorado river over millions of years.",
  "rocks are classified into three types: igneous, sedimentary, and metamorphic.",
  "igneous rocks form when hot lava or magma cools and hardens.",
  "sedimentary rocks form in layers as sand, mud, and other materials pile up over time.",

  # Evolution basics
  "all living things are related and share common ancestors from long ago.",
  "evolution happens when living things slowly change over many many generations.",
  "natural selection means animals better suited to their environment are more likely to survive.",
  "dinosaurs lived millions of years ago and went extinct about 66 million years ago.",
  "birds are actually the living descendants of a group of dinosaurs.",
  "adaptations are features that help a living thing survive in its environment.",
  "humans and chimpanzees share about 98 percent of their DNA.",

  # Physics basics
  "gravity is a force that pulls objects toward each other. it keeps us on the ground.",
  "light travels faster than anything else in the universe.",
  "sound travels in waves. it moves faster through water than through air.",
  "energy cannot be created or destroyed. it can only change from one form to another.",
  "friction is the force that slows things down when two surfaces rub against each other.",
  "a magnet has two poles. opposite poles attract and same poles repel each other.",

  # Biology extras
  "plants make their own food using sunlight, water, and carbon dioxide. this is called photosynthesis.",
  "cells are the basic building blocks of all living things.",
  "DNA is like a set of instructions inside your cells that determines how you grow and develop.",
  "bacteria are tiny living things. some cause disease but many are actually helpful to us.",
  "viruses are even smaller than bacteria. they need to enter a cell to reproduce.",
  "animals that eat only plants are called herbivores. those that eat meat are called carnivores.",
  "amphibians like frogs can live both in water and on land.",
  "insects have six legs, three body parts, and usually have wings.",
  "spiders are not insects. they are arachnids and have eight legs instead of six.",
  "photosynthesis takes in carbon dioxide and releases oxygen which is what we breathe.",
]

science_explanations.each do |fact|
  8.times { segments << check!(fact) }
end

# ======================== 2. Multi-turn Conversations with Depth ========================

multi_turn_convos = [
  # Science topics
  "You: why do leaves change color in fall\nBot: the green color comes from something called chlorophyll.\nYou: what happens to it\nBot: when days get shorter the tree stops making chlorophyll and other colors show through.",

  "You: how does the moon cause tides\nBot: the moon's gravity pulls on the ocean water closest to it.\nYou: so only one side has high tide\nBot: actually there are two high tides. the far side bulges out too because of how gravity works.",

  "You: what causes an earthquake\nBot: the earth's crust is made of big plates that slowly move around.\nYou: and when they bump into each other\nBot: right. when the plates push against each other and suddenly slip that releases a lot of energy.",

  "You: how do airplanes fly\nBot: airplane wings are shaped so air moves faster over the top than the bottom.\nYou: why does that matter\nBot: faster moving air has lower pressure. the higher pressure below pushes the wing up. that is called lift.",

  "You: why is the ocean salty\nBot: rivers carry dissolved minerals from rocks into the ocean over millions of years.\nYou: why do rivers not taste salty then\nBot: rivers have much less salt because the water keeps flowing. in the ocean the salt builds up over time.",

  "You: what is a black hole\nBot: a black hole is a place in space where gravity is so strong that nothing can escape from it.\nYou: not even light\nBot: not even light. that is why they are called black holes. we detect them by how they affect things nearby.",

  "You: how do vaccines work\nBot: vaccines teach your immune system to recognize a germ before you actually get sick.\nYou: how do they teach it\nBot: they use a harmless piece of the germ so your body learns to make the right antibodies.",

  "You: why do we need sleep\nBot: sleep is when your brain organizes memories and your body repairs itself.\nYou: what happens if you do not sleep enough\nBot: you have trouble focusing, your mood gets worse, and your body cannot heal as well.",

  "You: how do our eyes see color\nBot: your eyes have special cells called cones that detect red, green, and blue light.\nYou: only three colors\nBot: yes but your brain mixes those signals together to create all the millions of colors you see.",

  "You: why do some animals migrate\nBot: they travel to find food, warmer weather, or safe places to have their babies.\nYou: how do they know where to go\nBot: some use the sun or stars to navigate. others follow the earth's magnetic field.",

  # History topics
  "You: who built the pyramids\nBot: the ancient egyptians built them as tombs for their pharaohs.\nYou: were they built by slaves\nBot: historians now think they were built by paid workers, not slaves. it was a huge organized effort.",

  "You: what started world war one\nBot: many things led to it including alliances and competition between countries.\nYou: what was the trigger\nBot: the assassination of archduke franz ferdinand of austria in 1914 set off a chain reaction.",

  "You: why did people explore the oceans\nBot: countries wanted to find new trade routes, resources, and expand their power.\nYou: who was a famous explorer\nBot: christopher columbus sailed across the atlantic in 1492 looking for a route to asia.",

  "You: what was the renaissance\nBot: it was a period in europe when art, science, and learning flourished after the middle ages.\nYou: when was it\nBot: it started in italy around the 1300s and spread across europe over the next few centuries.",

  # How things work
  "You: how does the internet work\nBot: computers send information to each other through cables, wifi signals, and satellites.\nYou: how does it know where to send things\nBot: every device has a unique address. routers direct the data to the right place like a postal system.",

  "You: how does a battery work\nBot: a battery stores energy using chemicals inside it.\nYou: how does it turn into electricity\nBot: chemical reactions inside the battery push electrons through a circuit creating an electric current.",

  "You: how do phones make calls\nBot: your voice is turned into a signal that travels to a cell tower and then to the other phone.\nYou: what about texts\nBot: texts work the same way but send data instead of a voice signal.",

  "You: how does a refrigerator stay cold\nBot: it uses a special liquid that absorbs heat from inside and releases it outside.\nYou: so it does not create cold\nBot: exactly. it removes heat. that is why the back of a fridge feels warm.",

  # Philosophy for kids
  "You: what does it mean to be a good person\nBot: it means treating others with respect and trying to do what is right even when it is hard.\nYou: but how do you know what is right\nBot: asking yourself if your actions help others and do not cause harm is a good place to start.",

  "You: is it ever okay to lie\nBot: most of the time honesty is important because trust is built on telling the truth.\nYou: what about a surprise party\nBot: small lies to protect someone or make them happy are different from lies that hurt people.",

  "You: why do people disagree about things\nBot: because everyone has different experiences that shape how they see the world.\nYou: does that mean no one is right\nBot: not always. some things are facts, but on opinions people can have different valid views.",

  "You: what makes something fair\nBot: fairness means everyone gets what they need and follows the same rules.\nYou: is fair the same as equal\nBot: not always. sometimes people need different things to have the same opportunity.",

  "You: why is it important to learn history\nBot: understanding the past helps us make better decisions in the future.\nYou: but it already happened\nBot: true, but patterns repeat. knowing what worked and what did not helps us do better.",

  "You: can animals think\nBot: many animals can solve problems and some can even use tools.\nYou: do they have feelings\nBot: scientists believe many animals experience emotions like joy, fear, and even grief.",
]

multi_turn_convos.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== 3. Reading Comprehension Style ========================

reading_comprehension = [
  "dolphins are mammals, not fish. they breathe air and feed milk to their babies.\nYou: are dolphins fish\nBot: no, dolphins are mammals. they breathe air just like we do.",

  "the sahara desert is the largest hot desert in the world. it is almost as big as the united states.\nYou: what is the largest hot desert\nBot: the sahara desert in africa. it covers a huge area almost the size of the united states.",

  "bees are important pollinators. without them many fruits and vegetables could not grow.\nYou: why are bees important\nBot: bees pollinate plants which means they help fruits and vegetables grow.",

  "the amazon rainforest produces about 20 percent of the world's oxygen.\nYou: why is the amazon rainforest important\nBot: it produces a large amount of the oxygen we breathe and is home to millions of species.",

  "the great wall of china was built over many centuries to protect against invasions from the north.\nYou: why was the great wall of china built\nBot: it was built to protect china from invasions and attacks from the north.",

  "octopuses have three hearts and blue blood. two hearts pump blood to the gills and one to the body.\nYou: how many hearts does an octopus have\nBot: three. two pump blood to the gills for oxygen and one pumps it to the rest of the body.",

  "the speed of light is about 186,000 miles per second. nothing can travel faster than that.\nYou: how fast does light travel\nBot: about 186,000 miles per second. it is the fastest thing in the universe.",

  "mount everest is the tallest mountain above sea level at about 29,032 feet.\nYou: what is the tallest mountain on earth\nBot: mount everest. it stands about 29,032 feet above sea level.",

  "honey never spoils. archaeologists have found 3000 year old honey in egyptian tombs that was still good.\nYou: can honey go bad\nBot: no, honey never really spoils. scientists found ancient honey that was still edible.",

  "the human brain uses about 20 percent of the body's total energy even though it is only 2 percent of body weight.\nYou: how much energy does the brain use\nBot: about 20 percent of all your body's energy, which is a lot for its small size.",

  "penguins cannot fly but they are excellent swimmers. some species can swim up to 22 miles per hour.\nYou: can penguins fly\nBot: no, but they are amazing swimmers. some can reach speeds of 22 miles per hour in the water.",

  "venus is the hottest planet even though mercury is closer to the sun. its thick atmosphere traps heat.\nYou: which planet is the hottest\nBot: venus, because its thick atmosphere traps heat like a blanket even though mercury is closer to the sun.",

  "the pacific ocean is the largest and deepest ocean. it covers more area than all the land on earth combined.\nYou: what is the biggest ocean\nBot: the pacific ocean. it is so big that it covers more area than all the land on earth put together.",

  "trees absorb carbon dioxide and release oxygen. a single large tree can provide oxygen for two people.\nYou: how do trees help us breathe\nBot: trees absorb carbon dioxide and release oxygen. one big tree can make enough oxygen for two people.",

  "the dead sea is so salty that you can float in it without even trying.\nYou: why can you float in the dead sea\nBot: because it has so much salt in the water that it makes you very buoyant.",

  "cheetahs can run up to 70 miles per hour but only in short bursts. they tire quickly.\nYou: how fast can a cheetah run\nBot: up to 70 miles per hour, but only for a short time before they need to rest.",

  "a group of stars that forms a pattern in the sky is called a constellation.\nYou: what is a constellation\nBot: a group of stars that appear to form a pattern or shape when viewed from earth.",

  "the earth's atmosphere is made mostly of nitrogen (about 78 percent) and oxygen (about 21 percent).\nYou: what is the atmosphere made of\nBot: mostly nitrogen at about 78 percent and oxygen at about 21 percent with small amounts of other gases.",

  "chameleons change color not just for camouflage but also to communicate and regulate body temperature.\nYou: why do chameleons change color\nBot: they change color to communicate with other chameleons, regulate temperature, and sometimes for camouflage.",

  "the amazon river carries more water than any other river in the world.\nYou: what is the largest river by water volume\nBot: the amazon river. it carries more water than any other river on earth.",

  "the rings of saturn are mostly made of chunks of ice and rock ranging from tiny grains to house sized pieces.\nYou: what are saturn's rings made of\nBot: they are made of chunks of ice and rock. some pieces are tiny and others are as big as a house.",

  "elephants are the only animals that cannot jump. their large size makes it impossible.\nYou: can elephants jump\nBot: no, elephants are the only mammals that cannot jump because of their size and weight.",

  "diamonds are made of carbon that has been under extreme pressure deep underground for millions of years.\nYou: how are diamonds formed\nBot: carbon is squeezed under extreme pressure deep in the earth for millions of years until it becomes a diamond.",

  "the human nose can detect over one trillion different scents.\nYou: how many smells can humans detect\nBot: scientists believe the human nose can distinguish over one trillion different scents.",
]

reading_comprehension.each do |rc|
  7.times { segments << check!(rc) }
end

# ======================== 4. Opinion and Reasoning ========================

opinion_reasoning = [
  "You: what is your favorite season\nBot: i think spring is nice because flowers bloom and the weather gets warm.",
  "You: is it better to be smart or kind\nBot: i think being kind is more important because kindness makes everyone feel good.",
  "You: what is the best animal\nBot: i think dogs are great because they are loyal and always happy to see you.",
  "You: do you think school is important\nBot: yes, because school teaches you how to think, not just what to know.",
  "You: which is better, books or movies\nBot: i like both but books let you imagine things in your own way which is really special.",
  "You: is it okay to be different\nBot: absolutely. being different is what makes the world interesting and full of new ideas.",
  "You: what matters more, talent or hard work\nBot: i think hard work matters more because talent without effort does not get very far.",
  "You: should kids have homework\nBot: some homework helps you practice, but too much can be stressful. balance is important.",
  "You: is it good to have lots of friends or a few close ones\nBot: i think a few close friends are better because deep friendships are really meaningful.",
  "You: which is more fun, summer or winter\nBot: i think summer is more fun because you can swim and play outside for longer.",
  "You: is winning important\nBot: trying your best is more important than winning because that is how you grow and improve.",
  "You: should people share their feelings\nBot: yes, because keeping feelings inside can make you feel worse. talking about them helps.",
  "You: is it okay to make mistakes\nBot: mistakes are one of the best ways to learn because they show you what to do differently.",
  "You: what is more important, money or happiness\nBot: happiness matters more because money cannot buy the things that truly make life good.",
  "You: do you think art is important\nBot: yes, art helps people express feelings and ideas that are hard to put into words.",
  "You: is technology good or bad\nBot: technology is a tool. it depends on how people use it. it can help or harm.",
  "You: should everyone learn to cook\nBot: i think so because cooking is a useful life skill and it can be really fun and creative.",
  "You: is it better to lead or follow\nBot: both are important. good leaders know when to listen and good followers know when to step up.",
  "You: do animals deserve the same rights as people\nBot: animals deserve to be treated with kindness and respect even if the rules are different.",
  "You: is competition healthy\nBot: healthy competition can push you to do better, but it should not make you feel bad about yourself.",
  "You: is it important to learn other languages\nBot: yes, because it helps you understand different cultures and communicate with more people.",
  "You: should kids be allowed to vote\nBot: kids have important opinions but voting requires understanding complex issues that takes time to learn.",
  "You: is it better to give or receive\nBot: giving feels wonderful because making someone else happy brings a special kind of joy.",
  "You: should we explore space\nBot: i think so because exploring helps us learn about the universe and could help us solve problems on earth.",
]

opinion_reasoning.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== 5. Problem Solving and Advice ========================

problem_solving = [
  "You: i have a test tomorrow and i am nervous\nBot: try studying a little bit at a time. take breaks and get good sleep tonight.",
  "You: my friend and i had a fight\nBot: give it some time. then tell them how you feel and listen to their side too.",
  "You: i do not know what i want to be when i grow up\nBot: that is totally okay. try lots of different things and see what you enjoy most.",
  "You: i feel left out at school\nBot: try joining a club or activity. you will meet people who share your interests.",
  "You: i have too much homework\nBot: make a list and do the hardest things first. break big tasks into smaller steps.",
  "You: i got a bad grade on my test\nBot: look at what you got wrong and learn from it. one test does not define how smart you are.",
  "You: someone is being mean to me\nBot: tell a trusted adult like a teacher or parent. you do not have to deal with it alone.",
  "You: i feel stressed all the time\nBot: try taking deep breaths and doing things you enjoy. talk to someone you trust about how you feel.",
  "You: i want to learn something new but do not know where to start\nBot: start with the basics. look up beginner guides online or ask someone who knows about it.",
  "You: i keep procrastinating\nBot: try the five minute rule. just start for five minutes and you will usually keep going.",
  "You: i am bored and there is nothing to do\nBot: try reading a book, learning something new online, or starting a creative project.",
  "You: my parents do not understand me\nBot: try writing down your thoughts and sharing them calmly. sometimes words on paper are easier.",
  "You: i am not good at sports\nBot: not everyone has to be. find activities you enjoy whether that is art, music, coding, or anything else.",
  "You: i want to save money but it is hard\nBot: start small. even saving a little bit each week adds up over time. set a goal to work toward.",
  "You: i am having trouble sleeping\nBot: try putting away screens an hour before bed. read a book or listen to calm music instead.",
  "You: i do not like how i look\nBot: everyone feels that way sometimes. focus on what your body can do, not just how it looks.",
  "You: i want to help the environment\nBot: start with small things like recycling, using less water, and walking instead of driving when you can.",
  "You: i feel shy around new people\nBot: that is normal. try asking them questions about themselves. most people love to talk about their interests.",
  "You: i said something i regret\nBot: apologize sincerely and learn from it. everyone says things they wish they could take back sometimes.",
  "You: i feel like giving up\nBot: take a break but do not quit. come back to it later with fresh eyes. you might surprise yourself.",
  "You: my friend is being pressured to do something bad\nBot: be there for them and help them say no. a real friend supports good choices.",
  "You: i have a big project and do not know where to start\nBot: break it into small pieces. do the first step today and the rest will follow.",
  "You: i am afraid of failing\nBot: failure is part of learning. every successful person has failed many times before getting it right.",
  "You: i want to be more confident\nBot: confidence comes from practice. try new things, celebrate small wins, and be kind to yourself.",
]

problem_solving.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== 6. History and World Knowledge ========================

history_knowledge = [
  "the ancient egyptians built the pyramids thousands of years ago as tombs for their rulers.",
  "the internet was invented so computers could share information with each other across long distances.",
  "the printing press was invented by johannes gutenberg around 1440 and changed the world forever.",
  "ancient rome was one of the most powerful civilizations in history and lasted for centuries.",
  "the wright brothers made the first successful powered airplane flight in 1903.",
  "ancient greeks invented democracy, the idea that citizens should have a voice in government.",
  "the industrial revolution changed the world by using machines to make things faster and cheaper.",
  "the united states declared independence from britain on july 4, 1776.",
  "world war two lasted from 1939 to 1945 and involved countries from all around the world.",
  "the cold war was a long period of tension between the united states and the soviet union.",
  "martin luther king jr. fought for civil rights and equality using peaceful protest.",
  "neil armstrong was the first person to walk on the moon in 1969.",
  "the invention of the wheel was one of the most important discoveries in human history.",
  "the renaissance was a time of great art and learning in europe starting around the 1300s.",
  "ancient china invented paper, gunpowder, the compass, and printing.",
  "the french revolution began in 1789 when the people of france fought for freedom and equality.",
  "the roman empire built roads that connected europe and allowed trade and travel.",
  "cleopatra was the last pharaoh of ancient egypt and was known for her intelligence.",
  "the silk road was an ancient trade route that connected china to the mediterranean.",
  "the telephone was invented by alexander graham bell in 1876.",
  "electricity changed everyday life. thomas edison helped make the light bulb practical for homes.",
  "the first computers were as big as entire rooms. now they fit in your pocket.",
  "galileo used a telescope to prove that the earth orbits the sun, not the other way around.",
  "the titanic sank in 1912 after hitting an iceberg on its very first voyage across the atlantic.",
  "the magna carta, signed in 1215, was one of the first documents to limit the power of a king.",
  "world war one was called the great war because people thought it would be the last major war.",
  "the berlin wall divided east and west germany for 28 years before it was torn down in 1989.",
  "mahatma gandhi led india to independence from british rule using nonviolent resistance.",
  "the ancient maya built great cities and developed an advanced calendar and writing system.",
  "charles darwin developed the theory of evolution after studying animals on the galapagos islands.",
  "the space race between the united states and soviet union pushed humans to reach the moon.",
  "nelson mandela fought against apartheid in south africa and became its first black president.",
]

history_knowledge.each do |fact|
  8.times { segments << check!(fact) }
end

# ======================== 7. Definitions and Explanations ========================

definitions = [
  "You: what is democracy\nBot: democracy means the people get to vote and choose their leaders.",
  "You: what is an ecosystem\nBot: an ecosystem is a community of living things that depend on each other and their environment.",
  "You: what is gravity\nBot: gravity is a force that pulls objects toward each other. it is what keeps us on the ground.",
  "You: what is photosynthesis\nBot: photosynthesis is how plants use sunlight, water, and carbon dioxide to make their own food.",
  "You: what is an atom\nBot: an atom is the tiniest building block of matter. everything around you is made of atoms.",
  "You: what is the atmosphere\nBot: the atmosphere is the layer of gases surrounding the earth that protects us and gives us air to breathe.",
  "You: what does extinct mean\nBot: extinct means a species has completely died out and no more of that animal or plant exists anywhere.",
  "You: what is a continent\nBot: a continent is one of the seven large landmasses on earth like africa, asia, and north america.",
  "You: what is culture\nBot: culture is the beliefs, customs, food, art, and way of life shared by a group of people.",
  "You: what is a molecule\nBot: a molecule is a group of atoms bonded together. water is a molecule made of hydrogen and oxygen.",
  "You: what is climate\nBot: climate is the average weather in a place over a long time. weather changes daily but climate is a pattern.",
  "You: what is a revolution\nBot: a revolution is a big change, often when people overthrow a government to create a new system.",
  "You: what is migration\nBot: migration is when animals travel long distances, usually with the seasons, to find food or warmth.",
  "You: what is renewable energy\nBot: renewable energy comes from sources that do not run out like sunlight, wind, and water.",
  "You: what is a vaccine\nBot: a vaccine is a substance that teaches your body to fight a specific disease without getting sick.",
  "You: what is erosion\nBot: erosion is when wind, water, or ice slowly wears away rock and soil over time.",
  "You: what is a cell\nBot: a cell is the smallest unit of life. your body is made of trillions of tiny cells.",
  "You: what is an orbit\nBot: an orbit is the curved path one object takes around another, like the earth going around the sun.",
  "You: what is pollution\nBot: pollution is harmful substances released into the air, water, or soil that damage the environment.",
  "You: what is a fossil fuel\nBot: fossil fuels like coal, oil, and gas formed from ancient plants and animals buried millions of years ago.",
  "You: what is the equator\nBot: the equator is an imaginary line around the middle of the earth that divides it into north and south.",
  "You: what is a peninsula\nBot: a peninsula is a piece of land that is surrounded by water on three sides but connected to the mainland.",
  "You: what is an archipelago\nBot: an archipelago is a chain or group of islands, like hawaii or the philippines.",
  "You: what is a hypothesis\nBot: a hypothesis is an educated guess that scientists make before doing an experiment to test it.",
  "You: what is a metaphor\nBot: a metaphor compares two unlike things by saying one is the other, like the world is a stage.",
  "You: what is a civilization\nBot: a civilization is a complex society with its own government, culture, religion, and technology.",
  "You: what is biodiversity\nBot: biodiversity means having many different types of plants, animals, and other living things in an area.",
  "You: what is a constitution\nBot: a constitution is a set of rules and laws that explain how a government should work.",
  "You: what is empathy\nBot: empathy is the ability to understand and share the feelings of another person.",
  "You: what is an equation\nBot: an equation is a math statement that shows two things are equal, like 2 plus 3 equals 5.",
]

definitions.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== 8. Creative and Hypothetical Thinking ========================

creative_hypothetical = [
  "You: if you could have any superpower what would it be\nBot: i would choose the ability to fly so i could see the whole world from above.",
  "You: what would happen if there was no gravity\nBot: everything would float away into space. we need gravity to stay on earth.",
  "You: what if humans could breathe underwater\nBot: we could explore the entire ocean and discover so many new species we have never seen.",
  "You: what would you do if you could time travel\nBot: i would visit ancient civilizations to see what life was really like back then.",
  "You: what if animals could talk\nBot: we could finally understand what they think and feel. imagine having a conversation with a dolphin.",
  "You: what if the sun disappeared\nBot: earth would get very cold and dark. plants would die without sunlight and so would most life.",
  "You: imagine a world where everyone could read minds\nBot: there would be no secrets. people might be more honest but privacy would be gone completely.",
  "You: what if you discovered a new planet\nBot: i would want to know if it had water and air. those are the first signs it might support life.",
  "You: what if school only lasted two hours a day\nBot: we would need to learn more efficiently. maybe technology could help us learn faster.",
  "You: what would you invent if you could make anything\nBot: a machine that cleans the oceans. keeping our water clean would help all living things.",
  "You: what if you woke up 100 years in the future\nBot: i would be amazed by the technology but i would miss the people and places i knew.",
  "You: what if trees could move\nBot: forests would look completely different every day and trees might walk toward the sunniest spots.",
  "You: what if you could only eat one food forever\nBot: i would pick something nutritious like potatoes because you can cook them in so many ways.",
  "You: what if we found life on another planet\nBot: it would be the most important discovery ever. we would finally know we are not alone.",
  "You: what if rain was a different color\nBot: if rain were blue the world would look like a painting every time it rained.",
  "You: what if you were the president for a day\nBot: i would focus on education and the environment because those affect everyone's future.",
  "You: what if there were no oceans\nBot: the earth would be much drier and hotter. most of our weather depends on the oceans.",
  "You: what if you could talk to your future self\nBot: i would ask what mistakes to avoid and what the most important things to focus on are.",
  "You: what if money did not exist\nBot: people would probably trade goods and services. communities might work together more closely.",
  "You: what if everyone lived to be 200 years old\nBot: people would have time for many different careers and could learn so much more in one lifetime.",
  "You: what if you could shrink to the size of an ant\nBot: the world would look completely different. a puddle would seem like a lake and grass like a forest.",
  "You: what if the internet stopped working\nBot: people would need to go back to using libraries, writing letters, and talking on landline phones.",
  "You: what if dinosaurs were still alive\nBot: our world would be very different. humans might not have evolved the same way at all.",
  "You: what if we could control the weather\nBot: we could end droughts and floods but we would have to be careful not to create new problems.",
]

creative_hypothetical.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== 9. Everyday Knowledge ========================

everyday_knowledge = [
  # Health and body
  "brushing your teeth twice a day helps prevent cavities and keeps your gums healthy.",
  "when you exercise your heart gets stronger and pumps blood more efficiently.",
  "drinking enough water helps your body stay hydrated and your brain work better.",
  "eating a balanced diet with fruits, vegetables, protein, and grains gives your body what it needs.",
  "getting eight to ten hours of sleep helps your body grow and your brain process what you learned.",
  "washing your hands with soap and water for twenty seconds kills most germs.",
  "wearing sunscreen protects your skin from harmful rays that can cause sunburn.",
  "stretching before exercise helps prevent injuries and makes your muscles more flexible.",

  # How things work
  "electricity flows through wires like water flows through pipes. it powers our lights and devices.",
  "a car engine works by burning gasoline to create small explosions that push pistons up and down.",
  "a microwave heats food by making water molecules vibrate very fast which creates heat.",
  "a refrigerator works by removing heat from the inside and releasing it into the room.",
  "solar panels turn sunlight into electricity using special materials called semiconductors.",
  "a compass works because earth has a magnetic field and the needle always points north.",
  "the brakes on a bike work by pressing pads against the wheel to create friction and slow it down.",
  "wifi sends information through the air using radio waves that your devices can pick up.",

  # Social skills and life tips
  "listening carefully when someone talks shows respect and helps you understand their point of view.",
  "saying please and thank you might seem small but it makes a big difference in how people feel.",
  "being on time shows that you respect other people's time and are responsible.",
  "admitting when you are wrong takes courage but it earns respect from others.",
  "taking notes in class helps you remember what you learned and study more effectively later.",
  "setting goals gives you something to work toward and helps you stay motivated.",
  "learning to manage your time well is one of the most useful skills you can develop.",
  "treating everyone with kindness, even people you disagree with, shows maturity.",

  # Study tips
  "studying in short sessions with breaks in between works better than cramming all at once.",
  "teaching something you learned to someone else is one of the best ways to remember it.",
  "making flashcards can help you memorize facts for tests and quizzes.",
  "reading the questions before a test passage helps you know what to look for.",
  "taking practice tests is one of the most effective ways to prepare for the real thing.",
  "writing things down by hand helps your brain remember them better than just reading.",

  # Cooking and food
  "boiling water reaches 212 degrees fahrenheit or 100 degrees celsius at sea level.",
  "yeast makes bread rise by producing carbon dioxide gas bubbles in the dough.",
  "eggs are used in baking because they help hold ingredients together and add moisture.",
  "salt enhances the flavor of food by making your taste buds more sensitive.",
  "fruits and vegetables get their colors from natural chemicals. orange carrots have beta carotene.",
  "milk contains calcium which helps build strong bones and teeth.",

  # Nature and environment
  "recycling helps reduce waste and saves natural resources like trees and metals.",
  "composting turns food scraps into rich soil that helps plants grow.",
  "turning off lights when you leave a room saves electricity and reduces your energy use.",
  "planting trees helps clean the air because trees absorb carbon dioxide and release oxygen.",
  "using a reusable water bottle reduces plastic waste that can end up in the ocean.",
  "bees pollinate about one third of the food we eat so protecting them is important.",
]

everyday_knowledge.each do |fact|
  8.times { segments << check!(fact) }
end

# ======================== 10. Well-formed Prose Passages ========================

prose_passages = [
  "the ocean covers most of our planet. it is home to millions of different creatures.\nsome parts are so deep that sunlight cannot reach them.",

  "the earth is always moving even though we cannot feel it.\nit spins on its axis and orbits the sun at thousands of miles per hour.",

  "music has been part of human culture for thousands of years.\npeople use it to celebrate, to mourn, to tell stories, and to express emotions.",

  "the desert may look empty but it is full of life.\ncactuses store water in their thick stems and animals come out at night when it is cooler.",

  "every snowflake has a unique shape because of how ice crystals form.\nthe temperature and humidity in the cloud determine each snowflake's pattern.",

  "our galaxy, the milky way, contains billions of stars.\nthe sun is just one ordinary star among all of them.",

  "ancient people looked at the stars and saw patterns they called constellations.\nthey used these patterns to navigate and to tell stories about their gods and heroes.",

  "the arctic and antarctic are two very different places.\nthe arctic is an ocean covered in ice while antarctica is a continent covered in ice and snow.",

  "languages change over time as people use them in new ways.\nenglish spoken today is very different from the english spoken 500 years ago.",

  "volcanoes can be destructive but they also create new land.\nthe hawaiian islands were formed by volcanic eruptions on the ocean floor.",

  "reading opens doors to new worlds and new ideas.\nthrough books you can travel anywhere, meet anyone, and learn almost anything.",

  "the human body is an amazing machine that works even while you sleep.\nyour heart beats, your lungs breathe, and your brain processes the day's memories.",

  "forests are sometimes called the lungs of the earth.\nthey absorb carbon dioxide and release the oxygen that animals need to breathe.",

  "water is essential for all life on earth.\nit makes up about 60 percent of your body and covers about 71 percent of the planet's surface.",

  "birds migrate thousands of miles every year following the seasons.\nsome fly nonstop over oceans, navigating by the stars and the earth's magnetic field.",

  "the invention of writing changed everything for human civilization.\nfor the first time people could record their ideas and pass knowledge to future generations.",

  "caves hold records of ancient life including paintings made thousands of years ago.\nthese artworks show us what early humans thought about and how they lived.",

  "the moon affects our planet in many ways.\nits gravity creates ocean tides and its light brightens our night sky.",

  "insects are the most numerous group of animals on earth.\nscientists have identified over a million species and believe there are millions more to discover.",

  "mountains form over millions of years as tectonic plates push against each other.\nthe himalayas are still growing taller by about one centimeter each year.",

  "rivers have shaped human history by providing water, food, and transportation.\nmost ancient civilizations grew up along the banks of major rivers.",

  "the seasons happen because the earth is tilted on its axis.\nwhen the north pole tilts toward the sun it is summer. when it tilts away it is winter.",

  "the deep ocean is one of the least explored places on earth.\nwe know more about the surface of the moon than we do about the ocean floor.",

  "lightning strikes the earth about 100 times every second.\neach bolt can heat the air around it to 30,000 degrees, five times hotter than the sun.",

  "butterflies go through an amazing transformation called metamorphosis.\nthey start as caterpillars, form a chrysalis, and emerge as completely different creatures.",

  "the great barrier reef is the largest living structure on earth.\nit stretches over 1,400 miles along the coast of australia and can be seen from space.",

  "our solar system formed about 4.6 billion years ago from a cloud of gas and dust.\nthe sun formed first, then the planets slowly came together from the remaining material.",

  "a single teaspoon of soil can contain more organisms than there are people on earth.\nbacteria, fungi, and tiny creatures all work together to keep the soil healthy.",

  "the atmosphere protects us from harmful radiation and keeps the planet warm.\nwithout it the earth would be a frozen, lifeless rock floating in space.",

  "photography was invented in the 1800s and changed how people record history.\nbefore cameras, artists had to paint or draw everything they wanted to remember.",
]

prose_passages.each do |passage|
  6.times { segments << check!(passage) }
end

# ======================== Additional: Extended Science Conversations ========================

extended_science = [
  "You: how do plants know which way to grow\nBot: plants can sense gravity and light. their roots grow downward and stems grow toward the light.",

  "You: why does ice float\nBot: water expands when it freezes which makes ice less dense than liquid water. less dense things float.",

  "You: how do scientists measure the age of fossils\nBot: they use a method called radioactive dating which measures how much certain elements have decayed over time.",

  "You: why do we see our breath when it is cold\nBot: the warm water vapor in your breath cools down quickly in cold air and turns into tiny visible droplets.",

  "You: how does a rainbow form\nBot: sunlight enters a raindrop, bends, and splits into different colors. each color bends at a different angle.",

  "You: why does the moon look different each night\nBot: the moon orbits earth and we see different amounts of its sunlit side. these are called moon phases.",

  "You: what makes a sunset red\nBot: at sunset, light travels through more atmosphere. blue light scatters away and red light reaches your eyes.",

  "You: how do birds fly\nBot: birds have hollow bones to stay light and wings shaped to create lift. they flap to push air down.",

  "You: why is venus so hot\nBot: venus has a thick atmosphere full of carbon dioxide that traps heat. it is like a runaway greenhouse effect.",

  "You: how deep is the ocean\nBot: the deepest point is the mariana trench at almost 36,000 feet. that is deeper than mount everest is tall.",

  "You: why do stars twinkle\nBot: starlight passes through layers of moving air in our atmosphere which bends the light and makes it flicker.",

  "You: how does sound work\nBot: sound is made of vibrations that travel through the air as waves. your ears detect these waves.",

  "You: why is blood red\nBot: blood contains hemoglobin, a protein that carries oxygen. when hemoglobin binds with oxygen it turns red.",

  "You: what causes wind\nBot: wind happens when the sun heats the air unevenly. warm air rises and cooler air rushes in to replace it.",

  "You: how do magnets work\nBot: magnets create an invisible field around them. they attract metals like iron and can push or pull other magnets.",

  "You: why do onions make you cry\nBot: when you cut an onion it releases a gas that mixes with the moisture in your eyes and forms a mild acid.",
]

extended_science.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== Additional: More History Conversations ========================

history_convos = [
  "You: who was cleopatra\nBot: cleopatra was the last pharaoh of ancient egypt. she was known for her intelligence and political skill.",

  "You: what was the ice age\nBot: the ice age was a time when much of the earth was covered in thick sheets of ice. it ended about 10,000 years ago.",

  "You: who was galileo\nBot: galileo was an italian scientist who used a telescope to prove that the earth orbits the sun.",

  "You: what was the silk road\nBot: the silk road was a network of trade routes connecting china to europe. goods and ideas traveled along it.",

  "You: who was marie curie\nBot: marie curie was a scientist who discovered radioactivity. she was the first woman to win a nobel prize.",

  "You: what caused the fall of rome\nBot: many things contributed including invasions, economic problems, and the empire becoming too large to manage.",

  "You: who invented the light bulb\nBot: thomas edison made the light bulb practical for everyday use, though others also worked on the idea.",

  "You: what was the cold war\nBot: it was a long period of tension between the united states and the soviet union that lasted from the 1940s to 1991.",

  "You: who were the vikings\nBot: the vikings were seafaring people from scandinavia who explored, traded, and raided across europe about 1,000 years ago.",

  "You: what was the renaissance about\nBot: the renaissance was a rebirth of art, science, and learning in europe inspired by ancient greek and roman ideas.",

  "You: who was rosa parks\nBot: rosa parks refused to give up her bus seat in 1955. her courage helped spark the civil rights movement.",

  "You: how were the continents formed\nBot: millions of years ago all the continents were one big landmass. they slowly drifted apart over time.",

  "You: what was the space race\nBot: it was a competition between the united states and the soviet union to achieve the greatest space exploration firsts.",

  "You: who was leonardo da vinci\nBot: he was an artist, inventor, and scientist from the renaissance. he painted the mona lisa and designed flying machines.",

  "You: what was the industrial revolution\nBot: it was a time when machines replaced hand labor. factories changed how goods were made and how people lived.",

  "You: who wrote the declaration of independence\nBot: thomas jefferson was the main author. it declared the american colonies free from british rule in 1776.",
]

history_convos.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== Additional: Math and Logic ========================

math_logic = [
  "You: what is a fraction\nBot: a fraction represents a part of a whole. like one half means one part out of two equal parts.",
  "You: what is a percentage\nBot: a percentage is a number out of 100. fifty percent means fifty out of every hundred.",
  "You: what is the order of operations\nBot: you do parentheses first, then exponents, then multiplication and division, then addition and subtraction.",
  "You: what is an average\nBot: the average is the sum of all numbers divided by how many numbers there are.",
  "You: what is geometry\nBot: geometry is the part of math that deals with shapes, angles, and measurements of space.",
  "You: what is area\nBot: area is the amount of space inside a flat shape. for a rectangle you multiply the length by the width.",
  "You: what is volume\nBot: volume is the amount of space inside a three dimensional object like a box or a sphere.",
  "You: what is a prime number\nBot: a prime number can only be divided evenly by one and itself. like 2, 3, 5, 7, and 11.",
  "You: what is pi\nBot: pi is a special number, about 3.14, that shows up whenever you work with circles.",
  "You: what is probability\nBot: probability is how likely something is to happen. flipping a coin gives you a 50 percent chance of heads.",
  "You: why do we need to learn math\nBot: math helps you solve problems, think logically, and understand patterns in the world around you.",
  "You: what is negative number\nBot: a negative number is less than zero. it is like going below ground level or owing money.",
  "You: what is a variable\nBot: a variable is a letter like x that stands for a number you do not know yet in math.",
  "You: what is symmetry\nBot: symmetry means both sides of something look the same. a butterfly's wings are symmetrical.",
  "You: what is an angle\nBot: an angle is formed where two lines meet. a right angle is 90 degrees like the corner of a square.",
  "You: what is a ratio\nBot: a ratio compares two amounts. if there are 3 cats and 5 dogs the ratio of cats to dogs is 3 to 5.",
]

math_logic.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== Additional: Geography ========================

geography = [
  "there are seven continents: africa, antarctica, asia, australia, europe, north america, and south america.",
  "the nile river in africa is one of the longest rivers in the world at over 4,000 miles.",
  "the pacific ocean is the largest ocean. it is bigger than all the land on earth combined.",
  "mount everest is the tallest mountain above sea level located in the himalayas between nepal and china.",
  "the sahara desert stretches across northern africa. it is the largest hot desert in the world.",
  "the amazon rainforest spans several south american countries and contains incredible biodiversity.",
  "australia is both a country and a continent. it is home to many unique animals like kangaroos and koalas.",
  "the arctic is an ocean mostly covered in sea ice. the antarctic is a frozen continent.",
  "the mediterranean sea is surrounded by europe, africa, and asia and has warm mild weather.",
  "the great lakes are five large lakes in north america that hold about 20 percent of the world's fresh water.",
  "japan is an island nation made up of about 6,800 islands in the pacific ocean.",
  "the andes mountains in south america are the longest mountain range on land.",
  "iceland sits on top of a volcanic hotspot and has many geysers and hot springs.",
  "the congo rainforest in africa is the second largest tropical rainforest in the world.",
  "india is a large country in south asia with over a billion people and many different languages and cultures.",
  "the mississippi river flows through the center of the united states from minnesota to the gulf of mexico.",
]

geography.each do |fact|
  8.times { segments << check!(fact) }
end

# ======================== Additional: Technology and Innovation ========================

tech_innovation = [
  "You: how do computers work\nBot: computers use tiny switches called transistors that turn on and off to process information as ones and zeros.",
  "You: what is artificial intelligence\nBot: AI is when computers learn to do things that normally require human thinking, like recognizing faces.",
  "You: how do video games work\nBot: a computer draws images on the screen very fast, over 30 times per second, to create the illusion of movement.",
  "You: what is coding\nBot: coding is writing instructions for a computer to follow using a special language it can understand.",
  "You: how does GPS work\nBot: GPS uses satellites orbiting earth. your device measures signals from several satellites to find your location.",
  "You: what is the cloud\nBot: the cloud means storing data on powerful computers somewhere else instead of on your own device.",
  "You: how do touchscreens work\nBot: touchscreens detect the small electrical charge in your finger and figure out exactly where you touched.",
  "You: what is a robot\nBot: a robot is a machine programmed to carry out tasks. some can move around and interact with the world.",
  "You: how does email work\nBot: your email travels through the internet from server to server until it reaches the inbox of the person you sent it to.",
  "You: what is 3D printing\nBot: a 3D printer builds objects layer by layer using materials like plastic or metal based on a digital design.",
  "You: how do electric cars work\nBot: electric cars use batteries instead of gasoline. an electric motor turns the wheels using stored electrical energy.",
  "You: what is virtual reality\nBot: VR uses a headset to create a computer generated world that feels like you are actually inside it.",
  "You: who invented the internet\nBot: no single person invented it. many scientists and engineers worked together starting in the 1960s.",
  "You: what is a search engine\nBot: a search engine scans billions of web pages and helps you find information by matching your search words.",
  "You: how do satellites stay in orbit\nBot: they move fast enough that their forward motion balances the pull of gravity keeping them circling earth.",
  "You: what is blockchain\nBot: blockchain is a way to record information so that it cannot be changed. it is used in digital currencies.",
]

tech_innovation.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== Additional: Emotions and Social Intelligence ========================

emotional_social = [
  "You: why do people get angry\nBot: anger usually happens when we feel threatened, frustrated, or treated unfairly. it is a normal emotion.",
  "You: how can i deal with anxiety\nBot: try deep breathing, talk to someone you trust, and remind yourself that the feeling will pass.",
  "You: what is empathy\nBot: empathy is putting yourself in someone else's shoes and understanding how they feel.",
  "You: why is it important to apologize\nBot: apologizing shows you care about the other person's feelings and want to make things right.",
  "You: how do i make new friends\nBot: be yourself, show interest in others, and look for people who share your interests.",
  "You: why do people bully others\nBot: bullying often comes from insecurity. the bully might be dealing with their own problems.",
  "You: how can i be a good listener\nBot: give your full attention, do not interrupt, and show you care about what the person is saying.",
  "You: is it okay to cry\nBot: absolutely. crying is a natural way to express emotions and it can actually help you feel better.",
  "You: what should i do if i feel lonely\nBot: reach out to someone, join a group activity, or try a new hobby where you can meet people.",
  "You: how do i deal with peer pressure\nBot: trust your own judgment. real friends will respect your choices even if they are different.",
  "You: why is gratitude important\nBot: being grateful helps you notice the good things in life and makes you feel happier overall.",
  "You: how can i be more patient\nBot: remind yourself that good things take time. practice waiting calmly in small everyday situations.",
  "You: what does it mean to be brave\nBot: being brave does not mean having no fear. it means doing what is right even when you are scared.",
  "You: how do i handle disappointment\nBot: let yourself feel sad for a bit, then focus on what you can learn and what comes next.",
  "You: why do people have different opinions\nBot: because everyone has different experiences, values, and ways of seeing the world.",
  "You: how can i build self confidence\nBot: set small goals and achieve them. celebrate your progress and do not compare yourself to others.",
]

emotional_social.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== Additional: Literature and Language ========================

literature_language = [
  "You: what is a simile\nBot: a simile compares two things using like or as. for example, her smile was as bright as the sun.",
  "You: what is the difference between fiction and nonfiction\nBot: fiction tells made up stories while nonfiction is about real facts, people, and events.",
  "You: what is a protagonist\nBot: the protagonist is the main character of a story. the story usually follows their journey.",
  "You: what is a haiku\nBot: a haiku is a short japanese poem with three lines of five, seven, and five syllables.",
  "You: what makes a good story\nBot: a good story has interesting characters, a problem to solve, and an ending that feels satisfying.",
  "You: what is a myth\nBot: a myth is an ancient story that explains how the world works or teaches a lesson about life.",
  "You: what is an autobiography\nBot: an autobiography is a book someone writes about their own life and experiences.",
  "You: what is a synonym\nBot: a synonym is a word that means the same thing as another word. happy and glad are synonyms.",
  "You: what is an antonym\nBot: an antonym is a word that means the opposite of another word. hot and cold are antonyms.",
  "You: what is alliteration\nBot: alliteration is when words near each other start with the same sound, like peter piper picked peppers.",
  "You: what is a genre\nBot: a genre is a category of stories like mystery, science fiction, fantasy, or romance.",
  "You: what is a narrator\nBot: a narrator is the person or voice telling the story. sometimes it is a character in the story.",
  "You: why is reading important\nBot: reading builds vocabulary, improves thinking skills, and lets you experience lives different from your own.",
  "You: what is a fable\nBot: a fable is a short story, often with animal characters, that teaches a moral or lesson.",
  "You: what is rhyme\nBot: rhyme is when words have the same ending sound, like cat and hat or moon and spoon.",
  "You: what is a theme\nBot: a theme is the main message or lesson of a story, like friendship, courage, or honesty.",
]

literature_language.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== Additional: Environment and Sustainability ========================

environment = [
  "You: what is climate change\nBot: climate change is the long term shift in temperatures and weather patterns mainly caused by burning fossil fuels.",
  "You: why are polar ice caps melting\nBot: rising global temperatures caused by greenhouse gases are melting ice at the north and south poles.",
  "You: what is the greenhouse effect\nBot: certain gases in the atmosphere trap heat from the sun, like a greenhouse. too much causes warming.",
  "You: why should we recycle\nBot: recycling reduces waste, saves energy, and preserves natural resources like trees and metals.",
  "You: what are endangered species\nBot: endangered species are animals or plants at risk of dying out completely because of habitat loss or other threats.",
  "You: why are rainforests being cut down\nBot: people clear rainforests for farming, logging, and building. this destroys habitats and hurts biodiversity.",
  "You: what is renewable energy\nBot: energy from sources that do not run out like solar, wind, and hydropower. they produce less pollution.",
  "You: what can kids do to help the planet\nBot: reduce waste, recycle, save water and energy, plant trees, and learn about environmental issues.",
  "You: what is deforestation\nBot: deforestation is clearing large areas of forest. it hurts wildlife, contributes to climate change, and causes erosion.",
  "You: why are bees disappearing\nBot: bees face threats from pesticides, habitat loss, disease, and climate change. protecting them is vital.",
  "You: what is an oil spill\nBot: an oil spill is when petroleum leaks into the ocean, harming sea life, birds, and coastal ecosystems.",
  "You: what is a carbon footprint\nBot: a carbon footprint is the total amount of greenhouse gases produced by a person, company, or activity.",
  "You: how does plastic harm the ocean\nBot: plastic does not break down easily. sea animals can eat it or get tangled in it, which can be deadly.",
  "You: what is sustainable living\nBot: sustainable living means using resources carefully so there will be enough for future generations too.",
  "You: why is fresh water important\nBot: only about 3 percent of earth's water is fresh. we need it for drinking, farming, and industry.",
  "You: what is biodiversity and why does it matter\nBot: biodiversity means variety of life. ecosystems with more species are healthier and more resilient.",
]

environment.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== Additional: Arts and Culture ========================

arts_culture = [
  "music is a universal language. people all around the world create and enjoy it in many different forms.",
  "the mona lisa was painted by leonardo da vinci and is one of the most famous paintings in the world.",
  "ballet is a form of dance that originated in italy and was developed further in france and russia.",
  "shakespeare wrote plays and poetry over 400 years ago and his works are still performed today.",
  "origami is the japanese art of folding paper into shapes like cranes, flowers, and animals.",
  "jazz music began in new orleans in the early 1900s and blends african and european musical traditions.",
  "the ancient greeks performed plays in outdoor theaters. they invented comedy and tragedy as art forms.",
  "hip hop started in new york city in the 1970s and has become one of the most popular music genres worldwide.",
  "the statue of liberty was a gift from france to the united states and stands in new york harbor.",
  "animation brings drawings to life by showing many slightly different images very quickly.",
  "photography captures a moment in time using light. digital cameras use sensors instead of film.",
  "folk tales are stories passed down through generations that teach lessons about life and culture.",
  "pottery is one of the oldest art forms. people have been shaping clay into useful objects for thousands of years.",
  "the taj mahal in india is a beautiful marble building considered one of the wonders of the world.",
  "graffiti started as street art and some people now consider it a legitimate art form.",
  "museums preserve art, history, and science so that people can learn from the past and be inspired.",
]

arts_culture.each do |fact|
  8.times { segments << check!(fact) }
end

# ======================== Additional: Critical Thinking ========================

critical_thinking = [
  "You: how do you know if something is true\nBot: check the source, look for evidence, and see if other reliable sources say the same thing.",
  "You: what is bias\nBot: bias is when someone favors one side over another, often without realizing it.",
  "You: why should we ask questions\nBot: asking questions helps you learn, think deeper, and avoid accepting things without understanding them.",
  "You: what is the difference between fact and opinion\nBot: a fact can be proven true. an opinion is what someone thinks or believes.",
  "You: how can i tell if news is fake\nBot: check who wrote it, look at the source, see if other reliable outlets report the same thing.",
  "You: why do people believe different things\nBot: because they grow up with different cultures, experiences, and information that shape their views.",
  "You: what does it mean to think critically\nBot: it means carefully analyzing information instead of just accepting it at face value.",
  "You: is everything on the internet true\nBot: no, anyone can post anything online. always check facts from trusted sources before believing them.",
  "You: why is evidence important\nBot: evidence supports claims with facts. without evidence a statement is just a guess or opinion.",
  "You: what is a logical fallacy\nBot: a logical fallacy is a mistake in reasoning that makes an argument seem correct when it is not.",
  "You: how do scientists test ideas\nBot: they use the scientific method: ask a question, form a hypothesis, test it, and analyze the results.",
  "You: why do experts sometimes disagree\nBot: new evidence can change understanding. science evolves as we learn more about the world.",
  "You: what makes a good argument\nBot: a good argument has clear reasoning, solid evidence, and considers other points of view.",
  "You: should you believe something just because an adult says it\nBot: adults are often right, but it is still good to ask questions and understand why something is true.",
  "You: what is perspective\nBot: perspective is how you see things based on your own experiences. different people can see the same thing differently.",
  "You: how can i form my own opinions\nBot: gather information from different sources, think about it carefully, and decide what makes sense to you.",
]

critical_thinking.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== Additional: World Cultures ========================

world_cultures = [
  "people around the world celebrate different holidays based on their culture, religion, and history.",
  "chinese new year is celebrated with dragon dances, fireworks, and family gatherings.",
  "diwali is the festival of lights celebrated by hindus, sikhs, and jains around the world.",
  "day of the dead is a mexican tradition where families honor and remember loved ones who have passed.",
  "ramadan is a month when many muslims fast from sunrise to sunset as an act of faith.",
  "the olympics bring athletes from countries around the world together to compete in many different sports.",
  "many cultures have their own traditional clothing, music, food, and stories that make them unique.",
  "sushi is a traditional japanese food made with vinegared rice, seafood, and vegetables.",
  "flamenco is a passionate style of music and dance that comes from southern spain.",
  "the great wall of china stretches thousands of miles and took centuries to build.",
  "carnival in brazil features colorful parades, music, and dancing in the streets.",
  "aboriginal australians have one of the oldest continuous cultures in the world, spanning over 50,000 years.",
  "the maori of new zealand perform the haka, a powerful traditional dance used for many occasions.",
  "pasta comes in hundreds of shapes and is a staple food in italy.",
  "the inuit people of the arctic have many words to describe different types of snow and ice.",
  "traditional african drumming uses complex rhythms and is an important part of many ceremonies.",
]

world_cultures.each do |fact|
  8.times { segments << check!(fact) }
end

# ======================== Additional: Space Exploration ========================

space_exploration = [
  "You: have humans been to mars\nBot: not yet, but scientists are working on plans to send astronauts to mars in the future.",
  "You: what is the international space station\nBot: the ISS is a large spacecraft orbiting earth where astronauts live and do science experiments.",
  "You: how far away is the moon\nBot: the moon is about 238,900 miles from earth. it took apollo astronauts about three days to get there.",
  "You: what is a light year\nBot: a light year is the distance light travels in one year, about 5.88 trillion miles. it measures space distances.",
  "You: are there other planets with life\nBot: we have not found any yet, but scientists are searching. some planets might have the right conditions.",
  "You: what happens to astronauts in space\nBot: in space astronauts float because of microgravity. their muscles and bones get weaker without exercise.",
  "You: how big is the universe\nBot: the observable universe is about 93 billion light years across, and it is still expanding.",
  "You: what is a nebula\nBot: a nebula is a giant cloud of gas and dust in space. new stars are born inside nebulae.",
  "You: what is a supernova\nBot: a supernova is the explosion of a massive star at the end of its life. it can outshine an entire galaxy.",
  "You: will the sun ever burn out\nBot: yes, in about five billion years. but that is so far away that we do not need to worry about it.",
  "You: what is a dwarf planet\nBot: a dwarf planet is round and orbits the sun but has not cleared its orbit of other objects. pluto is one.",
  "You: how do rockets work\nBot: rockets push exhaust gases out the back at high speed. the reaction pushes the rocket forward.",
  "You: what is the milky way\nBot: the milky way is our galaxy. it contains hundreds of billions of stars including our sun.",
  "You: can you see planets without a telescope\nBot: yes, you can see mercury, venus, mars, jupiter, and saturn with just your eyes on clear nights.",
  "You: what is a meteor shower\nBot: a meteor shower happens when earth passes through debris left by a comet. the bits burn up in our atmosphere.",
  "You: what is dark matter\nBot: dark matter is invisible material in space that has gravity. scientists know it exists but cannot see it directly.",
]

space_exploration.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== Additional: Growth Mindset (Advanced) ========================

growth_mindset = [
  "you do not have to be perfect to be amazing. progress matters more than perfection.",
  "the most successful people in history failed many times before they got it right.",
  "intelligence is not fixed. your brain grows stronger every time you learn something new.",
  "comparing yourself to others only slows you down. focus on your own growth instead.",
  "asking for help is a sign of strength, not weakness. everyone needs support sometimes.",
  "every expert was once a beginner. the key is to keep practicing and never give up.",
  "challenges are opportunities to grow. the things that are hard now will become easier with practice.",
  "your attitude matters more than your aptitude. believing you can improve is the first step.",
  "making mistakes means you are pushing yourself beyond what is comfortable. that is where growth happens.",
  "you do not learn much from success. failure teaches you what to do differently next time.",
  "curiosity is more important than knowing all the answers. keep asking questions and exploring.",
  "the only real failure is giving up. as long as you keep trying, you are making progress.",
  "be patient with yourself. learning takes time and every small step counts.",
  "you are capable of more than you think. push past the doubt and see what happens.",
  "do not let fear of failure stop you from trying. regret hurts more than failure ever could.",
  "celebrate what you have learned, not just what you have achieved. the journey matters.",
]

growth_mindset.each do |msg|
  8.times { segments << check!(msg) }
end

# ======================== Additional: Fun Facts and Trivia ========================

fun_facts = [
  "a day on venus is longer than a year on venus. it rotates very slowly on its axis.",
  "the shortest war in history lasted only 38 to 45 minutes between britain and zanzibar.",
  "a group of flamingos is called a flamboyance.",
  "bananas are actually berries, but strawberries are not.",
  "the longest hiccupping spree lasted 68 years.",
  "there are more stars in the universe than grains of sand on all of earth's beaches.",
  "the eiffel tower can grow taller in summer because metal expands when it gets hot.",
  "an octopus has three hearts and its blood is blue because it contains copper.",
  "a bolt of lightning is five times hotter than the surface of the sun.",
  "the inventor of the pringles can is buried in one.",
  "the average person walks about 100,000 miles in their lifetime, enough to circle the earth four times.",
  "a jiffy is an actual unit of time. it is one hundredth of a second.",
  "the smallest bone in your body is in your ear. it is called the stapes.",
  "venus is the only planet in our solar system that spins clockwise.",
  "your body contains enough iron to make a small nail.",
  "the fingerprints of a koala are so similar to human fingerprints that they can be confused.",
]

fun_facts.each do |fact|
  8.times { segments << check!(fact) }
end

# ======================== Additional: Multi-sentence Explanations ========================

multi_sentence = [
  "the water cycle is how water moves through the environment.\nwater evaporates from the ocean, forms clouds, and falls back as rain or snow.",

  "magnets have a north pole and a south pole.\nopposite poles attract each other and same poles push each other away.",

  "your body has an immune system that fights off germs and infections.\nwhite blood cells are like soldiers that protect you from getting sick.",

  "the food chain shows how energy moves from one living thing to another.\nplants get energy from the sun, animals eat plants, and predators eat those animals.",

  "earthquakes happen when pieces of the earth's crust suddenly shift.\nthe energy released travels as waves that shake the ground and can damage buildings.",

  "the human skeleton has 206 bones that provide structure and protect organs.\nyour bones are living tissue that constantly rebuilds itself throughout your life.",

  "electricity is the flow of tiny particles called electrons through a conductor like wire.\nwe use it every day for lights, computers, and almost everything in modern life.",

  "the solar system has eight planets that orbit the sun.\nthe inner planets are rocky and the outer planets are mostly made of gas.",

  "dna is a molecule inside every cell that carries the instructions for life.\nit determines things like your eye color, hair color, and many other traits.",

  "photosynthesis is the process plants use to convert sunlight into food.\nthey take in carbon dioxide and water and release oxygen as a byproduct.",

  "the layers of the earth include the crust, mantle, and core.\nthe core is incredibly hot, about as hot as the surface of the sun.",

  "sound is a vibration that travels through air, water, or solid materials.\nit moves faster through solids because the particles are closer together.",

  "the brain is the most complex organ in the human body.\nit controls everything from breathing and heartbeat to thoughts, memories, and emotions.",

  "ocean currents are like rivers flowing through the sea.\nthey help distribute heat around the planet and affect weather patterns everywhere.",

  "fossils tell us about life that existed millions of years ago.\nscientists study them to understand how living things have changed over time.",

  "black holes form when massive stars collapse at the end of their lives.\ntheir gravity is so strong that not even light can escape from them.",
]

multi_sentence.each do |passage|
  6.times { segments << check!(passage) }
end

# ======================== Additional: Human Body Deep Dive ========================

body_deep = [
  "You: how does the brain send messages\nBot: your brain sends electrical signals through nerve cells called neurons at speeds up to 270 miles per hour.",
  "You: why does my stomach growl\nBot: your stomach muscles squeeze to move food along. when it is empty, the squeezing moves air and makes noise.",
  "You: how do cuts heal\nBot: your blood forms a clot to stop bleeding. then new skin cells grow underneath to repair the damage.",
  "You: why do we get fevers\nBot: a fever is your body raising its temperature to fight off germs. most bacteria and viruses struggle in heat.",
  "You: how many muscles does the human body have\nBot: the human body has over 600 muscles. they work together to help you move, breathe, and even digest food.",
  "You: why do we shiver when cold\nBot: shivering is your muscles contracting rapidly to generate heat and warm your body up.",
  "You: what happens when we sneeze\nBot: a sneeze forces air out of your nose at up to 100 miles per hour to clear out irritants.",
  "You: why do our fingers wrinkle in water\nBot: scientists think it helps you grip wet objects better. it is controlled by your nervous system.",
  "You: what is the largest organ in the body\nBot: your skin is the largest organ. it covers about 20 square feet and protects everything inside.",
  "You: how fast does blood travel\nBot: blood travels through your body at about 3 miles per hour and makes a full circuit in about one minute.",
  "You: why do we yawn\nBot: scientists are not completely sure, but it may help cool down the brain or increase alertness.",
  "You: how does memory work\nBot: your brain stores memories by strengthening connections between neurons. repetition makes these connections stronger.",
  "You: why does exercise make you feel good\nBot: exercise releases chemicals called endorphins in your brain that reduce pain and boost your mood.",
  "You: what are reflexes\nBot: reflexes are automatic responses your body makes without thinking, like pulling your hand from something hot.",
  "You: how do taste buds work\nBot: taste buds have receptors that detect five flavors: sweet, salty, sour, bitter, and savory called umami.",
  "You: why do we blink\nBot: blinking keeps your eyes moist and clean. you blink about 15 to 20 times every minute without thinking about it.",
]

body_deep.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== Additional: Animals and Biology ========================

animals_bio = [
  "whales are the largest animals ever to live on earth. a blue whale's heart is the size of a small car.",
  "migration is a long journey animals make, often thousands of miles, to find food or breeding grounds.",
  "some animals use camouflage to blend in with their surroundings and hide from predators.",
  "dolphins use echolocation to find food. they send out clicks and listen for the echo that bounces back.",
  "ants live in colonies with different jobs. there are workers, soldiers, and a queen who lays eggs.",
  "a chameleon can move its eyes independently, looking in two different directions at the same time.",
  "sea turtles return to the same beach where they were born to lay their own eggs.",
  "elephants are highly intelligent. they mourn their dead, use tools, and have excellent memories.",
  "a woodpecker's skull has special padding that absorbs the shock of pecking at trees all day.",
  "the arctic fox changes color with the seasons, white in winter and brown in summer.",
  "salmon swim upstream against the current to return to the river where they were born to spawn.",
  "fireflies produce light through a chemical reaction in their bodies. it is called bioluminescence.",
  "wolves communicate through howling, body language, and scent marking in their territory.",
  "the mantis shrimp can punch so fast that it creates a shockwave in the water.",
  "honey bees perform a special dance to tell other bees where to find flowers with nectar.",
  "a group of wolves is called a pack, a group of fish is a school, and a group of crows is a murder.",
  "the platypus is one of only five species of mammals that lay eggs instead of giving live birth.",
  "geckos can walk on walls and ceilings because their feet have millions of tiny hairs that grip surfaces.",
  "crows are one of the smartest birds. they can use tools, solve puzzles, and even recognize human faces.",
  "some deep sea fish produce their own light to attract prey in the pitch black ocean depths.",
]

animals_bio.each do |fact|
  8.times { segments << check!(fact) }
end

# ======================== Additional: Earth Science ========================

earth_science = [
  "the earth is about 4.5 billion years old. scientists figured this out by studying rocks and meteorites.",
  "the core of the earth is mostly made of iron and nickel and is as hot as the surface of the sun.",
  "plate tectonics explains how continents move. south america and africa once fit together like puzzle pieces.",
  "geysers like old faithful shoot hot water into the air when underground water is heated by magma.",
  "glaciers are massive rivers of ice that move slowly and carve out valleys and lakes over thousands of years.",
  "stalactites grow down from cave ceilings and stalagmites grow up from cave floors over thousands of years.",
  "the ring of fire is an area around the pacific ocean where most of the world's earthquakes and volcanoes occur.",
  "the mariana trench is the deepest part of the ocean at about 36,000 feet below the surface.",
  "soil is made of broken down rocks, dead plants and animals, water, and air.",
  "the water table is the level below which the ground is completely saturated with water.",
  "limestone caves form when slightly acidic water dissolves the rock over millions of years.",
  "the ozone layer in the atmosphere protects us from the sun's harmful ultraviolet radiation.",
  "tsunamis are giant ocean waves usually caused by underwater earthquakes or volcanic eruptions.",
  "the seasons are caused by the earth's tilt, not by how close we are to the sun.",
  "the rock cycle shows how rocks change from one type to another through heat, pressure, and erosion.",
  "mineral crystals form underground when hot liquids cool slowly, allowing atoms to arrange in patterns.",
]

earth_science.each do |fact|
  8.times { segments << check!(fact) }
end

# ======================== Additional: Inventions and Discoveries ========================

inventions = [
  "the microscope was invented around 1590 and allowed scientists to see things too small for the naked eye.",
  "the telescope was improved by galileo in 1609, letting him observe the moon, planets, and stars in detail.",
  "penicillin was discovered by alexander fleming in 1928. it was the first antibiotic and saved millions of lives.",
  "the steam engine powered the industrial revolution and changed transportation and manufacturing forever.",
  "the airplane was invented by the wright brothers in 1903, making human flight a reality for the first time.",
  "the vaccine was developed by edward jenner in 1796 to protect people from smallpox.",
  "the discovery of electricity by scientists like benjamin franklin and michael faraday changed the world.",
  "the internet started as a military project in the 1960s and became public in the 1990s.",
  "x-rays were discovered by wilhelm roentgen in 1895, allowing doctors to see inside the human body.",
  "the compass was invented in ancient china and helped sailors navigate the open seas.",
  "the refrigerator became common in homes in the 1920s and changed how people stored and preserved food.",
  "the phonograph, invented by thomas edison in 1877, was the first device that could record and play back sound.",
  "the television became popular in the 1950s and changed entertainment, news, and culture forever.",
  "dynamite was invented by alfred nobel in 1867. he later created the nobel prizes with his fortune.",
  "the first successful heart transplant was performed by christiaan barnard in 1967.",
  "the barcode was invented in 1951 and is now used on almost every product sold in stores.",
]

inventions.each do |fact|
  8.times { segments << check!(fact) }
end

# ======================== Additional: Study Skills and Learning ========================

study_learning = [
  "You: how can i remember things better\nBot: try connecting new information to something you already know. associations help your brain remember.",
  "You: what is the best way to study for a test\nBot: spread your studying over several days instead of cramming. review a little bit each day.",
  "You: how do i stay focused when studying\nBot: remove distractions, set a timer for 25 minutes of focused work, then take a short break.",
  "You: why do i forget things i just studied\nBot: your brain needs time to process information. reviewing the material again the next day helps a lot.",
  "You: is it better to study alone or in a group\nBot: both can work. study alone for focus and in groups to discuss ideas and quiz each other.",
  "You: how can i take better notes\nBot: write key ideas in your own words instead of copying everything. use headings and bullet points.",
  "You: what should i do if i do not understand something\nBot: ask your teacher, look it up online, or try explaining it to yourself in simpler words.",
  "You: how do i manage my time for homework\nBot: make a schedule, do the hardest work first when your brain is fresh, and take short breaks.",
  "You: does music help you study\nBot: quiet background music without lyrics can help some people focus, but it depends on the person.",
  "You: how can i stop procrastinating\nBot: start with the smallest possible step. once you begin, it is much easier to keep going.",
  "You: what is the pomodoro technique\nBot: you study for 25 minutes then take a 5 minute break. after four rounds you take a longer break.",
  "You: how can i read faster\nBot: practice reading regularly, do not read word by word, and try to understand whole phrases at once.",
  "You: should i highlight my textbook\nBot: highlighting alone is not very effective. try writing summaries or making flashcards from what you read.",
  "You: why is sleep important for learning\nBot: while you sleep your brain consolidates memories and processes what you learned during the day.",
  "You: how do i prepare for a presentation\nBot: practice out loud several times. know your material well so you do not need to read from notes.",
  "You: what if i have test anxiety\nBot: prepare well in advance, practice deep breathing, and remind yourself that one test is not everything.",
]

study_learning.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== Additional: Philosophy and Ethics for Kids ========================

philosophy_ethics = [
  "You: what is justice\nBot: justice means treating people fairly and making sure the rules apply equally to everyone.",
  "You: why do rules exist\nBot: rules help everyone live together peacefully. without them, people might hurt each other more often.",
  "You: is there such a thing as a white lie\nBot: a white lie is a small lie told to avoid hurting someone. people disagree about whether they are okay.",
  "You: what does responsibility mean\nBot: responsibility means being accountable for your actions and doing what you said you would do.",
  "You: is it important to keep promises\nBot: yes, keeping promises builds trust. if you cannot keep a promise, let the person know honestly.",
  "You: what is freedom\nBot: freedom is the ability to make your own choices, but it also comes with responsibility toward others.",
  "You: what is the golden rule\nBot: treat others the way you want to be treated. it is a principle found in many cultures around the world.",
  "You: why should we help others\nBot: helping others makes the world better and it also makes you feel good. kindness creates more kindness.",
  "You: what does integrity mean\nBot: integrity means doing the right thing even when nobody is watching.",
  "You: is it okay to change your mind\nBot: absolutely. changing your mind when you learn new information is a sign of wisdom, not weakness.",
  "You: what is courage\nBot: courage is doing something you believe is right even when you feel scared or uncertain.",
  "You: why is honesty important\nBot: honesty builds trust between people. once trust is broken, it is very hard to rebuild.",
  "You: what does compassion mean\nBot: compassion is feeling concern for others who are suffering and wanting to help them.",
  "You: is it wrong to be selfish sometimes\nBot: taking care of your own needs is healthy. but ignoring others to benefit only yourself is not.",
  "You: what is tolerance\nBot: tolerance means accepting and respecting people who are different from you, even if you disagree.",
  "You: why is education important\nBot: education gives you the tools to think for yourself, solve problems, and create a better future.",
]

philosophy_ethics.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== Additional: Nature Observations ========================

nature_observations = [
  "the sky turns shades of orange and pink at sunset because light travels through more atmosphere.",
  "dew forms on grass in the morning when moisture in the air condenses as temperatures drop overnight.",
  "the aurora borealis, or northern lights, happen when charged particles from the sun hit our atmosphere.",
  "tides rise and fall twice each day because of the gravitational pull of the moon and sun.",
  "tree rings can tell you how old a tree is. each ring represents one year of growth.",
  "spider webs are made of silk that is stronger than steel of the same thickness.",
  "the smell of rain on dry ground is called petrichor. it comes from oils released by plants and bacteria.",
  "honey bees visit about two million flowers to make just one pound of honey.",
  "some plants can move. the venus flytrap snaps shut when an insect touches its trigger hairs.",
  "the tallest trees in the world are coast redwoods in california, reaching over 350 feet.",
  "mushrooms are not plants. they belong to a separate group of organisms called fungi.",
  "owls cannot move their eyes in their sockets, so they rotate their heads up to 270 degrees.",
  "salmon use their sense of smell to find the exact river where they were born.",
  "the giant sequoia is the largest tree by volume. some are over 2,000 years old.",
  "hummingbirds can fly backward and their wings beat up to 80 times per second.",
  "many flowers close at night to protect their pollen and open again when the sun comes out.",
  "earthworms are important for soil health. they break down organic matter and aerate the ground.",
  "monarch butterflies migrate up to 3,000 miles from canada to mexico every fall.",
  "coral bleaching happens when water temperatures rise and corals expel the algae that give them color.",
  "the oldest known living tree is a bristlecone pine in california that is over 4,800 years old.",
]

nature_observations.each do |fact|
  8.times { segments << check!(fact) }
end

# ======================== Additional: Everyday Conversations ========================

everyday_convos = [
  "You: what should i eat for breakfast\nBot: something with protein like eggs or yogurt gives you energy. add fruit for vitamins.",
  "You: how does a microwave heat food\nBot: microwaves make water molecules in food vibrate very fast. the vibration creates heat.",
  "You: why do we need to brush our teeth\nBot: brushing removes bacteria that cause cavities and gum disease. doing it twice a day is important.",
  "You: how do glasses help you see\nBot: glasses have lenses that bend light so it focuses correctly on the back of your eye.",
  "You: why do we get sunburned\nBot: ultraviolet rays from the sun damage skin cells. sunscreen blocks these rays and protects you.",
  "You: how does soap clean things\nBot: soap molecules have one end that grabs dirt and oil and another end that sticks to water.",
  "You: why does ice cream melt\nBot: when ice cream absorbs heat from the air it warms up and changes from a solid back to a liquid.",
  "You: how do planes stay in the air\nBot: the shape of the wings creates lift. air moves faster over the top creating lower pressure that holds it up.",
  "You: why do we get thirsty\nBot: your body monitors water levels. when you lose water through sweat and breathing your brain tells you to drink.",
  "You: how do traffic lights work\nBot: they use timers and sensors to control the flow of cars and keep intersections safe.",
  "You: why is the sky blue\nBot: sunlight contains all colors. blue light scatters more in the atmosphere because it travels in shorter waves.",
  "You: what makes popcorn pop\nBot: each kernel has a tiny amount of water inside. when heated the water turns to steam and the kernel explodes.",
  "You: how do elevators work\nBot: most elevators use a motor and cable system with a counterweight to lift and lower the cab safely.",
  "You: why do leaves fall off trees\nBot: deciduous trees drop their leaves in fall to conserve water and energy during the cold winter months.",
  "You: how do bridges hold up so much weight\nBot: engineers design bridges to spread weight across supports. arches and cables help distribute the forces.",
  "You: why does metal feel colder than wood\nBot: metal conducts heat away from your hand faster than wood does, so it feels colder even at the same temperature.",
]

everyday_convos.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== Additional: Moral Dilemmas and Thinking ========================

moral_thinking = [
  "You: is it okay to tell on someone who is cheating\nBot: if cheating is hurting others or is unfair, speaking up is the right thing to do.",
  "You: should you always follow the rules\nBot: most rules exist for good reasons, but thinking about why a rule exists helps you understand it better.",
  "You: what if doing the right thing is unpopular\nBot: doing the right thing can be hard when others disagree, but integrity means standing by your values.",
  "You: is it wrong to eat meat\nBot: people have different views on this. some choose not to for ethical or environmental reasons. it is personal.",
  "You: should rich people help poor people\nBot: many people believe those with more should help those with less because it makes society better for everyone.",
  "You: is it okay to keep a secret\nBot: it depends on the secret. if someone could get hurt, it is important to tell a trusted adult.",
  "You: why is it wrong to steal\nBot: stealing takes something that belongs to someone else. it hurts them and breaks the trust in a community.",
  "You: should everyone be treated equally\nBot: everyone deserves equal respect and rights, but sometimes people need different support to have equal opportunities.",
  "You: is it better to be honest or polite\nBot: you can usually be both. honest feedback given kindly is more helpful than a hurtful truth or a nice lie.",
  "You: what would you do if you found money on the ground\nBot: i would try to find the owner. if i could not, i might donate it or turn it in to lost and found.",
  "You: should animals be kept in zoos\nBot: zoos help protect endangered species and educate people, but animals deserve the best possible living conditions.",
  "You: is social media good or bad\nBot: it can connect people and spread ideas, but it can also spread misinformation and affect mental health.",
  "You: why should we care about people in other countries\nBot: we are all part of one world. helping each other across borders makes the whole planet better.",
  "You: is failure a bad thing\nBot: failure is only bad if you do not learn from it. most great achievements came after many failures.",
  "You: should homework be banned\nBot: some homework reinforces learning but too much causes stress. the right amount depends on the student.",
  "You: is it important to vote\nBot: voting is how citizens influence their government. every vote matters and helps shape the future.",
]

moral_thinking.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== Additional: More Prose Passages ========================

more_prose = [
  "the human race has always been curious about what lies beyond the horizon.\nexploration has taken us from the depths of the ocean to the surface of the moon.",

  "music can change your mood in an instant.\na fast beat can make you want to dance while a slow melody can bring you to tears.",

  "the ability to read and write is one of the most powerful skills a person can have.\nit opens doors to knowledge, opportunity, and understanding across time and cultures.",

  "sleep is not just rest. it is an active process where your brain sorts through the day.\nmemories are strengthened, emotions are processed, and your body repairs itself.",

  "the domestication of animals changed human civilization.\ndogs helped with hunting, horses with transportation, and cows with farming.",

  "the night sky has inspired humans for thousands of years.\nancient sailors navigated by the stars and cultures created myths about the constellations.",

  "every living thing on earth is connected through ecosystems.\nwhen one species disappears it can affect many others in unexpected ways.",

  "the ocean floor is as varied as any landscape on land.\nthere are mountains taller than everest, valleys deeper than the grand canyon, and vast flat plains.",

  "cooking food was a turning point in human evolution.\nheat breaks down nutrients making them easier to digest and gave early humans more energy for brain growth.",

  "the scientific method is a way of learning about the world through observation and experiment.\nit starts with a question, forms a hypothesis, tests it, and draws conclusions from the results.",

  "maps have changed how we understand the world.\nfrom ancient hand drawn charts to modern satellite images, they help us navigate and see our place on earth.",

  "the development of agriculture about 10,000 years ago changed everything for humans.\ninstead of wandering to find food, people could settle in one place and build communities.",

  "coral reefs are often called the rainforests of the sea because of their incredible biodiversity.\nthey cover less than one percent of the ocean floor but support about 25 percent of marine species.",

  "the periodic table organizes all known elements by their properties.\nit was created by dmitri mendeleev in 1869 and has been expanded as new elements were discovered.",

  "democracy was born in ancient athens where citizens could vote directly on laws.\ntoday most democracies are representative, meaning people vote for leaders who make decisions for them.",

  "the human hand is one of the most remarkable tools in nature.\nits combination of strength, flexibility, and precision grip helped humans build civilizations.",

  "clouds come in many shapes and sizes that can help predict the weather.\nflat gray clouds often bring rain while tall puffy clouds can signal thunderstorms.",

  "storytelling is one of the oldest human traditions.\nlong before writing was invented, people passed down knowledge and history through spoken stories.",

  "the discovery of fire was one of the most important moments in human history.\nit provided warmth, protection, a way to cook food, and light in the darkness.",

  "friendship is one of the most valuable things in life.\ngood friends support you, challenge you to be better, and make the hard times easier to bear.",
]

more_prose.each do |passage|
  6.times { segments << check!(passage) }
end

# ======================== Additional: Mixed Quick Q&A ========================

quick_qa = [
  "You: how many bones do humans have\nBot: adults have 206 bones. babies are born with about 270 that fuse together as they grow.",
  "You: what is the biggest animal ever\nBot: the blue whale is the biggest animal that has ever lived, even bigger than the largest dinosaurs.",
  "You: how old is the earth\nBot: the earth is about 4.5 billion years old. scientists figured this out by dating ancient rocks.",
  "You: what is the fastest animal\nBot: the peregrine falcon is the fastest animal. it can dive through the air at over 240 miles per hour.",
  "You: how many countries are there\nBot: there are about 195 countries in the world, though the exact number depends on how you count them.",
  "You: what is the longest river\nBot: the nile river in africa and the amazon river in south america compete for the title at over 4,000 miles.",
  "You: what is the smallest country\nBot: vatican city is the smallest country in the world. it is only about 0.17 square miles.",
  "You: how hot is the sun\nBot: the surface of the sun is about 10,000 degrees fahrenheit. the core is about 27 million degrees.",
  "You: what is the hardest natural substance\nBot: diamond is the hardest natural substance on earth. it is made of carbon atoms arranged in a crystal.",
  "You: how deep is the ocean\nBot: the deepest point is the mariana trench at about 36,000 feet. that is almost 7 miles deep.",
  "You: what percentage of earth is water\nBot: about 71 percent of the earth's surface is covered by water, but most of it is salt water.",
  "You: how many teeth do humans have\nBot: adults have 32 teeth including wisdom teeth. children have 20 baby teeth that fall out.",
  "You: what is the speed of sound\nBot: sound travels at about 767 miles per hour through air at sea level. it is much slower than light.",
  "You: what is the largest desert\nBot: antarctica is actually the largest desert because a desert is defined by low precipitation, not heat.",
  "You: what causes a rainbow\nBot: rainbows form when sunlight enters raindrops and splits into its different colors like a prism.",
  "You: how many species are there on earth\nBot: scientists estimate there are about 8.7 million species on earth, but many have not been discovered yet.",
  "You: what is the tallest building in the world\nBot: the burj khalifa in dubai is the tallest building at over 2,700 feet. it has 163 floors.",
  "You: how far is the sun from earth\nBot: the sun is about 93 million miles from earth. light from the sun takes about 8 minutes to reach us.",
  "You: what is the most spoken language\nBot: mandarin chinese has the most native speakers, but english is the most widely spoken language overall.",
  "You: how long can humans hold their breath\nBot: most people can hold their breath for about one to two minutes. trained divers can go much longer.",
]

quick_qa.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== Additional: Sports and Games ========================

sports_games = [
  "the olympic games started in ancient greece almost 3,000 years ago as a celebration of athletic skill.",
  "soccer is the most popular sport in the world. it is called football in most countries outside the united states.",
  "basketball was invented by james naismith in 1891. he used a peach basket as the first hoop.",
  "chess is one of the oldest strategy games. it originated in india over 1,500 years ago.",
  "the world cup is the biggest soccer tournament. it is held every four years and billions of people watch it.",
  "swimming is a great exercise because it works almost every muscle in your body without stressing your joints.",
  "sportsmanship means playing fair, respecting your opponents, and accepting both winning and losing gracefully.",
  "teamwork in sports teaches communication, cooperation, and how to work toward a shared goal.",
  "the marathon is a 26.2 mile race named after an ancient greek messenger who ran a long distance.",
  "table tennis, also called ping pong, is one of the fastest racket sports in the world.",
  "yoga is an ancient practice that improves flexibility, strength, and mental focus through poses and breathing.",
  "the first video game, pong, was created in 1972. now the gaming industry is larger than movies and music combined.",
  "rock climbing builds strength and problem solving skills as you figure out the best path upward.",
  "martial arts like karate, judo, and taekwondo teach discipline, respect, and self defense.",
  "running is one of the simplest forms of exercise. all you need is a pair of shoes and some space.",
  "playing sports regularly helps reduce stress, improve mood, and build confidence.",
]

sports_games.each do |fact|
  8.times { segments << check!(fact) }
end

# ======================== Additional: Famous Scientists and Thinkers ========================

famous_people = [
  "You: who was albert einstein\nBot: einstein was a physicist who developed the theory of relativity and changed our understanding of space and time.",
  "You: who was isaac newton\nBot: newton discovered the laws of gravity and motion. he also made important contributions to mathematics.",
  "You: who was jane goodall\nBot: jane goodall studied chimpanzees in africa for decades and showed the world how similar they are to humans.",
  "You: who was ada lovelace\nBot: ada lovelace wrote the first computer program in the 1840s, long before modern computers existed.",
  "You: who was nikola tesla\nBot: tesla was an inventor who developed alternating current electricity, which powers most of the world today.",
  "You: who was frida kahlo\nBot: frida kahlo was a mexican artist known for her colorful self portraits that expressed pain and identity.",
  "You: who was pythagoras\nBot: pythagoras was a greek mathematician famous for the theorem about right triangles that bears his name.",
  "You: who was harriet tubman\nBot: harriet tubman escaped slavery and then risked her life to help hundreds of others escape through the underground railroad.",
  "You: who was amelia earhart\nBot: amelia earhart was the first woman to fly solo across the atlantic ocean in 1932.",
  "You: who was aristotle\nBot: aristotle was an ancient greek philosopher who studied science, logic, politics, and many other subjects.",
  "You: who was katherine johnson\nBot: katherine johnson was a mathematician whose calculations helped NASA send astronauts to the moon.",
  "You: who was william shakespeare\nBot: shakespeare was an english playwright and poet. he wrote famous works like romeo and juliet and hamlet.",
  "You: who was genghis khan\nBot: genghis khan united the mongol tribes and built one of the largest empires in history.",
  "You: who was helen keller\nBot: helen keller was deaf and blind but became a famous author, speaker, and advocate for people with disabilities.",
  "You: who was louis pasteur\nBot: pasteur was a french scientist who proved that germs cause disease and developed the process of pasteurization.",
  "You: who was malala yousafzai\nBot: malala is a pakistani activist who stood up for girls' education and became the youngest nobel prize winner.",
]

famous_people.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== Additional: Weather and Climate Conversations ========================

weather_climate = [
  "You: what is the difference between weather and climate\nBot: weather is what happens day to day. climate is the average weather in a place over many years.",
  "You: why does it rain more in some places\nBot: geography plays a big role. mountains can force air up, cooling it and causing more rain on one side.",
  "You: what is a drought\nBot: a drought is a long period with very little rain. it can damage crops, dry up rivers, and cause water shortages.",
  "You: how do meteorologists predict weather\nBot: they use satellites, weather stations, and computer models to analyze patterns in the atmosphere.",
  "You: what is a blizzard\nBot: a blizzard is a severe snowstorm with strong winds over 35 miles per hour and low visibility.",
  "You: why is it colder at higher altitudes\nBot: air pressure decreases as you go up, which causes the air to expand and cool down.",
  "You: what causes hail\nBot: strong updrafts in thunderstorms carry raindrops high up where they freeze. they grow bigger as more ice forms.",
  "You: what is el nino\nBot: el nino is a pattern of warm ocean temperatures in the pacific that affects weather all around the world.",
  "You: why do clouds float\nBot: cloud droplets are so tiny and light that the rising air beneath them keeps them suspended in the sky.",
  "You: what is humidity\nBot: humidity is the amount of water vapor in the air. high humidity makes hot days feel even hotter.",
  "You: how do tornadoes form\nBot: tornadoes form when warm moist air meets cold dry air, creating a spinning column of wind.",
  "You: what is the jet stream\nBot: the jet stream is a fast flowing river of air high in the atmosphere that influences weather patterns below.",
  "You: why does fog happen\nBot: fog forms when air near the ground cools enough for water vapor to condense into tiny visible droplets.",
  "You: what is a monsoon\nBot: a monsoon is a seasonal wind shift that brings heavy rains to parts of asia and other tropical regions.",
  "You: can lightning strike the same place twice\nBot: yes it can. tall buildings like the empire state building get struck by lightning dozens of times a year.",
  "You: what is acid rain\nBot: acid rain forms when pollution from burning fossil fuels mixes with water vapor in the atmosphere.",
]

weather_climate.each do |conv|
  7.times { segments << check!(conv) }
end

# ======================== Additional: More Everyday Facts ========================

more_everyday = [
  "the average person spends about 26 years of their life sleeping.",
  "the human eye can distinguish about 10 million different colors.",
  "your fingernails grow about 3.5 millimeters per month, faster than your toenails.",
  "a single strand of hair can support about 100 grams of weight.",
  "the average person takes about 20,000 breaths per day without even thinking about it.",
  "your body produces about 1 to 1.5 liters of saliva every day.",
  "the strongest muscle in the human body, relative to its size, is the masseter or jaw muscle.",
  "it takes about 8 minutes for sunlight to travel from the sun to earth.",
  "the average human heart will beat about 2.5 billion times in a lifetime.",
  "you share about 50 percent of your DNA with bananas and about 60 percent with fruit flies.",
  "the great pacific garbage patch is a collection of marine debris in the pacific twice the size of texas.",
  "one lightning bolt has enough energy to toast about 100,000 slices of bread.",
  "the deepest hole ever dug by humans is in russia and goes down about 7.6 miles.",
  "a cloud can weigh more than a million pounds but stays in the sky because the air below is even denser.",
  "the earth travels through space at about 67,000 miles per hour as it orbits the sun.",
  "there are more bacteria in your mouth right now than there are people on earth.",
]

more_everyday.each do |fact|
  8.times { segments << check!(fact) }
end

# ======================== Shuffle and Write ========================

segments.shuffle!

out_path = File.join(__dir__, 'tier4.txt')
File.write(out_path, segments.join("\n"))

# Verify line lengths
lines = File.readlines(out_path).map(&:chomp)
max_len = lines.map(&:length).max
long_lines = lines.select { |l| l.length > 128 }

puts "=== Tier 4 Training Data Stats ==="
puts "Segments: #{segments.length}"
puts "Lines: #{lines.length}"
puts "File size: #{File.size(out_path)} bytes (#{(File.size(out_path) / 1024.0).round(1)} KB)"
puts "Max line length: #{max_len}"
puts "Lines over 128 chars: #{long_lines.length}"

if long_lines.any?
  puts "\nERROR: Lines exceeding 128 chars found!"
  long_lines.first(10).each { |l| puts "  [#{l.length}] #{l}" }
else
  puts "\nAll lines are 128 chars or fewer. OK!"
end

puts "\nSample segments:"
segments.first(8).each_with_index do |s, i|
  puts "  #{i + 1}. #{s.split("\n").first}"
end
