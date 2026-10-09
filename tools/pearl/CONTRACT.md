# Pearl Dive: the prompt contract

One prompt, in every file and in every day the server publishes:

    {"id": "e001", "level": 0,
     "en": {"ask": "A fruit"}, "pt": {"ask": "Uma fruta"}, "es": {"ask": "Una fruta"},
     "answers": [
       {"t": 0, "en": ["Apple"], "pt": ["Maçã"], "es": ["Manzana"]},
       {"t": 2, "en": ["Eggplant", "Aubergine"], "pt": ["Berinjela"], "es": ["Berenjena"]},
       ...]}

- `id`: level letter (e everyday, m medium, h hard) + three digits, unique.
  A day the model wrote has ids of its own (`d<day>l<level>k<n>`).
- `level`: 0 broad everyday kinds a ten-year-old can answer, 1 school
  general knowledge, 2 narrower, for a keen player.
- `ask`: the kind, a short noun phrase, at most 64 characters. `pt` is
  Brazilian Portuguese, `es` neutral Latin American Spanish.
- The kind is a set whose members are beyond argument, with thirty or more
  that ordinary people can name. About things in the world, never about
  spelling or language, so it is the same kind in all three languages.
  Timeless and for all ages; no brands.
- `answers`: at least 14, and as many as the kind has that a player might
  type (40 and up is usual): **the list is the judge**, and a right answer
  that is not on it is refused on the phone.
- `t`: how rare the answer is, **written, not counted from players**: 0 what
  almost everybody says first, 1 well known, 2 rare, 3 deep, 4 the Pearl.
  Exactly one Pearl: a deep answer with some charm that a few players will
  find, not the most obscure member there is. At least one answer on every
  tier.
- `en`, `pt`, `es`: each a list. The first is the name as it is shown, at
  most 26 characters; the rest are other names really in use for the same
  thing. Every one must come to 2..22 letters once it is folded as the
  keyboard types (lower case, no accents, letters only), and holds no
  numeral.
- No folded spelling is shared by two answers of a prompt in one language:
  the commoner answer keeps it.
- The game ignores capitals, accents, spaces and hyphens, takes a name typed
  in another of the three languages, and forgives a slip of one letter in
  names of five letters and up; none of those need listing.
