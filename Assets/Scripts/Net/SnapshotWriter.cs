using System;
using System.Text;

namespace BattleOfAgents.Net
{
    /// <summary>Compact binary reader/writer for the 20 Hz gameplay channel.
    ///
    /// The lobby can afford JSON; the movement channel cannot. A snapshot for eight
    /// players fits in about 200 bytes here, versus roughly 1.5 KB as JSON — which
    /// matters once it goes out twenty times a second to every phone in the room.</summary>
    public class SnapshotWriter
    {
        readonly byte[] _buffer;
        int _position;

        public SnapshotWriter(int capacity = 1024) { _buffer = new byte[capacity]; }

        public int Length { get { return _position; } }
        public byte[] Buffer { get { return _buffer; } }

        public void Reset() { _position = 0; }

        public void Byte(byte value) { _buffer[_position++] = value; }

        public void Int(int value)
        {
            _buffer[_position++] = (byte)(value      );
            _buffer[_position++] = (byte)(value >>  8);
            _buffer[_position++] = (byte)(value >> 16);
            _buffer[_position++] = (byte)(value >> 24);
        }

        public void Float(float value)
        {
            var bits = BitConverter.ToInt32(BitConverter.GetBytes(value), 0);
            Int(bits);
        }

        /// <summary>Positions are quantised to centimetres — far finer than a player
        /// can perceive at this speed, and half the bytes of a raw float triple.</summary>
        public void Position(float x, float y, float z)
        {
            Short((short)Math.Round(Clamp(x) * 20f));
            Short((short)Math.Round(Clamp(y) * 20f));
            Short((short)Math.Round(Clamp(z) * 20f));
        }

        public void Angle(float degrees)
        {
            var wrapped = degrees % 360f;
            if (wrapped < 0f) wrapped += 360f;
            Byte((byte)Math.Round(wrapped / 360f * 255f));
        }

        public void Short(short value)
        {
            _buffer[_position++] = (byte)(value     );
            _buffer[_position++] = (byte)(value >> 8);
        }

        static float Clamp(float v) { return Math.Max(-1600f, Math.Min(1600f, v)); }

        /// <summary>Stable 32-bit id for a player, identical on every device.
        /// FNV-1a: cheap, no allocation, and good enough for a handful of players.</summary>
        public static int HashId(string playerId)
        {
            unchecked
            {
                uint hash = 2166136261;
                var bytes = Encoding.UTF8.GetBytes(playerId ?? string.Empty);
                for (int i = 0; i < bytes.Length; i++)
                {
                    hash ^= bytes[i];
                    hash *= 16777619;
                }
                return (int)hash;
            }
        }
    }

    public class SnapshotReader
    {
        readonly byte[] _buffer;
        int _position;

        public SnapshotReader(byte[] buffer, int length)
        {
            _buffer = buffer;
            Length = length;
        }

        public int Length { get; private set; }
        public bool HasMore { get { return _position < Length; } }

        public byte Byte() { return _buffer[_position++]; }

        public short Short()
        {
            var value = (short)(_buffer[_position] | (_buffer[_position + 1] << 8));
            _position += 2;
            return value;
        }

        public int Int()
        {
            var value = _buffer[_position]
                      | (_buffer[_position + 1] << 8)
                      | (_buffer[_position + 2] << 16)
                      | (_buffer[_position + 3] << 24);
            _position += 4;
            return value;
        }

        public float Float() { return BitConverter.ToSingle(BitConverter.GetBytes(Int()), 0); }

        public void Position(out float x, out float y, out float z)
        {
            x = Short() / 20f;
            y = Short() / 20f;
            z = Short() / 20f;
        }

        public float Angle() { return Byte() / 255f * 360f; }
    }
}
