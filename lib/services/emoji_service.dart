class EmojiService {
  static const String cdnBaseUrl = 'https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/';
  
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
    final unicode = emojiMap[emojiCode.toLowerCase()];
    if (unicode == null) return null;
    return '$cdnBaseUrl$unicode.png';
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










