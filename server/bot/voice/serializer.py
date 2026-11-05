"""The browser wire format: binary is 16-bit PCM (16 kHz in, 24 kHz out), text is JSON. A `clear` message makes the page wind the voice down and drop the rest on interruption."""
import json

from pipecat.frames.frames import Frame, InputAudioRawFrame, InterruptionFrame, OutputAudioRawFrame, OutputTransportMessageFrame, OutputTransportMessageUrgentFrame
from pipecat.serializers.base_serializer import FrameSerializer

IN_RATE = 16000


class PcmSerializer(FrameSerializer):
    async def serialize(self, frame: Frame) -> str | bytes | None:
        if isinstance(frame, OutputAudioRawFrame):
            return frame.audio
        if isinstance(frame, InterruptionFrame):
            return json.dumps({"type": "clear"})
        if isinstance(frame, (OutputTransportMessageFrame, OutputTransportMessageUrgentFrame)):
            return json.dumps(frame.message)
        return None

    async def deserialize(self, data: str | bytes) -> Frame | None:
        return InputAudioRawFrame(audio=bytes(data), sample_rate=IN_RATE, num_channels=1) if isinstance(data, (bytes, bytearray)) else None
