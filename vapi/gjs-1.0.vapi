[CCode (cprefix = "Gjs", gir_namespace = "Gjs", gir_version = "1.0", lower_case_cprefix = "gjs_")]
namespace Gjs {
	[CCode (cheader_filename = "gjs/gjs.h", type_id = "GJS_TYPE_CONTEXT")]
	public class Context : GLib.Object {
		public Context();
		[CCode (cname = "gjs_context_new_with_search_path")]
		public Context.with_search_path([CCode (array_length = false, array_null_terminated = true)] string[] search_path);
		public bool eval_file(string filename, out int exit_status) throws GLib.Error;
		[CCode (cname = "gjs_context_eval_module_file")]
		public bool eval_module_file(string filename, out uint8 exit_status) throws GLib.Error;
		[CCode (array_length = false, array_null_terminated = true)]
		public string[] search_path { get; construct; }
		public string program_name { get; construct; }
		public string program_path { get; construct; }
	}
}
