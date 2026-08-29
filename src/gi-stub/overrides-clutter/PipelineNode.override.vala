		/**
		 * Default ctor so subclasses can {@code Object()} before real paint
		 * wiring exists. Stock {@code new(pipeline)} stays denied/not wired.
		 */
		public PipelineNode()
		{
			Object();
			GLib.error("gi-stub: Clutter-PipelineNode not implemented");
		}
