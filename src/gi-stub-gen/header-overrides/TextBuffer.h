/* Curated TextBuffer (0.7.4) — class get_text matches stock (const / gsize).
 * Method protos still append from GIR + TextBuffer.methods.h.
 */

#include <glib-object.h>
#include "clutter/clutter-types.h"

G_BEGIN_DECLS

#define CLUTTER_TYPE_TEXT_BUFFER (clutter_text_buffer_get_type ())
#define CLUTTER_TEXT_BUFFER(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST ((obj), CLUTTER_TYPE_TEXT_BUFFER, ClutterTextBuffer))
#define CLUTTER_TEXT_BUFFER_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST ((klass), CLUTTER_TYPE_TEXT_BUFFER, ClutterTextBufferClass))
#define CLUTTER_IS_TEXT_BUFFER(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE ((obj), CLUTTER_TYPE_TEXT_BUFFER))
#define CLUTTER_IS_TEXT_BUFFER_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE ((klass), CLUTTER_TYPE_TEXT_BUFFER))
#define CLUTTER_TEXT_BUFFER_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), CLUTTER_TYPE_TEXT_BUFFER, ClutterTextBufferClass))

struct _ClutterTextBuffer
{
  GObject parent_instance;
  ClutterTextBufferPrivate *priv;
};

struct _ClutterTextBufferClass
{
  GObjectClass parent_class;
  void (* inserted_text) (ClutterTextBuffer * buffer, guint32 position, const gchar * chars, guint32 n_chars);
  void (* deleted_text) (ClutterTextBuffer * buffer, guint32 position, guint32 n_chars);
  const gchar * (* get_text) (ClutterTextBuffer * buffer, gsize * n_bytes);
  guint32 (* get_length) (ClutterTextBuffer * buffer);
  guint32 (* insert_text) (ClutterTextBuffer * buffer, guint32 position, const gchar * chars, guint32 n_chars);
  guint32 (* delete_text) (ClutterTextBuffer * buffer, guint32 position, guint32 n_chars);
};

GType clutter_text_buffer_get_type (void);
