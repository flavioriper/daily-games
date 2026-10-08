# Golden Acorn: the question contract

One question, in every file and in every day the server publishes:

    {"id": "e001", "cat": "nature",
     "en": {"q": "...", "right": "...", "wrong": ["...", "...", "..."], "why": "..."},
     "pt": {...}, "es": {...}}

- `id`: tier letter (e easy, m medium, h hard, x expert) + three digits, unique.
- `cat`: one of nature, science, geography, history, arts, food, sports,
  words, everyday.
- `q`: the question, at most 110 characters. `right`: the one right answer.
  `wrong`: exactly three wrong answers, plausible, the same kind of thing as
  the right one. Every answer at most 26 characters. `why`: one friendly
  sentence that teaches the fact, at most 110 characters.
- `pt` is Brazilian Portuguese, `es` neutral Latin American Spanish; each is
  the same question, written naturally, not word for word.
- Exactly one answer is right, beyond argument, and will still be right in
  ten years (no records that fall, no "current", no populations, no prices).
- Family game, all ages, played worldwide: nothing violent, political,
  religious-doctrinal, sexual or brand-driven; no trick wording; no "all of
  the above"; the right answer must not be the odd one out by length or form.

The game shuffles the four answers itself.
