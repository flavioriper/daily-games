# Copied from persona-policy-demo on 2026-10-31; see its spec for the design.
"""Jev as perception: five typed questions about a turn, one request, answers cached in SQLite by sha256(text)."""
import hashlib
import json
import os
import sqlite3
import threading

from pipecat.classifiers.base_classifier import BaseClassifier, ChoiceQuestion, ClassifierError, YesNoQuestion

from policy.features import KINDS, JevAnswers


class JevError(Exception):
    """Jev could not read the turn; the demo refuses the turn rather than guess."""


YES_NO = ["complete", "wants_detail", "upset", "decision_needed"]

QUESTIONS: dict[str, ChoiceQuestion | YesNoQuestion] = {
    "kind": ChoiceQuestion(
        instructions="What kind of turn is this?",
        options={
            "answer": "they are answering the question just asked, or giving their own information or an instruction",
            "question": "they ask something back",
            "redo": "they want it done again or changed",
            "greeting": "hello, good morning, or checking the line works",
            "off_topic": "small talk or something unrelated",
            "stop": "be quiet, stop, cancel, never mind",
        },
    ),
    # the same wording as jev-voice-demo/bot.py JevTurnGate.QUESTION
    "complete": YesNoQuestion(
        instructions="Is this a complete request or statement? Answer no if the person sounds like they are mid-sentence and will say more.",
        yes="it stands on its own",
        no="it is cut off or clearly continues",
    ),
    "wants_detail": YesNoQuestion(instructions="Does the person want a thorough, detailed reply rather than a quick one?"),
    "upset": YesNoQuestion(instructions="Does the person sound frustrated or annoyed?"),
    "decision_needed": YesNoQuestion(instructions="Is the person asking for a recommendation or a decision, rather than for something to be done?"),
    "complaint": ChoiceQuestion(
        instructions="Is the person complaining about how the assistant just behaved? If so, about what?",
        options={
            "none": "no complaint about the assistant's behaviour",
            "too_long": "it talks too much or the reply was too long",
            "too_short": "the reply was too short or left things out",
            "too_soft": "it should be more direct",
            "too_harsh": "it was too blunt or rude",
            "too_many_questions": "it asks too many questions and should just do it",
            "should_have_asked": "it should have asked before acting",
            "too_eager_ack": "it keeps saying got it or similar filler",
        },
    ),
}


class JevFeatures:
    def __init__(self, classifier: BaseClassifier, cache_path: str = "data/jev-cache.sqlite"):
        self.classifier = classifier
        if cache_path != ":memory:":
            os.makedirs(os.path.dirname(cache_path) or ".", exist_ok=True)
        self._db = sqlite3.connect(cache_path, check_same_thread=False)
        self._db.execute("CREATE TABLE IF NOT EXISTS answers (sha TEXT PRIMARY KEY, json TEXT)")
        self._lock = threading.Lock()

    async def warm(self) -> None:
        """Open the connection at call start, so the first turn doesn't spend its budget on a TLS handshake."""
        try:
            await self.classifier.client.connect()
        except ClassifierError:
            pass  # the first question opens it itself, or falls back

    async def answers(self, text: str) -> JevAnswers:
        sha = hashlib.sha256(text.encode()).hexdigest()
        with self._lock:
            row = self._db.execute("SELECT json FROM answers WHERE sha = ?", (sha,)).fetchone()
        if row:
            return JevAnswers(**json.loads(row[0]))
        try:
            results = await self.classifier.ask(text, QUESTIONS)
        except (ClassifierError, KeyError) as e:
            raise JevError(f"Jev failed: {e}") from e
        for name in QUESTIONS:
            if name not in results:
                raise JevError(f"Jev gave no answer for {name!r}")
        probs = results["kind"].probabilities
        if set(probs) != set(KINDS):
            raise JevError(f"Jev's kind answer is not over the six kinds: {sorted(probs)}")
        complaint = max(results["complaint"].probabilities.items(), key=lambda kv: kv[1])
        answers = JevAnswers(kind={k: float(probs[k]) for k in KINDS}, **{n: float(results[n].probability) for n in YES_NO}, complaint=complaint[0], complaint_p=float(complaint[1]))
        with self._lock:
            self._db.execute("INSERT OR REPLACE INTO answers VALUES (?, ?)", (sha, json.dumps(answers.__dict__)))
            self._db.commit()
        return answers


class NoJev:
    """No JEV_API_KEY: every turn takes the persona's default decision, marked on the panel, instead of the service refusing to start."""

    async def warm(self) -> None:
        pass

    async def answers(self, text: str) -> JevAnswers:
        raise JevError("JEV_API_KEY is not set")


def default_jev(cache_path: str = "data/jev-cache.sqlite") -> "JevFeatures | NoJev":
    from pipecat.classifiers.typesafe.jev.classifier import JevClassifier

    if not os.environ.get("JEV_API_KEY"):
        return NoJev()
    return JevFeatures(JevClassifier(api_key=os.environ["JEV_API_KEY"], model="jev-1.13.0"), cache_path=cache_path)
