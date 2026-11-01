/**
 * Touch sequence handed across the RPC boundary. The server packs
 * mutter's slot. This object stores that number, and
 * {@link get_slot} returns it.
 *
 * == Example ==
 *
 * {{{
 * var sequence = event.get_event_sequence();
 * if (sequence != null) {
 *     held = sequence.get_slot();
 * }
 * }}}
 */
namespace Clutter
{
	[CCode (cname = "ClutterEventSequence", cheader_filename = "namespace.h", copy_function = "clutter_event_sequence_copy", free_function = "clutter_event_sequence_free", type_id = "CLUTTER_TYPE_EVENT_SEQUENCE")]
	[Compact (opaque = true)]
	public class EventSequence
	{
		private int slot;

		/**
		 * @param slot mutter's {@code clutter_event_sequence_get_slot}
		 */
		public EventSequence(int slot) {
			this.slot = slot;
		}

		/**
		 * Boxed copy. A new sequence with the same slot.
		 */
		[CCode (cname = "clutter_event_sequence_copy")]
		public EventSequence copy() {
			return new EventSequence(this.slot);
		}

		/**
		 * Stock {@code clutter_event_sequence_get_slot}.
		 *
		 * @return the packed touch slot
		 */
		[CCode (cname = "clutter_event_sequence_get_slot")]
		public int get_slot() {
			return this.slot;
		}
	}
}
