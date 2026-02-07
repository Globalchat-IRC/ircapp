class EmojiService {
  static const String cdnBaseUrl = 'https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/';
  // Emojis animados (Noto Emoji Animation / Noto Emoji de Google)
  // - Local (preferido): assets/emoji_animated_noto/{codepoint}.gif
  // - Fallback CDN: https://fonts.gstatic.com/s/e/notoemoji/latest/{codepoint}/512.gif
  static const String animatedCdnBaseUrl = 'https://fonts.gstatic.com/s/e/notoemoji/latest/';
  static const String animatedAssetBasePath = 'assets/emoji_animated_noto/';
  static const String notoLatestBaseUrl = 'https://fonts.gstatic.com/s/e/notoemoji/latest/';
  
  // Mapa de emoticonos animados (GIFs) generado desde
  // https://googlefonts.github.io/noto-emoji-animation/data/api.json
  // Clave: código estilo :nombre: que se usará en el chat/picker
  // Valor: codepoint de Noto (carpeta/archivo GIF).
  static final Map<String, String> animatedEmojiMap = {
    ':smile:': '1f600',
    ':smile_with_big_eyes:': '1f603',
    ':grin:': '1f604',
    ':grinning:': '1f601',
    ':laughing:': '1f606',
    ':grin_sweat:': '1f605',
    ':joy:': '1f602',
    ':rofl:': '1f923',
    ':loudly_crying:': '1f62d',
    ':wink:': '1f609',
    ':kissing:': '1f617',
    ':kissing_smiling_eyes:': '1f619',
    ':kissing_closed_eyes:': '1f61a',
    ':kissing_heart:': '1f618',
    ':three_hearts:': '1f970',
    ':heart_face:': '1f970',
    ':heart_eyes:': '1f60d',
    ':star_struck:': '1f929',
    ':partying_face:': '1f973',
    ':melting:': '1fae0',
    ':upside_down_face:': '1f643',
    ':slightly_happy:': '1f642',
    ':happy_cry:': '1f972',
    ':holding_back_tears:': '1f979',
    ':blush:': '1f60a',
    ':warm_smile:': '263a_fe0f',
    ':relieved:': '1f60c',
    ':head_nod:': '1f642_200d_2195_fe0f',
    ':head_shake:': '1f642_200d_2194_fe0f',
    ':smirk:': '1f60f',
    ':drool:': '1f924',
    ':yum:': '1f60b',
    ':stuck_out_tongue:': '1f61b',
    ':squinting_tongue:': '1f61d',
    ':winky_tongue:': '1f61c',
    ':zany_face:': '1f92a',
    ':woozy:': '1f974',
    ':pensive:': '1f614',
    ':pleading:': '1f97a',
    ':grimacing:': '1f62c',
    ':expressionless:': '1f611',
    ':neutral_face:': '1f610',
    ':mouth_none:': '1f636',
    ':face_in_clouds:': '1f636_200d_1f32b_fe0f',
    ':lost:': '1f636_200d_1f32b_fe0f',
    ':dotted_line_face:': '1fae5',
    ':invisible:': '1fae5',
    ':zipper_face:': '1f910',
    ':salute:': '1fae1',
    ':thinking_face:': '1f914',
    ':shushing_face:': '1f92b',
    ':hand_over_mouth:': '1fae2',
    ':chuckling:': '1f92d',
    ':smiling_eyes_with_hand_over_mouth:': '1f92d',
    ':yawn:': '1f971',
    ':hug_face:': '1f917',
    ':peeking:': '1fae3',
    ':screaming:': '1f631',
    ':raised_eyebrow:': '1f928',
    ':monocle:': '1f9d0',
    ':unamused:': '1f612',
    ':rolling_eyes:': '1f644',
    ':exhale:': '1f62e_200d_1f4a8',
    ':triumph:': '1f624',
    ':angry:': '1f620',
    ':rage:': '1f621',
    ':cursing:': '1f92c',
    ':sad:': '1f61e',
    ':downcast:': '1f613',
    ':sweat:': '1f613',
    ':worried:': '1f61f',
    ':concerned:': '1f625',
    ':cry:': '1f622',
    ':big_frown:': '2639_fe0f',
    ':frown:': '1f641',
    ':diagonal_mouth:': '1fae4',
    ':slightly_frowning:': '1f615',
    ':anxious_with_sweat:': '1f630',
    ':scared:': '1f628',
    ':anguished:': '1f627',
    ':gasp:': '1f626',
    ':mouth_open:': '1f62e',
    ':hushed:': '1f62f',
    ':surprised:': '1f62f',
    ':astonished:': '1f632',
    ':flushed:': '1f633',
    ':exploding_head:': '1f92f',
    ':mind_blown:': '1f92f',
    ':confounded:': '1f616',
    ':scrunched_mouth:': '1f616',
    ':zigzag_mouth:': '1f616',
    ':persevering:': '1f623',
    ':scrunched_eyes:': '1f623',
    ':weary:': '1f629',
    ':distraught:': '1f62b',
    ':x_eyes:': '1f635',
    ':dizzy_face:': '1f635_200d_1f4ab',
    ':shaking_face:': '1fae8',
    ':cold_face:': '1f976',
    ':hot_face:': '1f975',
    ':sweat_face:': '1f975',
    ':nauseated:': '1f922',
    ':sick:': '1f922',
    ':vomit:': '1f92e',
    ':bags_under_eyes:': '1fae9',
    ':tired:': '1fae9',
    ':sleep:': '1f634',
    ':sleepy:': '1f62a',
    ':sneeze:': '1f927',
    ':thermometer_face:': '1f912',
    ':bandage_face:': '1f915',
    ':mask:': '1f637',
    ':liar:': '1f925',
    ':halo:': '1f607',
    ':innocent:': '1f607',
    ':cowboy:': '1f920',
    ':money_face:': '1f911',
    ':nerd_face:': '1f913',
    ':sunglasses_face:': '1f60e',
    ':disguise:': '1f978',
    ':clown:': '1f921',
    ':poop:': '1f4a9',
    ':imp_smile:': '1f608',
    ':imp_frown:': '1f47f',
    ':ghost:': '1f47b',
    ':skull:': '1f480',
    ':snowman_with_snow:': '2603_fe0f',
    ':snowman:': '26c4',
    ':jack_o_lantern:': '1f383',
    ':robot:': '1f916',
    ':alien:': '1f47d',
    ':alien_monster:': '1f47e',
    ':sun_with_face:': '1f31e',
    ':moon_face_first_quarter:': '1f31b',
    ':moon_face_last_quarter:': '1f31c',
    ':smiley_cat:': '1f63a',
    ':smile_cat:': '1f638',
    ':joy_cat:': '1f639',
    ':heart_eyes_cat:': '1f63b',
    ':smirk_cat:': '1f63c',
    ':kissing_cat:': '1f63d',
    ':scream_cat:': '1f640',
    ':crying_cat_face:': '1f63f',
    ':pouting_cat:': '1f63e',
    ':see_no_evil_monkey:': '1f648',
    ':hear_no_evil_monkey:': '1f649',
    ':speak_no_evil_monkey:': '1f64a',
    ':glowing_star:': '1f31f',
    ':sparkles:': '2728',
    ':electricity:': '26a1',
    ':lightning:': '26a1',
    ':zap:': '26a1',
    ':collision:': '1f4a5',
    ':burn:': '1f525',
    ':fire:': '1f525',
    ':lit:': '1f525',
    ':hundred:': '1f4af',
    ':one_hundred:': '1f4af',
    ':points:': '1f4af',
    ':party_popper:': '1f389',
    ':confetti_ball:': '1f38a',
    ':red_heart:': '2764_fe0f',
    ':orange_heart:': '1f9e1',
    ':yellow_heart:': '1f49b',
    ':green_heart:': '1f49a',
    ':light_blue_heart:': '1fa75',
    ':blue_heart:': '1f499',
    ':purple_heart:': '1f49c',
    ':brown_heart:': '1f90e',
    ':black_heart:': '1f5a4',
    ':grey_heart:': '1fa76',
    ':white_heart:': '1f90d',
    ':pink_heart:': '1fa77',
    ':cupid:': '1f498',
    ':gift_heart:': '1f49d',
    ':sparkling_heart:': '1f496',
    ':heart_grow:': '1f497',
    ':beating_heart:': '1f493',
    ':revolving_hearts:': '1f49e',
    ':two_hearts:': '1f495',
    ':love_letter:': '1f48c',
    ':heart_box:': '1f49f',
    ':heart_exclamation_point:': '2763_fe0f',
    ':bandaged_heart:': '2764_fe0f_200d_1fa79',
    ':broken_heart:': '1f494',
    ':fire_heart:': '2764_fe0f_200d_1f525',
    ':kiss:': '1f48b',
    ':footprints:': '1f463',
    ':fingerprint:': '1fac6',
    ':anatomical_heart:': '1fac0',
    ':blood:': '1fa78',
    ':microbe:': '1f9a0',
    ':virus:': '1f9a0',
    ':eyes:': '1f440',
    ':eye:': '1f441_fe0f',
    ':biting_lip:': '1fae6',
    ':nose:': '1f443',
    ':ear:': '1f442',
    ':hearing_aid:': '1f9bb',
    ':foot:': '1f9b6',
    ':leg:': '1f9b5',
    ':leg_mechanical:': '1f9bf',
    ':arm_mechanical:': '1f9be',
    ':bicep:': '1f4aa',
    ':flex:': '1f4aa',
    ':muscle:': '1f4aa',
    ':strong:': '1f4aa',
    ':clap:': '1f44f',
    ':+1:': '1f44d',
    ':thumbs_up:': '1f44d',
    ':thumbs_down:': '1f44e',
    ':heart_hands:': '1faf6',
    ':hooray:': '1f64c',
    ':raising_hands:': '1f64c',
    ':open_hands:': '1f450',
    ':palms_up:': '1f932',
    ':fist_rightwards:': '1f91c',
    ':fist_leftwards:': '1f91b',
    ':raised_fist:': '270a',
    ':bump:': '1f44a',
    ':fist:': '1f44a',
    ':drop:': '1faf3',
    ':palm_down:': '1faf3',
    ':palm_up:': '1faf4',
    ':throw:': '1faf4',
    ':rightwards_hand:': '1faf1',
    ':leftwards_hand:': '1faf2',
    ':push_rightwards:': '1faf8',
    ':push_leftwards:': '1faf7',
    ':wave:': '1f44b',
    ':back_hand:': '1f91a',
    ':palm:': '1f590_fe0f',
    ':raised_hand:': '270b',
    ':prosper:': '1f596',
    ':spock:': '1f596',
    ':vulcan:': '1f596',
    ':love_you_gesture:': '1f91f',
    ':horns:': '1f918',
    ':metal:': '1f918',
    ':peace_hand:': '270c_fe0f',
    ':v:': '270c_fe0f',
    ':victory:': '270c_fe0f',
    ':crossed_fingers:': '1f91e',
    ':finger_heart:': '1faf0',
    ':hand_with_index_finger_and_thumb_crossed:': '1faf0',
    ':snap:': '1faf0',
    ':call_me_hand:': '1f919',
    ':pinched_fingers:': '1f90c',
    ':pinch:': '1f90f',
    ':ok:': '1f44c',
    ':pointing:': '1faf5',
    ':point_right:': '1f449',
    ':point_left:': '1f448',
    ':index_finger:': '261d_fe0f',
    ':point_up:': '1f446',
    ':point_down:': '1f447',
    ':middle_finger:': '1f595',
    ':writing_hand:': '270d_fe0f',
    ':selfie:': '1f933',
    ':folded_hands:': '1f64f',
    ':high_five:': '1f64f',
    ':hope:': '1f64f',
    ':please:': '1f64f',
    ':pray:': '1f64f',
    ':thank_you:': '1f64f',
    ':wish:': '1f64f',
    ':nail_care:': '1f485',
    ':handshake:': '1f91d',
    ':dancer_woman:': '1f483',
    ':bouquet:': '1f490',
    ':flowers:': '1f490',
    ':rose:': '1f339',
    ':wilted_flower:': '1f940',
    ':fallen_leaf:': '1f342',
    ':plant:': '1f331',
    ':seed:': '1f331',
    ':leaves:': '1f343',
    ':four_leaf_clover:': '1f340',
    ':luck:': '1f340',
    ':leafless_tree:': '1fabe',
    ':cold:': '2744_fe0f',
    ':snowflake:': '2744_fe0f',
    ':winter:': '2744_fe0f',
    ':volcano:': '1f30b',
    ':sunrise:': '1f305',
    ':sunrise_over_mountains:': '1f304',
    ':rainbow:': '1f308',
    ':bubbles:': '1fae7',
    ':ocean:': '1f30a',
    ':wind_face:': '1f32c_fe0f',
    ':tornado:': '1f32a_fe0f',
    ':droplet:': '1f4a7',
    ':rain_cloud:': '1f327_fe0f',
    ':cloud_with_lightning:': '1f329_fe0f',
    ':globe_showing_europe_africa:': '1f30d',
    ':globe_showing_americas:': '1f30e',
    ':globe_showing_asia_australia:': '1f30f',
    ':comet:': '2604_fe0f',
    ':cow_face:': '1f42e',
    ':unicorn:': '1f984',
    ':lizard:': '1f98e',
    ':dragon:': '1f409',
    ':t_rex:': '1f996',
    ':dinosaur:': '1f995',
    ':turtle:': '1f422',
    ':crocodile:': '1f40a',
    ':snake:': '1f40d',
    ':frog:': '1f438',
    ':rabbit:': '1f407',
    ':rat:': '1f400',
    ':poodle:': '1f429',
    ':dog:': '1f415',
    ':guide_dog:': '1f9ae',
    ':service_dog:': '1f415_200d_1f9ba',
    ':pig:': '1f416',
    ':racehorse:': '1f40e',
    ':donkey:': '1facf',
    ':ox:': '1f402',
    ':goat:': '1f410',
    ':kangaroo:': '1f998',
    ':tiger:': '1f405',
    ':monkey:': '1f412',
    ':gorilla:': '1f98d',
    ':orangutan:': '1f9a7',
    ':chipmunk:': '1f43f_fe0f',
    ':otter:': '1f9a6',
    ':bat:': '1f987',
    ':bird:': '1f426',
    ':black_bird:': '1f426_200d_2b1b',
    ':rooster:': '1f413',
    ':hatching_chick:': '1f423',
    ':baby_chick:': '1f424',
    ':hatched_chick:': '1f425',
    ':eagle:': '1f985',
    ':owl:': '1f989',
    ':dove:': '1f54a_fe0f',
    ':peace:': '1f54a_fe0f',
    ':goose:': '1fabf',
    ':peacock:': '1f99a',
    ':phoenix:': '1f426_200d_1f525',
    ':seal:': '1f9ad',
    ':shark:': '1f988',
    ':dolphin:': '1f42c',
    ':whale:': '1f433',
    ':fish:': '1f41f',
    ':blowfish:': '1f421',
    ':lobster:': '1f99e',
    ':crab:': '1f980',
    ':octopus:': '1f419',
    ':jellyfish:': '1fabc',
    ':scorpion:': '1f982',
    ':spider:': '1f577_fe0f',
    ':snail:': '1f40c',
    ':ant:': '1f41c',
    ':mosquito:': '1f99f',
    ':cockroach:': '1fab3',
    ':fly:': '1fab0',
    ':bee:': '1f41d',
    ':lady_bug:': '1f41e',
    ':butterfly:': '1f98b',
    ':bug:': '1f41b',
    ':worm:': '1fab1',
    ':paw_prints:': '1f43e',
    ':tomato:': '1f345',
    ':beet:': '1fadc',
    ':root_vegetable:': '1fadc',
    ':turnip:': '1fadc',
    ':cooking:': '1f373',
    ':burrito:': '1f32f',
    ':spaghetti:': '1f35d',
    ':steaming_bowl:': '1f35c',
    ':popcorn:': '1f37f',
    ':hot_beverage:': '2615',
    ':clinking_beer_mugs:': '1f37b',
    ':clinking_glasses:': '1f942',
    ':bottle_with_popping_cork:': '1f37e',
    ':wine_glass:': '1f377',
    ':pour:': '1fad7',
    ':tropical_drink:': '1f379',
    ':construction:': '1f6a7',
    ':police_car_light:': '1f6a8',
    ':bicycle:': '1f6b2',
    ':automobile:': '1f697',
    ':racing_car:': '1f3ce_fe0f',
    ':taxi:': '1f695',
    ':bus:': '1f68c',
    ':sailboat:': '26f5',
    ':canoe:': '1f6f6',
    ':flying_saucer:': '1f6f8',
    ':rocket:': '1f680',
    ':airplane_departure:': '1f6eb',
    ':airplane_arrival:': '1f6ec',
    ':roller_coaster:': '1f3a2',
    ':ferris_wheel:': '1f3a1',
    ':camping:': '1f3d5_fe0f',
    ':balloon:': '1f388',
    ':birthday_cake:': '1f382',
    ':wrapped_gift:': '1f381',
    ':fireworks:': '1f386',
    ':pinata:': '1fa85',
    ':disco_ball:': '1faa9',
    ':mirror_ball:': '1faa9',
    ':first_place_medal:': '1f947',
    ':gold_medal:': '1f947',
    ':second_place_medal:': '1f948',
    ':silver_medal:': '1f948',
    ':third_place_medal:': '1f949',
    ':bronze_medal:': '1f949',
    ':trophy:': '1f3c6',
    ':soccer_ball:': '26bd',
    ':baseball:': '26be',
    ':softball:': '1f94e',
    ':tennis:': '1f3be',
    ':badminton:': '1f3f8',
    ':lacrosse:': '1f94d',
    ':cricket_game:': '1f3cf',
    ':field_hockey:': '1f3d1',
    ':ice_hockey:': '1f3d2',
    ':ice_skate:': '26f8_fe0f',
    ':roller_skates:': '1f6fc',
    ':ballet_shoes:': '1fa70',
    ':skateboard:': '1f6f9',
    ':flag_in_hole:': '26f3',
    ':direct_hit:': '1f3af',
    ':target:': '1f3af',
    ':flying_disc:': '1f94f',
    ':boomerang:': '1fa83',
    ':kite:': '1fa81',
    ':fishing_pole:': '1f3a3',
    ':martial_arts_uniform:': '1f94b',
    ':eight_ball:': '1f3b1',
    ':ping_pong:': '1f3d3',
    ':bowling:': '1f3b3',
    ':die:': '1f3b2',
    ':slot_machine:': '1f3b0',
    ':wand:': '1fa84',
    ':camera_flash:': '1f4f8',
    ':splatter:': '1fadf',
    ':saxophone:': '1f3b7',
    ':trumpet:': '1f3ba',
    ':violin:': '1f3bb',
    ':harp:': '1fa89',
    ':drum:': '1f941',
    ':maracas:': '1fa87',
    ':clapper:': '1f3ac',
    ':battery_full:': '1f50b',
    ':battery_low:': '1faab',
    ':coin:': '1fa99',
    ':money_with_wings:': '1f4b8',
    ':gem_stone:': '1f48e',
    ':balance_scale:': '2696_fe0f',
    ':light_bulb:': '1f4a1',
    ':graduation_cap:': '1f393',
    ':ring:': '1f48d',
    ':fan:': '1faad',
    ':umbrella:': '2602_fe0f',
    ':dig:': '1fa8f',
    ':shovel:': '1fa8f',
    ':gear:': '2699_fe0f',
    ':broken_chain:': '26d3_fe0f_200d_1f4a5',
    ':pencil:': '270f_fe0f',
    ':alarm_clock:': '23f0',
    ':bellhop_bell:': '1f6ce_fe0f',
    ':bell:': '1f514',
    ':crystal_ball:': '1f52e',
    ':bomb:': '1f4a3',
    ':mouse_trap:': '1faa4',
    ':locked:': '1f512',
    ':aries:': '2648',
    ':taurus:': '2649',
    ':gemini:': '264a',
    ':cancer:': '264b',
    ':leo:': '264c',
    ':virgo:': '264d',
    ':libra:': '264e',
    ':scorpio:': '264f',
    ':sagittarius:': '2650',
    ':capricorn:': '2651',
    ':aquarius:': '2652',
    ':pisces:': '2653',
    ':ophiuchus:': '26ce',
    ':exclamation_mark:': '2757',
    ':exclamation:': '2757',
    ':question_mark:': '2753',
    ':question:': '2753',
    ':interrobang:': '2049_fe0f',
    ':double_exclamation:': '203c_fe0f',
    ':cross_mark:': '274c',
    ':x:': '274c',
    ':sos:': '1f198',
    ':phone_off:': '1f4f4',
    ':radioactive:': '2622_fe0f',
    ':biohazard:': '2623_fe0f',
    ':warning:': '26a0_fe0f',
    ':check_mark_green:': '2705',
    ':check_mark:': '2705',
    ':new:': '1f195',
    ':free:': '1f193',
    ':up:': '1f199',
    ':cool:': '1f192',
    ':litter:': '1f6ae',
    ':peace_symbol:': '262e_fe0f',
    ':yin_yang:': '262f_fe0f',
    ':infinity:': '267e_fe0f',
    ':musical_notes:': '1f3b6',
    ':plus:': '2795',
    ':plus_sign:': '2795',
    ':chequered_flag:': '1f3c1',
    ':triangular_flag:': '1f6a9',
    ':black_flag:': '1f3f4',
    ':white_flag:': '1f3f3_fe0f',
    // Emojis personalizados (no de Noto) - Sonic de Slackmojis
    // Todos los emojis están en assets locales (assets/emoji_animated_noto/)
    ':sonic:': 'sonic_59877',
    ':sonic_blue:': 'sonic_59877',
    ':sonic1:': 'sonic_10687',
    ':sonic2:': 'sonic_43812',
    ':sonic3:': 'sonic_46444',
    ':sonic4:': 'sonic_92815',
    ':sonic__q:': 'sonic__q_85109',
    ':sonic_double_q:': 'sonic__q_85109',
    ':sonicq:': 'sonicq_73670',
    ':sonicq2:': 'sonicq_79951',
    ':sonic1q:': 'sonic1q_79952',
    ':asonicq:': 'asonicq_85355',
    ':sonic2q:': 'sonic2q_84953',
    ':sonic_wow:': 'sonic_wow_11999',
    ':sonic_run:': 'sonic_run_63777',
    ':sonic_running:': 'sonic_run_63777',
    ':ssoniccq:': 'ssoniccq_70614',
    ':sonicnoq:': 'sonicnoq_79953',
    ':sonichiq:': 'sonichiq_79954',
    ':sonic_1up:': 'sonic_1up_103077',
    ':sonic_ring:': 'sonic_ring_56731',
    ':wtfsonicq:': 'wtfsonicq_84123',
    ':sonic_runq:': 'sonic_runq_81366',
    ':gtgsonicq:': 'gtgsonicq_85378',
    ':sonicwave:': 'sonicwave_96246',
    ':sonic_slow:': 'sonic_slow_120435',
    ':mhmsonicq:': 'mhmsonicq_82044',
    ':omgsonicq:': 'omgsonicq_81600',
    ':supersonic:': 'supersonic_13390',
    ':sonic_super:': 'supersonic_13390',
    ':conga_sonic:': 'conga_sonic_4427',
    ':sonic_movie:': 'sonic_movie_59324',
    ':bruhsonic_q:': 'bruhsonic_q_69959',
    // Aliases para compatibilidad con emojis anteriores
    ':sonic_dance:': 'conga_sonic_4427',
    ':sonic_dance_pbj:': 'conga_sonic_4427',
    ':sonic_fast:': 'sonic_run_63777',
    ':sonicfastafboi:': 'sonic_run_63777',
    ':sonic_stfu:': 'sonicnoq_79953',
    ':sonicstfuq:': 'sonicnoq_79953',
    ':sonic_q:': 'sonicq_73670',
    ':sonic_scream:': 'omgsonicq_81600',
    ':sonicscreamq:': 'omgsonicq_81600',
    // Emojis de Bacteria de Slackmojis
    ':bacteria:': 'bacteria_14871',
    ':bacteria1:': 'bacteria_14871',
    ':bacteria2:': 'bacteria_52843',
    // Emojis de Pumuckl de Slackmojis
    ':pumuckl:': 'pumuckl_5661',
    // Pato animado (personalizado - similar a antipatos)
    ':pato:': 'pato_antipatos',
    ':antipatos:': 'pato_antipatos',
    ':duck:': 'pato_antipatos',
    // Emojis de Banderas de Slackmojis
    ':spain:': 'spain_37163',
    ':es:': 'spain_37163',
    ':espana:': 'spain_37163',
  };
  
  // Mapa de códigos de emoticonos comunes a sus códigos Unicode
  static final Map<String, String> emojiMap = {
    // Caras sonrientes
    ':smile:': '1f604',
    ':grinning:': '1f600',
    ':joy:': '1f602',
    ':laughing:': '1f606',
    ':wink:': '1f609',
    ':blush:': '1f60a',
    ':smiley:': '1f603',
    ':relaxed:': '263a',
    ':smirk:': '1f60f',
    ':heart_eyes:': '1f60d',
    ':kissing_heart:': '1f618',
    ':kissing:': '1f617',
    ':kissing_closed_eyes:': '1f61a',
    ':flushed:': '1f633',
    ':relieved:': '1f60c',
    ':satisfied:': '1f606',
    ':grin:': '1f601',
    ':wink2:': '1f60f',
    ':stuck_out_tongue:': '1f61b',
    ':stuck_out_tongue_winking_eye:': '1f61c',
    ':stuck_out_tongue_closed_eyes:': '1f61d',
    ':kissing_smiling_eyes:': '1f619',
    ':expressionless:': '1f611',
    ':unamused:': '1f612',
    ':sweat:': '1f613',
    ':pensive:': '1f614',
    ':confused:': '1f615',
    ':confounded:': '1f616',
    ':kissing_heart:': '1f618',
    ':yum:': '1f60b',
    ':mask:': '1f637',
    ':sunglasses:': '1f60e',
    ':sleeping:': '1f634',
    ':dizzy_face:': '1f635',
    ':astonished:': '1f632',
    ':worried:': '1f61f',
    ':frowning:': '1f626',
    ':anguished:': '1f627',
    ':open_mouth:': '1f62e',
    ':grimacing:': '1f62c',
    ':hushed:': '1f62f',
    ':cold_sweat:': '1f630',
    ':scream:': '1f631',
    ':cry:': '1f622',
    ':sob:': '1f62d',
    ':tired_face:': '1f62b',
    ':weary:': '1f629',
    ':triumph:': '1f624',
    ':rage:': '1f621',
    ':angry:': '1f620',
    ':imp:': '1f47f',
    ':smiling_imp:': '1f608',
    ':neutral_face:': '1f610',
    ':no_mouth:': '1f636',
    ':innocent:': '1f607',
    
    // Gestos
    ':thumbsup:': '1f44d',
    ':thumbsdown:': '1f44e',
    ':ok_hand:': '1f44c',
    ':punch:': '1f44a',
    ':fist:': '270a',
    ':v:': '270c',
    ':wave:': '1f44b',
    ':hand:': '270b',
    ':open_hands:': '1f450',
    ':point_up:': '1f446',
    ':point_down:': '1f447',
    ':point_left:': '1f448',
    ':point_right:': '1f449',
    ':raised_hands:': '1f64c',
    ':pray:': '1f64f',
    ':point_up_2:': '1f446',
    ':clap:': '1f44f',
    ':muscle:': '1f4aa',
    ':fu:': '1f595',
    ':walking:': '1f6b6',
    ':runner:': '1f3c3',
    ':couple:': '1f46b',
    ':family:': '1f46a',
    ':two_men_holding_hands:': '1f46c',
    ':two_women_holding_hands:': '1f46d',
    ':dancer:': '1f483',
    ':dancers:': '1f46f',
    ':ok_woman:': '1f646',
    ':no_good:': '1f645',
    ':information_desk_person:': '1f481',
    ':raising_hand:': '1f64b',
    ':bride_with_veil:': '1f470',
    ':person_with_pouting_face:': '1f64e',
    ':person_frowning:': '1f64d',
    ':bow:': '1f647',
    ':couplekiss:': '1f48f',
    ':couple_with_heart:': '1f491',
    ':massage:': '1f486',
    ':haircut:': '1f487',
    ':nail_care:': '1f485',
    ':boy:': '1f466',
    ':girl:': '1f467',
    ':woman:': '1f469',
    ':man:': '1f468',
    ':baby:': '1f476',
    ':older_woman:': '1f475',
    ':older_man:': '1f474',
    ':person_with_blond_hair:': '1f471',
    ':man_with_gua_pi_mao:': '1f472',
    ':man_with_turban:': '1f473',
    ':construction_worker:': '1f477',
    ':cop:': '1f46e',
    ':angel:': '1f47c',
    ':princess:': '1f478',
    ':smiley_cat:': '1f63a',
    ':smile_cat:': '1f638',
    ':heart_eyes_cat:': '1f63b',
    ':kissing_cat:': '1f63d',
    ':smirk_cat:': '1f63c',
    ':scream_cat:': '1f640',
    ':crying_cat_face:': '1f63f',
    ':joy_cat:': '1f639',
    ':pouting_cat:': '1f63e',
    ':japanese_ogre:': '1f479',
    ':japanese_goblin:': '1f47a',
    ':see_no_evil:': '1f648',
    ':hear_no_evil:': '1f649',
    ':speak_no_evil:': '1f64a',
    ':guardsman:': '1f482',
    ':skull:': '1f480',
    ':feet:': '1f43e',
    ':lips:': '1f444',
    ':kiss:': '1f48b',
    ':droplet:': '1f4a7',
    ':ear:': '1f442',
    ':eyes:': '1f440',
    ':nose:': '1f443',
    ':tongue:': '1f445',
    ':love_letter:': '1f48c',
    ':bust_in_silhouette:': '1f464',
    ':busts_in_silhouette:': '1f465',
    ':speech_balloon:': '1f4ac',
    ':thought_balloon:': '1f4ad',
    
    // Corazones
    ':heart:': '2764',
    ':yellow_heart:': '1f49b',
    ':green_heart:': '1f49a',
    ':blue_heart:': '1f499',
    ':purple_heart:': '1f49c',
    ':broken_heart:': '1f494',
    ':heartbeat:': '1f493',
    ':heartpulse:': '1f497',
    ':two_hearts:': '1f495',
    ':sparkling_heart:': '1f496',
    ':revolving_hearts:': '1f49e',
    ':cupid:': '1f498',
    ':love_hotel:': '1f3e9',
    ':gift_heart:': '1f49d',
    ':heart_decoration:': '1f49f',
    
    // Otros comunes
    ':thumbsup:': '1f44d',
    ':thumbsdown:': '1f44e',
    ':fire:': '1f525',
    ':100:': '1f4af',
    ':ok:': '1f197',
    ':x:': '274c',
    ':o:': '2b55',
    ':heavy_multiplication_x:': '2716',
    ':heavy_plus_sign:': '2715',
    ':heavy_minus_sign:': '2796',
    ':heavy_division_sign:': '2797',
    ':white_check_mark:': '2705',
    ':ballot_box_with_check:': '2611',
    ':radio_button:': '1f518',
    ':link:': '1f517',
    ':curly_loop:': '27b0',
    ':wavy_dash:': '3030',
    ':part_alternation_mark:': '303d',
    ':eight_spoked_asterisk:': '2733',
    ':eight_pointed_black_star:': '2734',
    ':sparkle:': '2747',
    ':copyright:': '00a9',
    ':registered:': '00ae',
    ':tm:': '2122',
    ':hash:': '0023-20e3',
    ':asterisk:': '002a-20e3',
    ':zero:': '0030-20e3',
    ':one:': '0031-20e3',
    ':two:': '0032-20e3',
    ':three:': '0033-20e3',
    ':four:': '0034-20e3',
    ':five:': '0035-20e3',
    ':six:': '0036-20e3',
    ':seven:': '0037-20e3',
    ':eight:': '0038-20e3',
    ':nine:': '0039-20e3',
  };
  
  // Obtener la URL de la imagen del emoticono
  static String? getEmojiUrl(String emojiCode) {
    final code = emojiCode.toLowerCase();
    
    // Verificar si es un emoticono animado
    if (animatedEmojiMap.containsKey(code)) {
      final unicode = animatedEmojiMap[code];
      if (unicode != null) {
        final codepoint = unicode.toLowerCase();
        // Si el codepoint contiene caracteres no hexadecimales (como "sonic_blue"),
        // es un asset personalizado y usamos el nombre tal cual
        // Si es un codepoint hexadecimal de Noto (ej: "1f389"), lo usamos directamente
        final isCustomAsset = !RegExp(r'^[0-9a-f_]+$').hasMatch(codepoint);
        if (isCustomAsset) {
          // Asset personalizado: intentar primero GIF, luego PNG
          // El código que carga la imagen verificará si existe
          return '${animatedAssetBasePath}${codepoint}.gif';
        } else {
          // Codepoint de Noto: usar formato estándar
          return '${animatedAssetBasePath}${codepoint}.gif';
        }
      }
      return null;
    }
    
    // Emoticonos estáticos normales
    final unicode = emojiMap[code];
    if (unicode == null) return null;
    return '$cdnBaseUrl$unicode.png';
  }

  /// Si el "url" devuelto por getEmojiUrl apunta a un asset local.
  static bool isAssetPath(String? url) {
    if (url == null) return false;
    return url.startsWith('assets/');
  }

  /// Obtener URL alternativa (PNG) si el GIF no existe para assets personalizados
  static String? getAlternativeAssetUrl(String? emojiUrl) {
    if (emojiUrl == null || !emojiUrl.startsWith('assets/')) return null;
    if (emojiUrl.endsWith('.gif')) {
      return emojiUrl.replaceAll('.gif', '.png');
    }
    return null;
  }

  /// Fallback por si el asset local no existe (o falla al cargar).
  static String? getAnimatedFallbackNetworkUrl(String emojiCode) {
    final code = emojiCode.toLowerCase();
    final unicode = animatedEmojiMap[code];
    if (unicode == null) return null;
    final codepoint = unicode.toLowerCase();
    // Si es un asset personalizado (no codepoint hexadecimal), no hay fallback a Noto CDN
    final isCustomAsset = !RegExp(r'^[0-9a-f_]+$').hasMatch(codepoint);
    if (isCustomAsset) return null;
    return '${animatedCdnBaseUrl}${codepoint}/512.gif';
  }

  /// URL (red) al GIF de Noto para un codepoint. Puede ser estático o animado según exista en Noto.
  /// Formato esperado: https://fonts.gstatic.com/s/e/notoemoji/latest/{codepoint}/512.gif
  ///
  /// Nota: para algunos emojis con variation selector o secuencias, Noto usa '_' (ej: 2764_fe0f).
  static String? getNotoGifUrlForEmojiCode(String emojiCode) {
    final code = emojiCode.toLowerCase();

    // Preferir el codepoint del mapa animado si existe
    final cp = animatedEmojiMap[code] ?? emojiMap[code];
    if (cp == null) return null;

    final raw = cp.toLowerCase();
    // Intentaremos con el raw tal cual; si falla en UI, el errorBuilder hará fallback.
    return '$notoLatestBaseUrl$raw/512.gif';
  }
  
  // Obtener el emoji Unicode directamente para renderizado nativo (mejor para animados)
  static String? getEmojiUnicode(String emojiCode) {
    final code = emojiCode.toLowerCase();
    
    // Verificar si es un emoticono animado
    if (animatedEmojiMap.containsKey(code)) {
      final unicode = animatedEmojiMap[code];
      if (unicode != null) {
        // Convertir código hexadecimal a emoji Unicode
        try {
          final codePoints = unicode.split('-');
          final chars = codePoints.map((cp) {
            final intValue = int.parse(cp, radix: 16);
            return String.fromCharCode(intValue);
          }).join();
          return chars;
        } catch (e) {
          return null;
        }
      }
    }
    
    // Para emoticonos estáticos, también podemos devolver Unicode
    final unicode = emojiMap[code];
    if (unicode != null) {
      try {
        final codePoints = unicode.split('-');
        final chars = codePoints.map((cp) {
          final intValue = int.parse(cp, radix: 16);
          return String.fromCharCode(intValue);
        }).join();
        return chars;
      } catch (e) {
        return null;
      }
    }
    
    return null;
  }
  
  // Verificar si un emoticono es animado
  static bool isAnimated(String emojiCode) {
    return animatedEmojiMap.containsKey(emojiCode.toLowerCase());
  }
  
  // Convertir texto con códigos de emoticonos a widgets
  static List<String> parseEmojiCodes(String text) {
    final List<String> parts = [];
    // Aceptar nombres con guiones, subrayados, números, etc. hasta el próximo ':'.
    final regex = RegExp(r':([^:]+):');
    int lastIndex = 0;
    
    for (final match in regex.allMatches(text)) {
      // Añadir texto antes del emoticono
      if (match.start > lastIndex) {
        parts.add(text.substring(lastIndex, match.start));
      }
      // Añadir el código del emoticono
      parts.add(match.group(0)!);
      lastIndex = match.end;
    }
    
    // Añadir el texto restante
    if (lastIndex < text.length) {
      parts.add(text.substring(lastIndex));
    }
    
    return parts;
  }
  
  // Lista de emoticonos populares para el selector
  static List<String> getPopularEmojis() {
    return [
      ':smile:', ':grinning:', ':joy:', ':laughing:', ':wink:', ':blush:',
      ':heart_eyes:', ':kissing_heart:', ':stuck_out_tongue:', ':sunglasses:',
      ':thumbsup:', ':thumbsdown:', ':ok_hand:', ':wave:', ':clap:', ':pray:',
      ':heart:', ':broken_heart:', ':two_hearts:', ':sparkling_heart:',
      ':fire:', ':100:', ':ok:', ':x:', ':o:',
    ];
  }
  
  // Lista completa de emoticonos organizados por categorías
  static Map<String, List<String>> getEmojisByCategory() {
    // Construir listas de animados por categoría para mejorar la carga
    // Usar Sets para rastrear emojis y assets ya asignados y evitar duplicados
    final Set<String> assignedEmojis = {};
    final Set<String> assignedAssets = {};
    
    // Función helper para filtrar y eliminar duplicados
    // Verifica tanto el código del emoji como el asset al que apunta
    List<String> filterUnique(List<String> emojis) {
      return emojis
          .where((e) {
            final key = e.toLowerCase();
            if (!animatedEmojiMap.containsKey(key)) return false;
            if (assignedEmojis.contains(key)) return false;
            
            // Verificar si el asset ya fue usado por otro emoji
            final asset = animatedEmojiMap[key]?.toLowerCase();
            if (asset != null && assignedAssets.contains(asset)) {
              return false; // Este asset ya está asignado a otro emoji
            }
            
            // Marcar como asignado tanto el código como el asset
            assignedEmojis.add(key);
            if (asset != null) {
              assignedAssets.add(asset);
            }
            return true;
          })
          .toList();
    }

    // Caras animadas - felices
    final carasFelices = filterUnique([
      ':smile:', ':smile_with_big_eyes:', ':grin:', ':grinning:', ':laughing:',
      ':grin_sweat:', ':joy:', ':rofl:', ':wink:', ':kissing:', ':kissing_smiling_eyes:',
      ':kissing_closed_eyes:', ':kissing_heart:', ':heart_eyes:', ':star_struck:',
      ':partying_face:', ':upside_down_face:', ':slightly_happy:', ':happy_cry:',
      ':holding_back_tears:', ':blush:', ':warm_smile:', ':relieved:', ':head_nod:',
      ':smirk:', ':drool:', ':yum:', ':stuck_out_tongue:', ':squinting_tongue:',
      ':winky_tongue:', ':zany_face:', ':woozy:', ':hug_face:', ':peeking:',
      ':innocent:', ':cowboy:', ':sunglasses_face:',
    ]);

    // Caras animadas - tristes/enfadadas
    final carasTristes = filterUnique([
      ':loudly_crying:', ':pensive:', ':pleading:', ':sad:', ':downcast:',
      ':sweat:', ':worried:', ':concerned:', ':cry:', ':big_frown:', ':frown:',
      ':slightly_frowning:', ':anxious_with_sweat:', ':scared:', ':anguished:',
      ':gasp:', ':weary:', ':distraught:', ':tired:', ':sleepy:', ':sleep:',
    ]);

    // Caras animadas - sorprendidas/expresivas
    final carasExpresivas = filterUnique([
      ':screaming:', ':raised_eyebrow:', ':monocle:', ':unamused:', ':rolling_eyes:',
      ':exhale:', ':triumph:', ':angry:', ':rage:', ':cursing:', ':mouth_open:',
      ':hushed:', ':surprised:', ':astonished:', ':flushed:', ':exploding_head:',
      ':mind_blown:', ':confounded:', ':persevering:', ':x_eyes:', ':dizzy_face:',
      ':shaking_face:', ':cold_face:', ':hot_face:', ':sweat_face:', ':nauseated:',
      ':sick:', ':vomit:', ':sneeze:', ':thermometer_face:', ':bandage_face:',
      ':mask:', ':liar:', ':thinking_face:', ':shushing_face:', ':hand_over_mouth:',
      ':chuckling:', ':yawn:', ':grimacing:', ':expressionless:', ':neutral_face:',
      ':zipper_face:', ':salute:', ':money_face:', ':nerd_face:', ':disguise:',
      ':clown:', ':imp_smile:', ':imp_frown:', ':ghost:', ':skull:', ':robot:',
      ':alien:', ':alien_monster:',
    ]);

    // Gatos animados
    final gatosAnimados = filterUnique([
      ':smiley_cat:', ':smile_cat:', ':joy_cat:', ':heart_eyes_cat:', ':smirk_cat:',
      ':kissing_cat:', ':scream_cat:', ':crying_cat_face:', ':pouting_cat:',
    ]);

    // Gestos animados
    final gestosAnimados = filterUnique([
      ':clap:', ':thumbs_up:', ':+1:', ':thumbs_down:', ':heart_hands:',
      ':hooray:', ':raising_hands:', ':open_hands:', ':palms_up:', ':fist_rightwards:',
      ':fist_leftwards:', ':raised_fist:', ':bump:', ':fist:', ':wave:', ':back_hand:',
      ':palm:', ':raised_hand:', ':prosper:', ':spock:', ':vulcan:', ':love_you_gesture:',
      ':horns:', ':metal:', ':peace_hand:', ':v:', ':victory:', ':crossed_fingers:',
      ':finger_heart:', ':snap:', ':call_me_hand:', ':pinched_fingers:', ':pinch:',
      ':ok:', ':pointing:', ':point_right:', ':point_left:', ':index_finger:',
      ':point_up:', ':point_down:', ':middle_finger:', ':writing_hand:', ':selfie:',
      ':folded_hands:', ':pray:', ':nail_care:', ':handshake:', ':dancer_woman:',
    ]);

    // Corazones animados
    final corazonesAnimados = filterUnique([
      ':red_heart:', ':orange_heart:', ':yellow_heart:', ':green_heart:',
      ':light_blue_heart:', ':blue_heart:', ':purple_heart:', ':brown_heart:',
      ':black_heart:', ':grey_heart:', ':white_heart:', ':pink_heart:', ':cupid:',
      ':gift_heart:', ':sparkling_heart:', ':heart_grow:', ':beating_heart:',
      ':revolving_hearts:', ':two_hearts:', ':love_letter:', ':heart_box:',
      ':heart_exclamation_point:', ':bandaged_heart:', ':broken_heart:', ':fire_heart:',
      ':kiss:', ':anatomical_heart:', ':blood:',
    ]);

    // Celebración
    final celebracion = filterUnique([
      ':party_popper:', ':confetti_ball:', ':balloon:', ':birthday_cake:',
      ':wrapped_gift:', ':fireworks:', ':pinata:', ':disco_ball:', ':mirror_ball:',
      ':first_place_medal:', ':gold_medal:', ':second_place_medal:', ':silver_medal:',
      ':third_place_medal:', ':bronze_medal:', ':trophy:', ':hundred:', ':one_hundred:',
      ':points:', ':sparkles:', ':glowing_star:',
    ]);

    // Naturaleza
    final naturaleza = filterUnique([
      ':bouquet:', ':flowers:', ':rose:', ':wilted_flower:', ':fallen_leaf:',
      ':plant:', ':seed:', ':leaves:', ':four_leaf_clover:', ':luck:', ':leafless_tree:',
      ':cold:', ':snowflake:', ':winter:', ':snowman:', ':snowman_with_snow:',
      ':volcano:', ':sunrise:', ':sunrise_over_mountains:', ':rainbow:', ':bubbles:',
      ':ocean:', ':wind_face:', ':tornado:', ':droplet:', ':rain_cloud:',
      ':cloud_with_lightning:', ':comet:', ':sun_with_face:', ':moon_face_first_quarter:',
      ':moon_face_last_quarter:', ':globe_showing_europe_africa:', ':globe_showing_americas:',
      ':globe_showing_asia_australia:',
    ]);

    // Animales
    final animales = filterUnique([
      ':cow_face:', ':unicorn:', ':lizard:', ':dragon:', ':t_rex:', ':dinosaur:',
      ':turtle:', ':crocodile:', ':snake:', ':frog:', ':rabbit:', ':rat:',
      ':poodle:', ':dog:', ':guide_dog:', ':service_dog:', ':pig:', ':racehorse:',
      ':donkey:', ':ox:', ':goat:', ':kangaroo:', ':tiger:', ':monkey:',
      ':gorilla:', ':orangutan:', ':chipmunk:', ':otter:', ':bat:', ':bird:',
      ':black_bird:', ':rooster:', ':hatching_chick:', ':baby_chick:', ':hatched_chick:',
      ':eagle:', ':owl:', ':dove:', ':goose:', ':peacock:', ':phoenix:',
      ':pato:', ':antipatos:', ':duck:', // Pato animado
      ':seal:', ':shark:', ':dolphin:', ':whale:', ':fish:', ':blowfish:',
      ':lobster:', ':crab:', ':octopus:', ':jellyfish:', ':scorpion:', ':spider:',
      ':snail:', ':ant:', ':mosquito:', ':cockroach:', ':fly:', ':bee:',
      ':lady_bug:', ':butterfly:', ':bug:', ':worm:', ':paw_prints:',
      ':see_no_evil_monkey:', ':hear_no_evil_monkey:', ':speak_no_evil_monkey:',
    ]);

    // Comida y Bebida
    final comidaBebida = filterUnique([
      ':tomato:', ':beet:', ':root_vegetable:', ':turnip:', ':cooking:',
      ':burrito:', ':spaghetti:', ':steaming_bowl:', ':popcorn:', ':hot_beverage:',
      ':clinking_beer_mugs:', ':clinking_glasses:', ':bottle_with_popping_cork:',
      ':wine_glass:', ':pour:', ':tropical_drink:',
    ]);

    // Deportes
    final deportes = filterUnique([
      ':soccer_ball:', ':baseball:', ':softball:', ':tennis:', ':badminton:',
      ':lacrosse:', ':cricket_game:', ':field_hockey:', ':ice_hockey:', ':ice_skate:',
      ':roller_skates:', ':ballet_shoes:', ':skateboard:', ':flag_in_hole:',
      ':direct_hit:', ':target:', ':flying_disc:', ':boomerang:', ':kite:',
      ':fishing_pole:', ':martial_arts_uniform:', ':eight_ball:', ':ping_pong:',
      ':bowling:', ':die:', ':slot_machine:',
    ]);

    // Transporte
    final transporte = filterUnique([
      ':construction:', ':police_car_light:', ':bicycle:', ':automobile:',
      ':racing_car:', ':taxi:', ':bus:', ':sailboat:', ':canoe:', ':flying_saucer:',
      ':rocket:', ':airplane_departure:', ':airplane_arrival:', ':roller_coaster:',
      ':ferris_wheel:', ':camping:',
    ]);

    // Música
    final musica = filterUnique([
      ':saxophone:', ':trumpet:', ':violin:', ':harp:', ':drum:', ':maracas:',
      ':clapper:', ':musical_notes:',
    ]);

    // Objetos y Símbolos
    final objetos = filterUnique([
      ':battery_full:', ':battery_low:', ':coin:', ':money_with_wings:', ':gem_stone:',
      ':balance_scale:', ':light_bulb:', ':graduation_cap:', ':ring:', ':fan:',
      ':umbrella:', ':dig:', ':shovel:', ':gear:', ':broken_chain:', ':pencil:',
      ':alarm_clock:', ':bellhop_bell:', ':bell:', ':crystal_ball:', ':bomb:',
      ':mouse_trap:', ':locked:', ':wand:', ':camera_flash:', ':splatter:',
      ':electricity:', ':lightning:', ':zap:', ':collision:', ':burn:', ':fire:',
      ':lit:', ':eyes:', ':eye:', ':biting_lip:', ':nose:', ':ear:', ':hearing_aid:',
      ':foot:', ':leg:', ':bicep:', ':flex:', ':muscle:', ':strong:', ':footprints:',
      ':fingerprint:', ':microbe:', ':virus:', ':jack_o_lantern:',
    ]);

    // Zodíaco
    final zodiaco = filterUnique([
      ':aries:', ':taurus:', ':gemini:', ':cancer:', ':leo:', ':virgo:',
      ':libra:', ':scorpio:', ':sagittarius:', ':capricorn:', ':aquarius:',
      ':pisces:', ':ophiuchus:',
    ]);

    // Símbolos (nota: peace_symbol está aquí, no en animales)
    final simbolos = filterUnique([
      ':exclamation_mark:', ':exclamation:', ':question_mark:', ':question:',
      ':interrobang:', ':double_exclamation:', ':cross_mark:', ':x:', ':sos:',
      ':phone_off:', ':radioactive:', ':biohazard:', ':warning:', ':check_mark_green:',
      ':check_mark:', ':new:', ':free:', ':up:', ':cool:', ':litter:',
      ':peace_symbol:', ':yin_yang:', ':infinity:', ':plus:', ':plus_sign:',
      ':chequered_flag:', ':triangular_flag:', ':black_flag:', ':white_flag:',
    ]);

    // Sonic (todos los emojis de Sonic juntos - todos en assets locales)
    final sonic = filterUnique([
      ':sonic:', ':sonic_blue:', ':sonic1:', ':sonic2:', ':sonic3:', ':sonic4:',
      ':sonic__q:', ':sonic_double_q:', ':sonicq:', ':sonicq2:', ':sonic1q:',
      ':asonicq:', ':sonic2q:', ':sonic_wow:', ':sonic_run:', ':sonic_running:',
      ':ssoniccq:', ':sonicnoq:', ':sonichiq:', ':sonic_1up:', ':sonic_ring:',
      ':wtfsonicq:', ':sonic_runq:', ':gtgsonicq:', ':sonicwave:', ':sonic_slow:',
      ':mhmsonicq:', ':omgsonicq:', ':supersonic:', ':sonic_super:', ':conga_sonic:',
      ':sonic_movie:', ':bruhsonic_q:',
      // Aliases para compatibilidad
      ':sonic_dance:', ':sonic_dance_pbj:', ':sonic_fast:', ':sonicfastafboi:',
      ':sonic_stfu:', ':sonicstfuq:', ':sonic_q:', ':sonic_scream:', ':sonicscreamq:',
    ]);

    // Bacteria (emojis de bacteria de Slackmojis)
    final bacteria = filterUnique([
      ':bacteria:', ':bacteria1:', ':bacteria2:',
    ]);

    // Pumuckl (emojis de Pumuckl de Slackmojis)
    final pumuckl = filterUnique([
      ':pumuckl:',
    ]);

    // Banderas (emojis de banderas de Slackmojis)
    final banderas = filterUnique([
      ':spain:', ':es:', ':espana:',
    ]);

    return {
      // Categorías animadas (más específicas para mejor carga)
      'Caras Felices': carasFelices,
      'Caras Tristes': carasTristes,
      'Caras Expresivas': carasExpresivas,
      'Gatos': gatosAnimados,
      'Gestos': gestosAnimados,
      'Corazones': corazonesAnimados,
      'Celebración': celebracion,
      'Naturaleza': naturaleza,
      'Animales': animales,
      'Comida': comidaBebida,
      'Deportes': deportes,
      'Transporte': transporte,
      'Música': musica,
      'Objetos': objetos,
      'Zodíaco': zodiaco,
      'Símbolos': simbolos,
      'Sonic': sonic,
      'Bacteria': bacteria,
      'Pumuckl': pumuckl,
      'Banderas': banderas,
      // Categorías estáticas (mantener para compatibilidad)
      'Caras': [
        ':smile:', ':grinning:', ':joy:', ':laughing:', ':wink:', ':blush:',
        ':smiley:', ':relaxed:', ':smirk:', ':heart_eyes:', ':kissing_heart:',
        ':kissing:', ':flushed:', ':relieved:', ':stuck_out_tongue:',
        ':sunglasses:', ':sleeping:', ':dizzy_face:', ':cry:', ':sob:',
        ':rage:', ':angry:', ':neutral_face:', ':innocent:',
      ],
      'Gestos': [
        ':thumbsup:', ':thumbsdown:', ':ok_hand:', ':wave:', ':clap:',
        ':pray:', ':point_up:', ':point_down:', ':point_left:', ':point_right:',
        ':raised_hands:', ':muscle:', ':fist:', ':v:',
      ],
      'Corazones': [
        ':heart:', ':broken_heart:', ':two_hearts:', ':sparkling_heart:',
        ':heartbeat:', ':heartpulse:', ':revolving_hearts:', ':cupid:',
        ':yellow_heart:', ':green_heart:', ':blue_heart:', ':purple_heart:',
      ],
      'Otros': [
        ':fire:', ':100:', ':ok:', ':x:', ':o:', ':white_check_mark:',
        ':link:', ':copyright:', ':registered:', ':tm:',
      ],
    };
  }
}












