/**
 * Owned {@code Shell.SecureTextBuffer} — stock
 * {@code shell-secure-text-buffer.c}.
 *
 * {@link Clutter.TextBuffer} backed by Gcr secure memory so password
 * contents are not kept in ordinary heap.
 */
namespace Shell
{
	public class SecureTextBuffer : Clutter.TextBuffer
	{
		[CCode (cname = "gcr_secure_memory_realloc")]
		private static extern void* secure_realloc(void* memory, size_t size);

		[CCode (cname = "gcr_secure_memory_strfree")]
		private static extern void secure_strfree([CCode (type = "gchar*")] void* memory);

		private void* text;
		private size_t text_size;
		private size_t text_bytes;
		private uint text_chars;

		public SecureTextBuffer()
		{
			Object();
		}

		~SecureTextBuffer()
		{
			if (this.text == null) {
				return;
			}
			secure_strfree(this.text);
			this.text = null;
		}

		public override uint32 get_length()
		{
			return this.text_chars;
		}

		public override string get_text()
		{
			if (this.text == null) {
				return "";
			}
			return (string) this.text;
		}

		public override uint32 insert_text(uint32 position, string chars, int32 n_chars)
		{
			if (n_chars <= 0) {
				return 0;
			}

			var n_bytes = chars.index_of_nth_char(n_chars);
			n_bytes = n_bytes < 0 ? chars.length : n_bytes;

			if (n_bytes + this.text_bytes + 1 > this.text_size) {
				while (n_bytes + this.text_bytes + 1 > this.text_size) {
					if (this.text_size == 0) {
						this.text_size = 16;
						continue;
					}
					if (2 * this.text_size < 65535) {
						this.text_size *= 2;
						continue;
					}
					this.text_size = 65535;
					if (n_bytes > this.text_size - this.text_bytes - 1) {
						n_bytes = (int) (this.text_size - this.text_bytes - 1);
						n_chars = (int32) chars.char_count(n_bytes);
					}
					break;
				}
				this.text = secure_realloc(this.text, this.text_size);
			}

			var at = 0;
			if (this.text != null && this.text_chars > 0) {
				at = ((string) this.text).index_of_nth_char((long) position);
				at = at < 0 ? (int) this.text_bytes : at;
			}

			GLib.Memory.move((uint8*) this.text + at + n_bytes,
				(uint8*) this.text + at, this.text_bytes - at);
			GLib.Memory.copy((uint8*) this.text + at, chars, n_bytes);

			this.text_bytes += n_bytes;
			this.text_chars += n_chars;
			((uint8*) this.text)[this.text_bytes] = 0;

			this.emit_inserted_text(position, chars, (uint32) n_chars);
			return (uint32) n_chars;
		}

		public override uint32 delete_text(uint32 position, int32 n_chars)
		{
			position = position > this.text_chars ? this.text_chars : position;
			n_chars = position + n_chars > this.text_chars ? (int32) (this.text_chars - position) : n_chars;
			if (n_chars <= 0) {
				return 0;
			}

			unowned var str = (string) this.text;
			var start = str.index_of_nth_char((long) position);
			var end = str.index_of_nth_char((long) (position + n_chars));
			start = start < 0 ? (int) this.text_bytes : start;
			end = end < 0 ? (int) this.text_bytes : end;

			GLib.Memory.move((uint8*) this.text + start,
				(uint8*) this.text + end, this.text_bytes + 1 - end);
			this.text_chars -= n_chars;
			this.text_bytes -= (end - start);

			this.emit_deleted_text(position, (uint32) n_chars);
			return (uint32) n_chars;
		}
	}
}
