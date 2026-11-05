# Copied from persona-policy-demo on 2026-10-31; see its spec for the design.
"""Python port of Fraction's `Mood.call` (app/models/mood.rb), text only: the prosody terms are left out and pace is always "normal"."""
import re

from policy.features import MoodResult

UNSURE = re.compile(r"\b(?:um+|uh+|er+|hmm+|not sure|i guess|i suppose|maybe|kind of|sort of|i don'?t know|dunno|you know)\b", re.I)
FRUSTRATED = re.compile(
    r"\b(?:ugh|come on|for the (?:second|third|\w+) time|i (?:already )?(?:said|told you)|again\?|that'?s not what i|why (?:can'?t|won'?t|don'?t) you|this is (?:wrong|useless|annoying)|seriously)\b"
    r"|\b(?:damn|shit|crap|wtf|fuck\w*)\b",
    re.I,
)
EXCITED = re.compile(r"\b(?:love (?:it|that|this)|awesome|amazing|perfect|brilliant|fantastic|great idea|excellent|yes!|wow|can'?t wait)\b", re.I)
HURRIED = re.compile(r"\b(?:quick(?:ly)?|hurry|asap|right now|in a rush|no time|fast|speed (?:it )?up|skip)\b", re.I)


def mood(text: str) -> MoodResult:
    text = " ".join(str(text).split())
    # same insertion order as the Ruby hash, so a tie goes to the mood Ruby's max_by picks first
    scores = {"frustrated": 0.0, "unsure": 0.0, "excited": 0.0, "hurried": 0.0}
    if FRUSTRATED.search(text):
        scores["frustrated"] += 0.8
    if UNSURE.search(text):
        scores["unsure"] += 0.6
    if EXCITED.search(text):
        scores["excited"] += 0.7
    if text.count("!") >= 1:
        scores["excited"] += 0.25
    if HURRIED.search(text):
        scores["hurried"] += 0.7
    best = max(scores, key=lambda m: scores[m])
    if scores[best] < 0.5:
        return MoodResult("calm", 0.6, "normal")
    return MoodResult(best, round(min(scores[best], 1.0), 2), "normal")
