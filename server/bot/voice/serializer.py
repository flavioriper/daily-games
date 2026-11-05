"""The browser wire format: binary is 16-bit PCM (16 kHz in, 24 kHz out), text is JSON. A `clear` message makes the page wind the voice down and drop the rest on interruption."""
import json
from typing import Callable

from pipecat.frames.frames import Frame, InputAudioRawFrame, InterruptionFrame, OutputAudioRawFrame, OutputTransportMessageFrame, OutputTransportMessageUrgentFrame
from pipecat.serializers.base_serializer import FrameSerializer

IN_RATE = 16000


class PcmSerializer(FrameSerializer):
    def __init__(self, on_text: Callable[[str], None] | None = None, **kwargs):
        """`on_text` gets every text frame the phone sends (interrupt, forget, bye, seen); the pipeline only ever sees audio."""
        super().__init__(**kwargs)
        self.on_text = on_text

    async def serialize(self, frame: Frame) -> str | bytes | None:
        if isinstance(frame, OutputAudioRawFrame):
            return frame.audio
        if isinstance(frame, InterruptionFrame):
            return json.dumps({"type": "clear"})
        if isinstance(frame, (OutputTransportMessageFrame, OutputTransportMessageUrgentFrame)):
            return json.dumps(frame.message)
        return None

    async def deserialize(self, data: str | bytes) -> Frame | None:
        if isinstance(data, (bytes, bytearray)):
            return InputAudioRawFrame(audio=bytes(data), sample_rate=IN_RATE, num_channels=1)
        if isinstance(data, str) and self.on_text:
            self.on_text(data)
        return None
