#include <glib.h>

typedef ClutterMargin *(*StockGetFadeMargins) (StScrollViewFade *);

G_STATIC_ASSERT (__builtin_types_compatible_p (
  __typeof__ (&st_scroll_view_fade_get_fade_margins),
  StockGetFadeMargins));

int
main (void)
{
  g_print ("st-scroll-view-fade-margins-abi: ok\n");
  return 0;
}
