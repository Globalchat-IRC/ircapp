class EmojiService {
  static const String cdnBaseUrl = 'https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/';
  // CDN para emoticonos animados (GIFs) - usando emoji.gg que tiene GIFs animados
  static const String animatedCdnBaseUrl = 'https://emoji.gg/assets/';
  
  // Mapa de emoticonos animados (GIFs) - usando nombres de archivos comunes
  static final Map<String, String> animatedEmojiMap = {
    // Caras animadas
    ':party:': '1f389',
    ':confetti_ball:': '1f38a',
    ':tada:': '1f389',
    ':clap_animated:': '1f44f',
    ':wave_animated:': '1f44b',
    ':thumbsup_animated:': '1f44d',
    ':fire_animated:': '1f525',
    ':heart_animated:': '2764',
    ':sparkles:': '2728',
    ':star_struck:': '1f929',
    ':dancing:': '1f57a',
    ':dancing_woman:': '1f483',
    ':dancing_men:': '1f46f',
    ':celebration:': '1f389',
    ':balloon:': '1f388',
    ':gift:': '1f381',
    ':trophy:': '1f3c6',
    ':medal:': '1f3c5',
    ':clinking_glasses:': '1f942',
    ':beers:': '1f37b',
    ':champagne:': '1f37e',
    ':rocket:': '1f680',
    ':star:': '2b50',
    ':rainbow:': '1f308',
    ':sunny:': '2600',
    ':zap:': '26a1',
    ':boom:': '1f4a5',
    ':collision:': '1f4a5',
    ':dizzy:': '1f4ab',
    ':sparkling_heart_animated:': '1f496',
    ':heart_eyes_animated:': '1f60d',
    ':kiss_animated:': '1f48b',
    ':love_you:': '1f91f',
    ':muscle_animated:': '1f4aa',
    ':ok_hand_animated:': '1f44c',
    ':victory_animated:': '270c',
    ':pray_animated:': '1f64f',
    ':clap_hands:': '1f44f',
    ':raised_hands_animated:': '1f64c',
    ':waving_hand:': '1f44b',
    ':thumbs_down_animated:': '1f44e',
    ':point_right_animated:': '1f449',
    ':point_left_animated:': '1f448',
    ':point_up_animated:': '1f446',
    ':point_down_animated:': '1f447',
    ':fist_animated:': '270a',
    ':punch_animated:': '1f44a',
    ':fingers_crossed:': '1f91e',
    ':call_me:': '1f919',
    ':metal:': '1f918',
    ':writing_hand:': '270d',
    ':nail_care_animated:': '1f485',
    ':selfie:': '1f933',
    ':dancer_animated:': '1f483',
    ':man_dancing:': '1f57a',
    ':dancing_women:': '1f46f',
    ':dancing_men_animated:': '1f46f',
    ':party_popper:': '1f389',
    ':confetti:': '1f38a',
    ':tada_animated:': '1f389',
    ':birthday:': '1f382',
    ':cake:': '1f370',
    ':cookie:': '1f36a',
    ':ice_cream:': '1f368',
    ':pizza:': '1f355',
    ':hamburger:': '1f354',
    ':taco:': '1f32e',
    ':burrito:': '1f32f',
    ':beer_animated:': '1f37a',
    ':cocktail:': '1f378',
    ':wine_glass:': '1f377',
    ':champagne_animated:': '1f37e',
    ':clinking_glasses_animated:': '1f942',
    ':tropical_drink:': '1f379',
    ':beer_mug:': '1f37a',
    ':beers_animated:': '1f37b',
    ':popcorn:': '1f37f',
    ':movie_camera:': '1f3a5',
    ':camera_flash:': '1f4f8',
    ':video_camera:': '1f4f9',
    ':tv:': '1f4fa',
    ':radio:': '1f4fb',
    ':musical_note:': '1f3b5',
    ':musical_notes:': '1f3b6',
    ':headphones:': '1f3a7',
    ':microphone:': '1f3a4',
    ':guitar:': '1f3b8',
    ':saxophone:': '1f3b7',
    ':trumpet:': '1f3ba',
    ':violin:': '1f3bb',
    ':drum:': '1f941',
    ':musical_keyboard:': '1f3b9',
    ':game_die:': '1f3b2',
    ':video_game:': '1f3ae',
    ':joystick:': '1f579',
    ':slot_machine:': '1f3b0',
    ':game_controller:': '1f3ae',
    ':8ball:': '1f3b1',
    ':basketball:': '1f3c0',
    ':soccer:': '26bd',
    ':baseball:': '26be',
    ':tennis:': '1f3be',
    ':volleyball:': '1f3d0',
    ':rugby_football:': '1f3c9',
    ':football:': '1f3c8',
    ':swimmer:': '1f3ca',
    ':surfer:': '1f3c4',
    ':rowboat:': '1f6a3',
    ':bicyclist:': '1f6b4',
    ':mountain_bicyclist:': '1f6b5',
    ':racehorse:': '1f40e',
    ':racing_car:': '1f3ce',
    ':motorcycle:': '1f3cd',
    ':airplane:': '2708',
    ':helicopter:': '1f681',
    ':rocket_animated:': '1f680',
    ':flying_saucer:': '1f6f8',
    ':satellite:': '1f6f0',
    ':artificial_satellite:': '1f6f0',
    ':star2:': '1f31f',
    ':dizzy_star:': '1f4ab',
    ':sparkles_animated:': '2728',
    ':comet:': '2604',
    ':sun_with_face:': '1f31e',
    ':full_moon_with_face:': '1f31d',
    ':new_moon_with_face:': '1f31a',
    ':crescent_moon:': '1f319',
    ':first_quarter_moon:': '1f313',
    ':last_quarter_moon:': '1f317',
    ':waxing_gibbous_moon:': '1f314',
    ':waning_gibbous_moon:': '1f316',
    ':waxing_crescent_moon:': '1f312',
    ':waning_crescent_moon:': '1f318',
    ':earth_americas:': '1f30e',
    ':earth_africa:': '1f30d',
    ':earth_asia:': '1f30f',
    ':globe_with_meridians:': '1f310',
    ':new_moon:': '1f311',
    ':waxing_crescent_moon2:': '1f312',
    ':first_quarter_moon2:': '1f313',
    ':waxing_gibbous_moon2:': '1f314',
    ':full_moon:': '1f315',
    ':waning_gibbous_moon2:': '1f316',
    ':last_quarter_moon2:': '1f317',
    ':waning_crescent_moon2:': '1f318',
    ':crescent_moon2:': '1f319',
    ':new_moon_with_face2:': '1f31a',
    ':first_quarter_moon_with_face:': '1f31b',
    ':last_quarter_moon_with_face:': '1f31c',
    ':full_moon_with_face2:': '1f31d',
    ':sun_with_face2:': '1f31e',
    ':star2_animated:': '1f31f',
    ':milky_way:': '1f30c',
    ':cloud:': '2601',
    ':sun_behind_cloud:': '26c5',
    ':cloud_with_rain:': '1f327',
    ':cloud_with_lightning:': '1f329',
    ':cloud_with_lightning_and_rain:': '1f32a',
    ':cloud_with_snow:': '1f328',
    ':snowflake:': '2744',
    ':snowman:': '26c4',
    ':snowman_without_snow:': '26c4',
    ':wind_face:': '1f32c',
    ':tornado:': '1f32a',
    ':fog:': '1f32b',
    ':umbrella:': '2602',
    ':umbrella_with_rain_drops:': '2614',
    ':droplet2:': '1f4a7',
    ':sweat_drops:': '1f4a6',
    ':ocean:': '1f30a',
    ':water_wave:': '1f30a',
    ':volcano:': '1f30b',
    ':fire_animated2:': '1f525',
    ':sparkles_animated2:': '2728',
    ':dizzy_animated:': '1f4ab',
    ':boom_animated:': '1f4a5',
    ':collision_animated:': '1f4a5',
    ':zap_animated:': '26a1',
    ':sunny_animated:': '2600',
    ':rainbow_animated:': '1f308',
    ':star_animated:': '2b50',
    ':rocket_animated2:': '1f680',
    ':trophy_animated:': '1f3c6',
    ':medal_animated:': '1f3c5',
    ':gift_animated:': '1f381',
    ':balloon_animated:': '1f388',
    ':celebration_animated:': '1f389',
    ':party_popper_animated:': '1f389',
    ':confetti_animated:': '1f38a',
    ':tada_animated2:': '1f389',
    ':birthday_animated:': '1f382',
    ':cake_animated:': '1f370',
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
      // Para emoticonos animados, usar GIFs animados reales
      final unicode = animatedEmojiMap[code];
      if (unicode != null) {
        // Usar emoji-api.com que tiene GIFs animados
        // Formato: https://emoji-api.com/emojis/{unicode}.gif
        return 'https://emoji-api.com/emojis/$unicode.gif';
      }
    }
    
    // Emoticonos estáticos normales
    final unicode = emojiMap[code];
    if (unicode == null) return null;
    return '$cdnBaseUrl$unicode.png';
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
    final regex = RegExp(r':(\w+):');
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
    return {
      'Animados': [
        ':party:', ':confetti_ball:', ':tada:', ':clap_animated:', ':wave_animated:',
        ':thumbsup_animated:', ':fire_animated:', ':heart_animated:', ':sparkles:',
        ':star_struck:', ':dancing:', ':celebration:', ':balloon:', ':gift:',
        ':trophy:', ':rocket:', ':rainbow:', ':zap:', ':boom:', ':sparkling_heart_animated:',
        ':heart_eyes_animated:', ':kiss_animated:', ':muscle_animated:', ':ok_hand_animated:',
        ':victory_animated:', ':pray_animated:', ':clap_hands:', ':raised_hands_animated:',
        ':dancer_animated:', ':party_popper:', ':confetti:', ':tada_animated:',
        ':birthday:', ':cake:', ':beer_animated:', ':champagne_animated:',
        ':rocket_animated:', ':trophy_animated:', ':medal_animated:', ':gift_animated:',
        ':balloon_animated:', ':celebration_animated:', ':fire_animated2:', ':sparkles_animated:',
        ':rainbow_animated:', ':star_animated:', ':zap_animated:', ':boom_animated:',
      ],
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












