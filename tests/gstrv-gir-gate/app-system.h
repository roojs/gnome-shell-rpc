#pragma once

#include <glib-object.h>

G_BEGIN_DECLS

#define GSR_SEARCH_TYPE_APP_SYSTEM (gsr_search_app_system_get_type ())
G_DECLARE_FINAL_TYPE (GsrSearchAppSystem, gsr_search_app_system,
                      GSR_SEARCH, APP_SYSTEM, GObject)

char *** gsr_search_app_system_search (const char *search_string);

G_END_DECLS
