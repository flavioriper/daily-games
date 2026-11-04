# Garden Fence

2026-11-04, the fifth and last of the word boards in
`docs/roadmap-word-boards.md` (the user: "let's tackle the next
docs/roadmap-word-boards.md item. Make sure to wire it properly with sounds,
animations, fully polished user player experience like the others wording
games ... Do it autonomous, commit to main when done"). Built straight from
the roadmap's entry, unattended, with no concept tab first, as the four
before it were.

The genre's best-known daily version is the New York Times' Letter Boxed,
named here once, to forbid it in code, comments, commits and on screen.

## The board

- **A garden bed on a lawn**, a low wooden rail round it in the fence's
  shape, three posts a side, a letter on each post's cap. Every letter on
  the fence is different.
- **String a word**: tap posts (or drag across them) and green twine runs
  post to post. Two letters in a row never come from the same side: a post
  from the side of the last one shivers and is refused, and while a trail
  is open the letters on that side are dimmed. A word has three letters at
  least.
- **Tie it off**: tap the trail's last post again, or the sign above the
  fence the word is chalked on. The twine is gold while it spells a word
  the garden knows, so the player sees when a knot will take. Tied, it
  turns jute, a knot pops on the last post, the word's posts hop in order
  and every post it touched for the first time opens a daisy. The word
  hangs on a seed tag in the row under the tools.
- **Chain**: the next word starts on the post the last one ended on (the
  trail starts there by itself). Letters may be used again.
- **The solve**: every post in bloom. On Insane (Gate) one post is a gate,
  drawn as a little arched gate outside it: the last word must end there.
- **Refusals**, each with a tongue and a line said: a post from the same
  side; fewer than three letters; a word the garden does not know (the
  trail stays to be mended); a word tied already.
- **Undo** takes back the last letter, or, with no letter strung past the
  joint, unties the last word (its twine recoils). **The bin** (asks)
  unties them all. Both are free: only the words tied when the garden
  blooms count.

## Words

`tools/build_fence.py` reads Biscuit Tin's pruned wordfreq lexicon (four to
sixteen letters, Hunspell checked, rude lists, stems and names out; the
build's cache dir) and adds three-letter words of its own (wordfreq, in the
Hunspell dictionary in lower case only, so no abbreviations or names),
drops words with one letter twice in a row (a fence can never string them),
and writes `content/fence_words[.lang].json`: by first letter,
space-separated, `fair` (zipf 2.9 up, commonest first: the par, the bulb
and the fewest-to-go walk on these), `more` (zipf 1.8 to 2.9, and a short
`CRUDE` list: the fence takes them but never offers them), `shown`
(accents). Typed letters are folded as Hidden Word folds (accents off, Ñ
kept in Spanish). Shipping the per-fence word lists instead was measured
at 4-5 MB a band; one list a language is 0.4-1 MB.

Banks: `content/insane/fence_<band>[.lang].json`, 365 a band a language,
read through `InsaneBank`. A fence starts from a chain of common words (two,
three on the pentagon, zipf 3.2-3.4 up, each a seed at most twice a bank)
that between them use exactly the fence's letters, last letter to first.
The letters are shared out three a side (a backtracking colouring) so no
two letters side by side in the chain share a side. The par is the seed's
length, proved: a fence is kept only when no shorter chain over every word
it takes (not only the fair ones) uses every post (on Insane, ending on the
gate). A fence takes at least 40/60/70/60 fair words by band. Each carries
`posts` (three a side, clockwise from the top), `sides`, `gate` (-1 off
Insane), `par`, `route`, and how many words and fair words it takes.

## Stars and quality

The pill reads the words tied and the fewest still to go from the last
(searched two words deep over the fair words, said to be three past that):
3 stars up to par + 1, 2 up to par + 3, 1 after. Par 2 proved over every
word is expert level for this genre; a casual solve of twelve posts is three
or four words, so three stars allow one word over par (Stepping Stones'
rule). The brain score is par over the words, a word the bulb strung
counted twice. A party on the solve at par with no bulb.

## Bulb, two presses

The first press (one hint) rings the posts the next word of a fewest way
starts and ends on and says how long it is ("8 letters, from S to R"); with
nothing tied, the route's first word. The search is exact to three words
(a budget of middle words, the starts that string the most new posts
first), else the word from the joint that strings the most new posts. From
a dead end (no fair word starts on the joint) it names the word to untie.
The second press strings that word a post at a time from the joint and
ties it (kind `bulb`, a blue edge on its tag). When the bulbs run out the
host offers one more for a video.

## Bands

| Band | Fence | Posts | Par | Hints | Rule |
|---|---|---|---|---|---|
| Easy | triangle | 9 | 2 | 3 | |
| Medium | square | 12 | 2 | 2 | |
| Hard | pentagon | 15 | 3 | 2 | |
| Insane | square | 12 | 2 | 2 | Gate: end on the gate post |

## Sound and feel

Every action a pop from `tools/sfx_bank/` (`tools/gen_sfx.py`, family
`fence`): `post` the pebble, pitched up the trail; `ready` one quiet wrap as
the twine turns gold; `back` the lip; `side` the tongue; `refuse` the tongue
twice falling; `again` the lip twice; `tie` the token low and wraps rising,
pitched by the word's length; `bloom` a high wrap a daisy, climbing;
`undo`, `clear`, `fall` the lip; `gate` tokens rising; `enter` a run of
tokens; hint, solved, confetti and party Honeycomb's takes. Haptics in
`docs/agents/haptics.md` (row 28q).
