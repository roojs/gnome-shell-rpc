overlay = get_option('gi_rpc_js_overlay_message_list')
if overlay == 'exit'
  message_list_overlay = configure_file(
    input: 'messageList.exit.js',
    output: 'messageList.js',
    copy: true,
  )
elif overlay != 'disabled'
  error('unknown gi_rpc_js_overlay_message_list: @0@'.format(overlay))
endif
