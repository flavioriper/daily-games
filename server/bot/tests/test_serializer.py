import json

from pipecat.frames.frames import InputAudioRawFrame, InterruptionFrame, OutputAudioRawFrame, TranscriptionFrame

from voice.serializer import PcmSerializer


async def test_audio_and_clear():
    s = PcmSerializer()
    assert await s.serialize(OutputAudioRawFrame(b"\x01\x02", 24000, 1)) == b"\x01\x02"
    assert json.loads(await s.serialize(InterruptionFrame())) == {"type": "clear"}
    assert await s.serialize(TranscriptionFrame("x", "u", "t")) is None
    f = await s.deserialize(b"\x01\x02")
    assert isinstance(f, InputAudioRawFrame) and f.sample_rate == 16000
    assert await s.deserialize("nonsense") is None


async def test_rtvi_chatter_never_reaches_the_phone():
    from pipecat.frames.frames import OutputTransportMessageFrame

    s = PcmSerializer()
    rtvi = {"label": "rtvi-ai", "type": "user-transcription", "data": {"text": "what the player said"}}
    assert await s.serialize(OutputTransportMessageFrame(message=rtvi)) is None
    assert json.loads(await s.serialize(OutputTransportMessageFrame(message={"type": "said", "text": "hi"}))) == {"type": "said", "text": "hi"}
